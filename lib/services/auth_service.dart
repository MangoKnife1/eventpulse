import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/organizer_application_model.dart';
import '../models/user_model.dart';
import 'demo_data.dart';
import 'firebase_refs.dart';
import 'service_exception.dart';

/// Handles sign-in state and the signed-in user's profile.
///
/// * Firebase mode  (`useFirebase: true`): Firebase Auth + `users/{uid}` in Firestore.
/// * Demo mode      (default): simulated login with sample profiles, no network.
///
/// Roles are never chosen by the client. Everyone signs up as an attendee;
/// organizers apply and an admin approves; admins are set in the Firebase console.
class AuthService extends ChangeNotifier {
  AuthService({this.useFirebase = false}) : _currentUser = UserModel.guest() {
    if (useFirebase) {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(
            _onAuthChanged,
            onError: (Object e) => debugPrint('Auth state error: $e'),
          );
    }
  }

  final bool useFirebase;
  bool get demoMode => !useFirebase;

  // ── State ────────────────────────────────────────────────────────────────
  UserModel _currentUser;
  bool _isDarkMode = true;
  bool _isAuthenticated = false; // guests can browse events before signing in
  String? _pendingEventIdToRegister;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool _registering = false;
  bool _disposed = false;

  UserModel get currentUser => _currentUser;
  UserRole get currentRole => _currentUser.role;
  bool get isDarkMode => _isDarkMode;
  bool get isAuthenticated => _isAuthenticated;
  String? get pendingEventIdToRegister => _pendingEventIdToRegister;

  bool get isAttendee => _currentUser.role == UserRole.attendee;
  bool get isOrganizer => _currentUser.role == UserRole.organizer;
  bool get isAdmin => _currentUser.role == UserRole.admin;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setPendingEventId(String? eventId) {
    _pendingEventIdToRegister = eventId;
    notifyListeners();
  }

