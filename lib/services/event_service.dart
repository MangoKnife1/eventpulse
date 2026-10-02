import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/event_model.dart';
import '../models/notification_model.dart';
import '../models/organizer_application_model.dart';
import '../models/ticket_model.dart';
import '../models/user_model.dart';
import 'demo_data.dart';
import 'firebase_refs.dart';
import 'service_exception.dart';

/// Events, tickets, notifications and organizer applications.
///
/// * Firebase mode: live Firestore listeners; registration and check-in run in
///   transactions so capacity and "already checked in" can't be raced.
/// * Demo mode (default): in-memory sample data, same public API.
///
/// Views read the lists below and call the methods; they don't care which mode
/// is active.
class EventService extends ChangeNotifier {
  EventService({this.useFirebase = false}) {
    if (!useFirebase) {
      _events = DemoData.events();
      _userTickets = DemoData.tickets(_events);
      _notifications = DemoData.notifications();
      _applications = DemoData.applications();
    }
  }

  final bool useFirebase;

  // ── Public state ─────────────────────────────────────────────────────────
  List<EventModel> _events = [];
  List<TicketModel> _userTickets = [];
  List<NotificationModel> _notifications = [];
  List<OrganizerApplicationModel> _applications = [];

  String _selectedCategory = 'All';
  String _selectedTag = 'All';
  String _selectedSort = 'date';
  String _searchQuery = '';

  // ── Firebase bookkeeping ─────────────────────────────────────────────────
  FirebaseFirestore get _db => appFirestore;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Map<String, EventModel> _approvedSrc = {};
  final Map<String, EventModel> _ownSrc = {};
  final Map<String, EventModel> _allSrc = {};
  final Map<String, TicketModel> _mineSrc = {};
  final Map<String, TicketModel> _managedSrc = {};
  String? _boundUid;
  UserRole? _boundRole;
  bool _disposed = false;

  // ── In-app popups & reminders ────────────────────────────────────────────
  /// Emits every notification that should pop up on screen (shown by main.dart).
  final StreamController<NotificationModel> _incoming = StreamController.broadcast();
  Stream<NotificationModel> get incomingNotifications => _incoming.stream;
  bool _notifPrimed = false; // first snapshot = existing notifications, no popups for those
  String? _currentUid; // signed-in user (set in both demo and Firebase mode)
  Timer? _reminderTimer;
  final Set<String> _remindedKeys = {};

  // ── Getters ──────────────────────────────────────────────────────────────
  List<EventModel> get allEvents => List.unmodifiable(_events);
  List<TicketModel> get userTickets => List.unmodifiable(_userTickets);
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  List<OrganizerApplicationModel> get pendingApplications => List.unmodifiable(
        _applications.where((a) => a.status == ApplicationStatus.pending),
      );
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  String get selectedCategory => _selectedCategory;
  String get selectedTag => _selectedTag;
  String get selectedSort => _selectedSort;
  String get searchQuery => _searchQuery;