  // ── Email / password ─────────────────────────────────────────────────────
  Future<UserModel> loginWithEmail(
    String email,
    String password, {
    UserRole? preferredRole,
  }) async {
    if (demoMode) return _demoLogin(email, preferredRole);

    _requireCredentials(email, password);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user!;
      if (!fbUser.emailVerified) {
        await fbUser.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        _setGuest();
        throw ServiceException(
          'Please verify your email first. We just sent a new verification link to '
          '${fbUser.email ?? email.trim()}. Check your Spam folder too, open the link, then sign in again.',
        );
      }
      await _signInLocal(fbUser);
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      throw ServiceException(_authMessage(e));
    } on FirebaseException catch (e) {
      throw ServiceException(_dataMessage(e));
    }
  }

  Future<UserModel> registerAsAttendee(
      String name, String email, String password) async {
    if (demoMode) return _demoRegister(name, email, UserRole.attendee, '', '');

    _requireCredentials(email, password);
    return _createAccount(name: name, email: email, password: password);
  }

  /// Creates an attendee account and files an organizer application for an
  /// admin to review. The role is upgraded only when an admin approves it.
  Future<UserModel> registerAsOrganizer(
    String name,
    String email,
    String organization, {
    String reason = '',
    String password = '',
  }) async {
    if (demoMode) {
      return _demoRegister(
          name, email, UserRole.organizer, organization, reason);
    }

    _requireCredentials(email, password);
    return _createAccount(
      name: name,
      email: email,
      password: password,
      organization: organization,
      applicationReason: reason,
    );
  }

  Future<UserModel> _createAccount({
    required String name,
    required String email,
    required String password,
    String organization = '',
    String? applicationReason,
  }) async {
    _registering =
        true; // stop the auth listener from creating a default profile first
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user!;
      final cleanName =
          name.trim().isEmpty ? _nameFromEmail(email) : name.trim();
      await fbUser.sendEmailVerification();
      await fbUser.updateDisplayName(cleanName);
      await _signInLocal(fbUser, name: cleanName, organization: organization);

      if (applicationReason != null) {
        final application = OrganizerApplicationModel(
          id: fbUser.uid, // one application per user
          userId: fbUser.uid,
          userName: cleanName,
          userEmail: fbUser.email ?? email.trim(),
          organizationName: organization.trim(),
          reason: applicationReason.trim(),
          submittedAt: DateTime.now(),
        );
        await appFirestore
            .collection('organizerApplications')
            .doc(fbUser.uid)
            .set(application.toJson());
      }
      await FirebaseAuth.instance.signOut();
      _setGuest();
      throw const ServiceException(
        'Account created. Check your email and verify your address before signing in.',
      );
    } on FirebaseAuthException catch (e) {
      throw ServiceException(_authMessage(e));
    } on FirebaseException catch (e) {
      throw ServiceException(_dataMessage(e));
    } finally {
      _registering = false;
    }
  }

  // ── Google ───────────────────────────────────────────────────────────────
  Future<UserModel> loginWithGoogle({UserRole? preferredRole}) async {
    if (demoMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      _setUser(preferredRole == UserRole.organizer
          ? DemoData.profiles()[1]
          : DemoData.profiles()[0]);
      return _currentUser;
    }

    try {
      final provider = GoogleAuthProvider();
      final auth = FirebaseAuth.instance;
      final cred = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      await _signInLocal(cred.user!, provider: 'google');
      return _currentUser;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in failed: ${e.code} ${e.message}');
      throw ServiceException(_googleMessage(e));
    } on FirebaseException catch (e) {
      throw ServiceException(_dataMessage(e));
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────
  /// Updates the signed-in user's editable profile fields.
  Future<void> updateProfile(
      {String? name, String? bio, String? avatarUrl}) async {
    if (!_isAuthenticated) {
      throw const ServiceException('Please sign in first.');
    }
    final updated =
        _currentUser.copyWith(name: name, bio: bio, avatarUrl: avatarUrl);

    if (useFirebase) {
      try {
        await appFirestore.collection('users').doc(_currentUser.id).update({
          if (name != null) 'name': name,
          if (bio != null) 'bio': bio,
          if (avatarUrl != null) ...{
            'avatarUrl': avatarUrl,
            'avatar': avatarUrl
          },
        });
      } on FirebaseException catch (e) {
        throw ServiceException(_dataMessage(e));
      }
    }
    _currentUser = updated;
    notifyListeners();
  }

  Future<void> signOut() async {
    _pendingEventIdToRegister = null;
    if (useFirebase) {
      await _profileSub?.cancel();
      _profileSub = null;
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Sign-out error: $e');
      }
    }
    _setGuest();
  }

  // ── Firebase internals ───────────────────────────────────────────────────
  Future<void> _onAuthChanged(User? fbUser) async {
    if (_registering) return; // the register flow finishes the profile itself
    if (fbUser == null) {
      await _profileSub?.cancel();
      _profileSub = null;
      _setGuest();
      return;
    }
    if (fbUser.providerData
            .every((provider) => provider.providerId == 'password') &&
        !fbUser.emailVerified) {
      await FirebaseAuth.instance.signOut();
      _setGuest();
      return;
    }
    if (_isAuthenticated && _currentUser.id == fbUser.uid) return;
    try {
      await _signInLocal(fbUser); // restores the session after an app restart
    } catch (e) {
      debugPrint('Could not load profile: $e');
    }
  }

  /// Loads (or creates) `users/{uid}`, then keeps it in sync so role changes
  /// made by an admin show up live.
  Future<void> _signInLocal(
    User fbUser, {
    String? name,
    String? provider,
    String organization = '',
  }) async {
    final ref = appFirestore.collection('users').doc(fbUser.uid);
    var snap = await ref.get();

    if (!snap.exists) {
      final profile = UserModel(
        id: fbUser.uid,
        name: name ?? fbUser.displayName ?? _nameFromEmail(fbUser.email),
        email: fbUser.email ?? '',
        avatarUrl: fbUser.photoURL ?? UserModel.defaultAvatar,
        role: UserRole.attendee, // roles are never self-assigned
        organization: organization,
        joinedDate: DateTime.now().toIso8601String().split('T').first,
        authProvider: provider ?? _providerOf(fbUser),
      );
      await ref.set(profile.toJson());
      snap = await ref.get();
    }

    _setUser(UserModel.fromJson({...snap.data()!, 'id': fbUser.uid}));

    await _profileSub?.cancel();
    _profileSub = ref.snapshots().listen(
      (s) {
        final data = s.data();
        if (data == null || _disposed) return;
        _currentUser = UserModel.fromJson({...data, 'id': s.id});
        notifyListeners();
      },
      onError: (Object e) => debugPrint('Profile sync error: $e'),
    );
  }

  String _providerOf(User u) =>
      u.providerData.any((p) => p.providerId == 'google.com')
          ? 'google'
          : 'email';

  void _requireCredentials(String email, String password) {
    if (email.trim().isEmpty) {
      throw const ServiceException('Please enter your email address.');
    }
    if (password.isEmpty) {
      throw const ServiceException('Please enter your password.');
    }
  }

  /// Google sign-in has its own failure modes; the short code is always shown
  /// so a screenshot is enough to diagnose it.
  String _googleMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'unauthorized-domain':
        return 'This website address is not allowed for sign-in. In Firebase: Authentication > Settings > '
            'Authorized domains, add it (localhost is normally there). (${e.code})';
      case 'popup-blocked':
        return 'The sign-in popup was blocked by the browser. Allow popups for this site and try again. (${e.code})';
      case 'account-exists-with-different-credential':
        return 'An account with this email already exists with a different sign-in method. '
            'Sign in with your email and password instead. (${e.code})';
      case 'operation-not-allowed':
        return 'Google sign-in is not enabled. In Firebase: Authentication > Sign-in method > Google > Enable. (${e.code})';
      case 'invalid-credential':
      case 'web-internal-error':
      case 'internal-error':
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'Google sign-in is not set up for this app yet. On Android, add your SHA-1 and SHA-256 '
            'fingerprints in Firebase project settings, then run "flutterfire configure" again. (${e.code})';
      default:
        return _authMessage(e);
    }
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in the Firebase console.';
      case 'canceled':
      case 'popup-closed-by-user':
      case 'web-context-canceled':
        return 'Sign-in was cancelled.';
      default:
        return 'Sign-in failed. Please try again. (${e.code})';
    }
  }

  String _dataMessage(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'You do not have permission to do that. Check the Firestore rules are deployed.';
    }
    if (e.code == 'unavailable' || e.code == 'network-request-failed') {
      return 'An internet connection is required to create an account. Please reconnect and try again.';
    }
    return 'Could not reach the database. Please try again.';
  }

  String _nameFromEmail(String? email) {
    final local = (email ?? 'member')
        .split('@')
        .first
        .replaceAll(RegExp(r'[._]'), ' ')
        .trim();
    return local.isEmpty ? 'Community Member' : local;
  }

  // ── State helpers ────────────────────────────────────────────────────────
  void _setUser(UserModel user) {
    _currentUser = user;
    _isAuthenticated = true;
    notifyListeners();
  }

  void _setGuest() {
    _currentUser = UserModel.guest();
    _isAuthenticated = false;
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Demo mode only (offline presentation without Firebase)
  // ═════════════════════════════════════════════════════════════════════════
  List<UserModel> get demoProfiles => List.unmodifiable(DemoData.profiles());

  void switchRole(UserRole role) {
    if (!demoMode) return;
    final profiles = DemoData.profiles();
    _setUser(
        profiles.firstWhere((p) => p.role == role, orElse: () => profiles[0]));
  }

  void selectProfile(UserModel profile) {
    if (!demoMode) return;
    _setUser(profile);
  }

  Future<UserModel> _demoLogin(String email, UserRole? preferredRole) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final trimmed = email.trim().toLowerCase();
    final profiles = DemoData.profiles();
    final existing = profiles.where((p) => p.email.toLowerCase() == trimmed);
    if (existing.isNotEmpty) {
      _setUser(existing.first);
      return _currentUser;
    }
    final role = preferredRole ?? UserRole.attendee;
    return _demoRegister(
        _nameFromEmail(email).toUpperCase(), email, role, '', '');
  }

  Future<UserModel> _demoRegister(
    String name,
    String email,
    UserRole role,
    String organization,
    String reason,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _setUser(UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'Community Member' : name.trim(),
      email: email.trim(),
      avatarUrl: UserModel.defaultAvatar,
      role: role,
      organization: organization.trim(),
      isOrganizerApproved: role != UserRole.attendee,
      bio: reason.isNotEmpty ? reason : 'EventPulse community member.',
      joinedDate: DateTime.now().toIso8601String().split('T').first,
      authProvider: 'email',
    ));
    return _currentUser;
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