  List<EventModel> get approvedEvents {
    final q = _searchQuery.toLowerCase();
    final filtered = _events.where((e) {
      final matchesStatus = e.approvalStatus == ApprovalStatus.approved;
      final matchesCategory = _selectedCategory == 'All' || e.category == _selectedCategory;
      final matchesTag = _selectedTag == 'All' ||
          e.tags.any((t) => t.toLowerCase() == _selectedTag.toLowerCase());
      final matchesSearch = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.venueName.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      return matchesStatus && matchesCategory && matchesTag && matchesSearch;
    }).toList();

    if (_selectedSort == 'popular') {
      filtered.sort((a, b) => b.registeredCount.compareTo(a.registeredCount));
    } else if (_selectedSort == 'spots') {
      filtered.sort((a, b) => a.spotsRemaining.compareTo(b.spotsRemaining));
    } else {
      filtered.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    return filtered;
  }

  /// Every approved event, ignoring the search/filter chips on the browse screen.
  List<EventModel> get openEvents =>
      _events.where((e) => e.approvalStatus == ApprovalStatus.approved).toList();

  /// Tags used by approved events, most common first (for the filter chips).
  List<String> get availableTags {
    final counts = <String, int>{};
    final display = <String, String>{};
    for (final e in _events.where((e) => e.approvalStatus == ApprovalStatus.approved)) {
      for (final raw in e.tags) {
        final t = raw.trim();
        if (t.isEmpty) continue;
        final key = t.toLowerCase();
        counts[key] = (counts[key] ?? 0) + 1;
        display.putIfAbsent(key, () => t);
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return keys.take(8).map((k) => display[k]!).toList();
  }

  List<EventModel> get pendingApprovalEvents =>
      _events.where((e) => e.approvalStatus == ApprovalStatus.pending).toList();

  /// Events an organizer manages (all their own, any approval state); an admin
  /// manages everything.
  List<EventModel> eventsManagedBy(UserModel user) {
    if (user.role == UserRole.admin) return List.unmodifiable(_events);
    return _events.where((e) => e.organizerId == user.id).toList();
  }

  // ── Filters ──────────────────────────────────────────────────────────────
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  void setSort(String sort) {
    _selectedSort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ── Lookups ──────────────────────────────────────────────────────────────
  EventModel? getEventByRegistrationCode(String code) {
    final clean = code.trim().toUpperCase();
    for (final e in _events) {
      if (e.registrationCode?.toUpperCase() == clean || e.id.toUpperCase() == clean) return e;
    }
    return null;
  }

  bool isUserRegisteredFor(String eventId, String userId) =>
      getTicketForEvent(eventId, userId) != null;

  TicketModel? getTicketForEvent(String eventId, String userId) {
    for (final t in _userTickets) {
      if (t.eventId == eventId && t.userId == userId && t.status != TicketStatus.cancelled) {
        return t;
      }
    }
    return null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Firebase: subscriptions (called by the ProxyProvider when auth changes)
  // ═════════════════════════════════════════════════════════════════════════
  void bindUser(UserModel user, {required bool signedIn}) {
    final uid = signedIn ? user.id : null;
    if (_currentUid != uid) {
      _currentUid = uid;
      _remindedKeys.clear();
      if (uid == null) {
        _stopReminderTimer();
      } else {
        _startReminderTimer();
      }
    } else if (uid != null) {
      _startReminderTimer();
    }
    if (!useFirebase) return;
    final role = signedIn ? user.role : null;
    if (_subs.isNotEmpty && uid == _boundUid && role == _boundRole) return;

    _boundUid = uid;
    _boundRole = role;
    _cancelSubs();
    for (final m in [_approvedSrc, _ownSrc, _allSrc]) {
      m.clear();
    }
    _mineSrc.clear();
    _managedSrc.clear();
    _notifications = [];
    _applications = [];
    _notifPrimed = false;

    final events = _db.collection('events');
    final tickets = _db.collection('tickets');

    // Everyone (including guests) sees approved events.
    _listenEvents(events.where('approvalStatus', isEqualTo: 'approved'), _approvedSrc);

    if (uid != null) {
      _listenTickets(tickets.where('userId', isEqualTo: uid), _mineSrc);
      _listenNotifications(uid);

      if (role == UserRole.organizer) {
        _listenEvents(events.where('organizerId', isEqualTo: uid), _ownSrc);
        _listenTickets(tickets.where('organizerId', isEqualTo: uid), _managedSrc);
      } else if (role == UserRole.admin) {
        _listenEvents(events, _allSrc);
        _listenTickets(tickets, _managedSrc);
        _listenApplications();
      }
    }

    _rebuildEvents();
    _rebuildTickets();
    // bindUser runs during a widget build; notify after the frame settles.
    Future.microtask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void _cancelSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  void _listenEvents(Query<Map<String, dynamic>> query, Map<String, EventModel> target) {
    _subs.add(query.snapshots().listen((snap) {
      target
        ..clear()
        ..addEntries(snap.docs.map((d) =>
            MapEntry(d.id, EventModel.fromJson({...d.data(), 'id': d.id}))));
      _rebuildEvents();
      notifyListeners();
    }, onError: (Object e) => debugPrint('Events listener error: $e')));
  }

  void _listenTickets(Query<Map<String, dynamic>> query, Map<String, TicketModel> target) {
    _subs.add(query.snapshots().listen((snap) {
      target
        ..clear()
        ..addEntries(snap.docs.map((d) =>
            MapEntry(d.id, TicketModel.fromJson({...d.data(), 'id': d.id}))));
      _rebuildTickets();
      notifyListeners();
    }, onError: (Object e) => debugPrint('Tickets listener error: $e')));
  }

  void _listenNotifications(String uid) {
    _subs.add(_db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      _notifications = snap.docs
          .map((d) => NotificationModel.fromJson({...d.data(), 'id': d.id}))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Pop up only notifications that ARRIVE after the first snapshot, and that
      // came from elsewhere (our own writes are shown directly by the code that made them).
      if (_notifPrimed) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added || change.doc.metadata.hasPendingWrites) {
            continue;
          }
          final data = change.doc.data();
          if (data == null) continue;
          final n = NotificationModel.fromJson({...data, 'id': change.doc.id});
          final fresh = DateTime.now().difference(n.timestamp).inMinutes.abs() < 10;
          if (!n.isRead && fresh) _emit(n);
        }
      }
      _notifPrimed = true;
      notifyListeners();
    }, onError: (Object e) => debugPrint('Notifications listener error: $e')));
  }

  void _listenApplications() {
    _subs.add(_db
        .collection('organizerApplications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      _applications = snap.docs
          .map((d) => OrganizerApplicationModel.fromJson({...d.data(), 'id': d.id}))
          .toList()
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
      notifyListeners();
    }, onError: (Object e) => debugPrint('Applications listener error: $e')));
  }

  void _rebuildEvents() {
    _events = {..._approvedSrc, ..._ownSrc, ..._allSrc}.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  void _rebuildTickets() {
    _userTickets = {..._mineSrc, ..._managedSrc}.values.toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Registration
  // ═════════════════════════════════════════════════════════════════════════
  Future<TicketModel> registerUserForEvent({
    required EventModel event,
    required UserModel user,
  }) async {
    if (user.isGuest) throw const ServiceException('Please sign in to register.');
    if (event.approvalStatus != ApprovalStatus.approved) {
      throw const ServiceException('This event is not open for registration.');
    }
    final existing = getTicketForEvent(event.id, user.id);
    if (existing != null) return existing;

    final ticket = useFirebase ? await _registerRemote(event, user) : _registerLocal(event, user);
    if (useFirebase) {
      _mineSrc[ticket.id] = ticket;
      _rebuildTickets();
      notifyListeners();
    }
    await _notifyUser(
      user.id,
      title: 'Pass Issued: ${event.title}',
      message: 'Your QR pass is ready in My Passes.',
      type: 'checkin',
      eventId: event.id,
      popup: false, // the RSVP screen already shows a confirmation
    );
    if (useFirebase && event.organizerId.isNotEmpty && event.organizerId != user.id) {
      await _notifyUser(
        event.organizerId,
        title: 'New registration',
        message: '${user.name} registered for ${event.title}.',
        type: 'registration',
        eventId: event.id,
      );
    }
    return ticket;
  }

  Future<TicketModel> _registerRemote(EventModel event, UserModel user) async {
    final eventRef = _db.collection('events').doc(event.id);
    // Deterministic id = one ticket per user per event, even on double-taps.
    final ticketRef = _db.collection('tickets').doc('${event.id}_${user.id}');

    try {
      return await _db.runTransaction<TicketModel>((tx) async {
        final eventSnap = await tx.get(eventRef);
        if (!eventSnap.exists) throw const ServiceException('This event no longer exists.');
        final fresh = EventModel.fromJson({...eventSnap.data()!, 'id': eventSnap.id});

        if (fresh.approvalStatus != ApprovalStatus.approved ||
            fresh.status == EventStatus.cancelled ||
            fresh.status == EventStatus.completed) {
          throw const ServiceException('This event is not open for registration.');
        }

        final ticketSnap = await tx.get(ticketRef);
        if (ticketSnap.exists) {
          return TicketModel.fromJson({...ticketSnap.data()!, 'id': ticketSnap.id});
        }
        if (fresh.isFull) throw const ServiceException('Sorry, this event is fully booked.');

        final ticket = _buildTicket(ticketRef.id, fresh, user);
        tx.set(ticketRef, ticket.toJson());
        tx.update(eventRef, {'registeredCount': fresh.registeredCount + 1});
        return ticket;
      });
    } on ServiceException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('Registration failed: ${e.code} ${e.message}');
      throw ServiceException('${firebaseErrorText(e)} (${e.code})');
    } catch (e) {
      debugPrint('Registration failed: $e');
      throw ServiceException(
        kDebugMode ? 'Could not issue the ticket: $e' : 'Could not issue the ticket. Please try again.',
      );
    }
  }

  TicketModel _registerLocal(EventModel event, UserModel user) {
    if (event.isFull) throw const ServiceException('Sorry, this event is fully booked.');
    final ticket = _buildTicket('tkt_${DateTime.now().millisecondsSinceEpoch}', event, user);
    _userTickets = [..._userTickets, ticket];
    final i = _events.indexWhere((e) => e.id == event.id);
    if (i != -1) {
      _events[i] = _events[i].copyWith(registeredCount: _events[i].registeredCount + 1);
    }
    notifyListeners();
    return ticket;
  }

  TicketModel _buildTicket(String id, EventModel event, UserModel user) {
    return TicketModel(
      id: id,
      eventId: event.id,
      eventTitle: event.title,
      eventDateTime: event.dateTime,
      venueName: event.venueName,
      location: event.location,
      bannerUrl: event.imageUrl,
      organizerId: event.organizerId,
      userId: user.id,
      userName: user.name,
      userEmail: user.email,
      qrPayload: _ticketPayload(event.id, id),
      issuedAt: DateTime.now(),
      status: TicketStatus.valid,
    );
  }

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String _randomToken(int length) {
    final rng = Random.secure();
    return List.generate(length, (_) => _alphabet[rng.nextInt(_alphabet.length)]).join();
  }

  /// One-of-a-kind pass code for ONE attendee at ONE event:
  ///   EP-<event>-<attendee fingerprint>-<random>
  /// The fingerprint comes from the ticket id (event + attendee), so two people (or two
  /// events) can never share a code; the random part makes it impossible to guess.
  /// The QR carries no name, email or other personal data.
  static String _ticketPayload(String eventId, String ticketId) {
    var h = 0x811c9dc5; // FNV-1a hash of the ticket id
    for (final unit in ticketId.codeUnits) {
      h = ((h ^ unit) * 16777619) & 0xFFFFFFFF;
    }
    final who = h.toRadixString(36).toUpperCase().padLeft(7, '0');
    var ev = eventId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (ev.length > 10) ev = ev.substring(0, 10);
    return 'EP-$ev-$who-${_randomToken(8)}';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Check-in
  // ═════════════════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> checkInTicketWithCode(
    String qrPayload, {
    String? targetEventId,
  }) async {
    final clean = qrPayload.trim().toUpperCase();
    if (clean.isEmpty) return _invalid();
    final result =
        useFirebase ? await _checkInRemote(clean, targetEventId) : _checkInLocal(clean, targetEventId);

    if (result['success'] == true && result['ticket'] is TicketModel) {
      await _afterCheckIn(result['ticket'] as TicketModel);
    }
    return result;
  }

  /// Organizer gets an instant on-screen confirmation; the attendee gets a notification
  /// (which pops up on their phone if the app is open, and is saved in their tray).
  Future<void> _afterCheckIn(TicketModel ticket) async {
    final at = ticket.checkedInAt ?? DateTime.now();
    final time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    _flash(
      title: 'Checked in: ${ticket.userName}',
      message: '${ticket.eventTitle} • $time',
      type: 'checkin',
      eventId: ticket.eventId,
    );
    await _notifyUser(
      ticket.userId,
      title: "You're checked in!",
      message: 'Welcome to ${ticket.eventTitle}. Checked in at $time.',
      type: 'checkin',
      eventId: ticket.eventId,
      popup: false, // the organizer's device already showed one; the attendee's shows its own
    );
  }

  Map<String, dynamic> _invalid() => {
        'success': false,
        'status': 'invalid',
        'message': 'Invalid QR Code: Unrecognized pass payload or forged code.',
      };

  /// Shared decision logic so demo and Firebase behave identically.
  Map<String, dynamic>? _rejectionFor(TicketModel ticket, String? targetEventId) {
    if (targetEventId != null &&
        targetEventId.isNotEmpty &&
        targetEventId != 'all' &&
        ticket.eventId != targetEventId) {
      return {
        'success': false,
        'status': 'wrong_event',
        'message': 'Wrong Event! Pass is for "${ticket.eventTitle}", NOT this meetup.',
        'ticket': ticket,
      };
    }
    if (ticket.status == TicketStatus.cancelled) {
      return {
        'success': false,
        'status': 'invalid',
        'message': 'This pass has been cancelled.',
        'ticket': ticket,
      };
    }
    if (ticket.status == TicketStatus.checkedIn) {
      final at = ticket.checkedInAt;
      final time = at != null
          ? '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'
          : 'earlier';
      return {
        'success': false,
        'status': 'already_used',
        'message': 'Duplicate Pass! Already checked in at $time. Re-entry prevented.',
        'ticket': ticket,
      };
    }
    return null;
  }

  Map<String, dynamic> _approved(TicketModel ticket) => {
        'success': true,
        'status': 'valid',
        'message': 'Entry Approved! Welcome ${ticket.userName} (${ticket.eventTitle})',
        'ticket': ticket,
      };

  Map<String, dynamic> _checkInLocal(String clean, String? targetEventId) {
    final i = _userTickets.indexWhere(
      (t) => t.qrPayload.toUpperCase() == clean || t.id.toUpperCase() == clean,
    );
    if (i == -1) return _invalid();

    final rejection = _rejectionFor(_userTickets[i], targetEventId);
    if (rejection != null) return rejection;

    final updated = _userTickets[i].copyWith(
      status: TicketStatus.checkedIn,
      checkedInAt: DateTime.now(),
    );
    _userTickets = [..._userTickets]..[i] = updated;
    notifyListeners();
    return _approved(updated);
  }

  Future<Map<String, dynamic>> _checkInRemote(String clean, String? targetEventId) async {
    try {
      // Organizers can only look up tickets for their own events (also enforced by rules).
      Query<Map<String, dynamic>> query =
          _db.collection('tickets').where('qrPayload', isEqualTo: clean);
      if (_boundRole == UserRole.organizer) {
        query = query.where('organizerId', isEqualTo: _boundUid);
      }
      final found = await query.limit(1).get();
      if (found.docs.isEmpty) return _invalid();

      final ref = found.docs.first.reference;
      return await _db.runTransaction<Map<String, dynamic>>((tx) async {
        final snap = await tx.get(ref); // re-read inside the transaction: no double check-in
        if (!snap.exists) return _invalid();
        final ticket = TicketModel.fromJson({...snap.data()!, 'id': snap.id});

        final rejection = _rejectionFor(ticket, targetEventId);
        if (rejection != null) return rejection;

        final now = DateTime.now();
        tx.update(ref, {
          'status': TicketStatus.checkedIn.name,
          'checkedIn': true,
          'checkedInAt': now.toIso8601String(),
        });
        return _approved(ticket.copyWith(status: TicketStatus.checkedIn, checkedInAt: now));
      });
    } on FirebaseException catch (e) {
      return {
        'success': false,
        'status': 'error',
        'message': _dataMessage(e),
      };
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Organizer & admin actions
  // ═════════════════════════════════════════════════════════════════════════
  /// Organizers' events start as `pending` and go live once an admin approves.
  /// Admin-created events are approved immediately.
  Future<EventModel> createEvent({
    required String title,
    required String description,
    required String category,
    required DateTime dateTime,
    required String location,
    required String venueName,
    required String imageUrl,
    required UserModel organizer,
    required int capacity,
    double price = 0.0,
    List<String> tags = const [],
  }) async {
    if (organizer.role != UserRole.organizer && organizer.role != UserRole.admin) {
      throw const ServiceException('Only approved organizers can create events.');
    }
    if (title.trim().isEmpty) throw const ServiceException('Please enter an event title.');
    if (capacity < 1) throw const ServiceException('Capacity must be at least 1.');

    final isAdmin = organizer.role == UserRole.admin;
    final id = useFirebase
        ? _db.collection('events').doc().id
        : 'evt_${DateTime.now().millisecondsSinceEpoch}';

    final event = EventModel(
      id: id,
      title: title.trim(),
      description: description,
      category: category,
      dateTime: dateTime,
      location: location,
      venueName: venueName,
      imageUrl: imageUrl.isNotEmpty
          ? imageUrl
          : 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
      organizerId: organizer.id,
      organizerName: organizer.name,
      organizerAvatar: organizer.avatarUrl,
      organizerEmail: organizer.email,
      capacity: capacity,
      registeredCount: 0,
      price: price,
      tags: tags,
      status: EventStatus.upcoming,
      approvalStatus: isAdmin ? ApprovalStatus.approved : ApprovalStatus.pending,
      registrationCode: 'EP-EVT-${_randomToken(8)}',
    );

    if (useFirebase) {
      try {
        await _db.collection('events').doc(id).set(event.toJson());
      } on FirebaseException catch (e) {
        throw ServiceException(_dataMessage(e));
      }
    } else {
      _events = [event, ..._events];
      notifyListeners();
    }
    return event;
  }

  Future<void> approveEvent(String eventId) => _setApproval(eventId, ApprovalStatus.approved);

  Future<void> rejectEvent(String eventId, {String? reason}) =>
      _setApproval(eventId, ApprovalStatus.rejected, reason: reason);

  Future<void> _setApproval(String eventId, ApprovalStatus status, {String? reason}) async {
    final i = _events.indexWhere((e) => e.id == eventId);
    if (i == -1) return;
    final event = _events[i];

    if (useFirebase) {
      try {
        await _db.collection('events').doc(eventId).update({
          'approvalStatus': status.name,
          if (reason != null) 'rejectionReason': reason,
        });
      } on FirebaseException catch (e) {
        throw ServiceException(_dataMessage(e));
      }
    } else {
      _events[i] = event.copyWith(approvalStatus: status, rejectionReason: reason);
      notifyListeners();
    }

    final approved = status == ApprovalStatus.approved;
    await _notifyUser(
      event.organizerId,
      title: approved ? 'Event approved' : 'Event declined',
      message: approved
          ? '"${event.title}" is now live.'
          : '"${event.title}" was not approved${reason == null ? '.' : ': $reason'}',
      type: 'approval',
      eventId: eventId,
    );
  }

  Future<void> approveOrganizerApplication(OrganizerApplicationModel app) =>
      _reviewApplication(app, approve: true);

  Future<void> rejectOrganizerApplication(OrganizerApplicationModel app) =>
      _reviewApplication(app, approve: false);

  Future<void> _reviewApplication(OrganizerApplicationModel app, {required bool approve}) async {
    if (useFirebase) {
      try {
        final batch = _db.batch();
        batch.update(_db.collection('organizerApplications').doc(app.id), {
          'status': approve ? 'approved' : 'rejected',
        });
        if (approve) {
          batch.update(_db.collection('users').doc(app.userId), {
            'role': 'organizer',
            'isOrganizerApproved': true,
            'organization': app.organizationName,
          });
        }
        await batch.commit();
      } on FirebaseException catch (e) {
        throw ServiceException(_dataMessage(e));
      }
    } else {
      _applications = _applications.where((a) => a.id != app.id).toList();
      notifyListeners();
    }

    await _notifyUser(
      app.userId,
      title: approve ? 'Organizer application approved' : 'Organizer application declined',
      message: approve
          ? 'You can now create events for ${app.organizationName}.'
          : 'Your organizer application was not approved.',
      type: 'approval',
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Ticket reminders
  // ═════════════════════════════════════════════════════════════════════════
  void toggleTicketReminder(String ticketId) {
    final i = _userTickets.indexWhere((t) => t.id == ticketId);
    if (i == -1) return;
    _updateReminder(i, reminderEnabled: !_userTickets[i].reminderEnabled);
  }

  void setTicketReminderTiming(String ticketId, String timing) {
    final i = _userTickets.indexWhere((t) => t.id == ticketId);
    if (i == -1) return;
    _updateReminder(i, reminderTiming: timing);
  }

  void _updateReminder(int index, {bool? reminderEnabled, String? reminderTiming}) {
    final current = _userTickets[index];
    final updated = current.copyWith(
      reminderEnabled: reminderEnabled,
      reminderTiming: reminderTiming,
    );
    _userTickets = [..._userTickets]..[index] = updated; // optimistic
    notifyListeners();

    if (useFirebase) {
      _db.collection('tickets').doc(current.id).update({
        if (reminderEnabled != null) 'reminderEnabled': reminderEnabled,
        if (reminderTiming != null) 'reminderTiming': reminderTiming,
      }).catchError((Object e) {
        debugPrint('Reminder update failed: $e');
      });
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Notifications
  // ═════════════════════════════════════════════════════════════════════════
  void markNotificationAsRead(String id) {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i == -1) return;
    _notifications = [..._notifications]..[i] = _notifications[i].copyWith(isRead: true);
    notifyListeners();
    if (useFirebase) {
      _db.collection('notifications').doc(id).update({'isRead': true, 'read': true}).catchError(
        (Object e) => debugPrint('Mark-read failed: $e'),
      );
    }
  }

  void markAllNotificationsAsRead() {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
    if (useFirebase) {
      final batch = _db.batch();
      for (final n in unread) {
        batch.update(_db.collection('notifications').doc(n.id), {'isRead': true, 'read': true});
      }
      batch.commit().catchError((Object e) => debugPrint('Mark-all-read failed: $e'));
    }
  }

  /// Adds a notification for the signed-in user.
  void addNotification({
    required String title,
    required String message,
    String type = 'reminder',
    String? eventId,
  }) {
    _notifyUser(_boundUid ?? '', title: title, message: message, type: type, eventId: eventId);
  }

  Future<void> _notifyUser(
    String userId, {
    required String title,
    required String message,
    String type = 'reminder',
    String? eventId,
    bool popup = true,
    String? docId, // fixed id = "send at most once", even across restarts or devices
  }) async {
    final notification = NotificationModel(
      id: docId ?? 'notif_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      eventId: eventId,
    );

    if (!useFirebase) {
      _notifications = [notification, ..._notifications];
      notifyListeners();
      if (popup) _emit(notification);
      return;
    }
    if (userId.isEmpty) return;
    try {
      final col = _db.collection('notifications');
      if (docId != null) {
        final ref = col.doc(docId);
        if ((await ref.get()).exists) return;
        await ref.set(notification.toJson()..remove('id'));
      } else {
        await col.add(notification.toJson()..remove('id'));
      }
      // Notifications for someone else pop up on THEIR device through the listener.
      if (popup && userId == _currentUid) _emit(notification);
    } catch (e) {
      // A failed notification must never block the action that triggered it.
      debugPrint('Notification not saved: $e');
    }
  }

  void _emit(NotificationModel n) {
    if (!_incoming.isClosed) _incoming.add(n);
  }

  /// On-screen popup only (not saved anywhere).
  void _flash({
    required String title,
    required String message,
    String type = 'checkin',
    String? eventId,
  }) {
    _emit(NotificationModel(
      id: 'flash_${DateTime.now().microsecondsSinceEpoch}',
      userId: _currentUid ?? '',
      title: title,
      message: message,
      timestamp: DateTime.now(),
      type: type,
      eventId: eventId,
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Ticket reminders (fire while the app is open)
  // ═════════════════════════════════════════════════════════════════════════
  void _startReminderTimer() {
    if (_reminderTimer != null || _disposed || _currentUid == null) return;
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
    Future.delayed(const Duration(seconds: 3), _checkReminders);
  }

  void _stopReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = null;
  }

  Duration? _leadFor(String timing) {
    final t = timing.toLowerCase();
    if (t.startsWith('15m')) return const Duration(minutes: 15);
    if (t.startsWith('1 hour')) return const Duration(hours: 1);
    if (t.startsWith('3 hours')) return const Duration(hours: 3);
    if (t.startsWith('1 day')) return const Duration(days: 1);
    return null;
  }

  Future<void> _checkReminders() async {
    final uid = _currentUid;
    if (uid == null || _disposed) return;
    final now = DateTime.now();

    for (final t in List<TicketModel>.of(_userTickets)) {
      if (t.userId != uid || !t.reminderEnabled || t.status != TicketStatus.valid) continue;
      final lead = _leadFor(t.reminderTiming);
      if (lead == null) continue;

      final start = t.eventDateTime;
      if (!now.isBefore(start) || now.isBefore(start.subtract(lead))) continue; // not due, or already started

      final timingKey = t.reminderTiming.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
      final key = 'reminder_${t.id}_$timingKey';
      if (!_remindedKeys.add(key)) continue;

      final mins = start.difference(now).inMinutes;
      final when = mins >= 90
          ? 'in about ${(mins / 60).round()} hours'
          : (mins <= 1 ? 'in a moment' : 'in $mins minutes');
      await _notifyUser(
        uid,
        title: 'Reminder: ${t.eventTitle}',
        message: 'Starts $when at ${t.venueName}. Have your QR pass ready.',
        type: 'reminder',
        eventId: t.eventId,
        docId: key,
      );
    }
  }

  // ── Errors & lifecycle ───────────────────────────────────────────────────
  String _dataMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that (permission-denied).';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No connection to the server. Please try again.';
      case 'failed-precondition':
        return 'The database needs an index or was changed. Please try again.';
      default:
        return 'Could not complete that action. Please try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopReminderTimer();
    _incoming.close();
    _cancelSubs();
    super.dispose();
  }
}
