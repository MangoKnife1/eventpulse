import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

// Services & Models
import 'services/auth_service.dart';
import 'services/event_service.dart';
import 'services/camera_service.dart';
import 'models/notification_model.dart';
import 'models/user_model.dart';

// Segregated Views per Role
import 'views/attendee/attendee_events_view.dart';
import 'views/attendee/attendee_passes_view.dart';
import 'views/organizer/organizer_dashboard_view.dart';
import 'views/organizer/organizer_scanner_view.dart';
import 'views/admin/admin_governance_view.dart';
import 'views/shared/profile_view.dart';
import 'views/shared/notification_center_modal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final firebaseReady = await _initFirebase();
  runApp(EventPulseApp(firebaseReady: firebaseReady));
}

/// Connects to Firebase. If it isn't configured yet (no `flutterfire configure`),
/// the app falls back to offline demo mode instead of crashing.
Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return true;
  } catch (e) {
    debugPrint('Firebase unavailable, running in demo mode: $e');
    return false;
  }
}

/// Lets services trigger on-screen popups (notifications) without a BuildContext.
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

class EventPulseApp extends StatelessWidget {
  /// `false` = offline demo mode (sample data, simulated login).
  final bool firebaseReady;

  const EventPulseApp({super.key, this.firebaseReady = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(useFirebase: firebaseReady)),
        // Re-subscribes to the right Firestore queries when the signed-in user or role changes.
        ChangeNotifierProxyProvider<AuthService, EventService>(
          create: (_) => EventService(useFirebase: firebaseReady),
          update: (_, auth, events) {
            events!.bindUser(auth.currentUser, signedIn: auth.isAuthenticated);
            return events;
          },
        ),
      ],
      child: Consumer<AuthService>(
        builder: (context, auth, _) {
          return MaterialApp(
            scaffoldMessengerKey: appMessengerKey,
            title: 'EventPulse',
            debugShowCheckedModeBanner: false,
            themeMode: auth.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFFFF5238),
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Color(0xFFF8FAFC),
                foregroundColor: Color(0xFF0F172A),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color(0xFFFF5238),
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF090D16),
              textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Color(0xFF090D16),
                foregroundColor: Colors.white,
              ),
            ),
            home: const MainMobileNavigation(),
          );
        },
      ),
    );
  }
}

class MainMobileNavigation extends StatefulWidget {
  const MainMobileNavigation({super.key});

  @override
  State<MainMobileNavigation> createState() => _MainMobileNavigationState();
}

class _MainMobileNavigationState extends State<MainMobileNavigation> {
  int _currentIndex = 0;
  UserRole? _lastRole;
  StreamSubscription<NotificationModel>? _popupSub;
  EventService? _popupService;
  final List<NotificationModel> _pendingPopups = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<EventService>();
    if (identical(service, _popupService)) return;

    _popupSub?.cancel();
    _popupService = service;
    // Every notification that arrives while the app is open pops up here.
    _popupSub = service.incomingNotifications.listen(_showPopup);
    WidgetsBinding.instance.addPostFrameCallback((_) => _flushPopups());
  }

  @override
  void dispose() {
    _popupSub?.cancel();
    super.dispose();
  }

  void _showPopup(NotificationModel n) {
    final messenger = appMessengerKey.currentState;
    if (!mounted) return;
    if (messenger == null) {
      _pendingPopups.add(n);
      WidgetsBinding.instance.addPostFrameCallback((_) => _flushPopups());
      return;
    }
    _displayPopup(messenger, n);
  }

  void _flushPopups() {
    if (!mounted || _pendingPopups.isEmpty) return;
    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;
    final pending = List<NotificationModel>.of(_pendingPopups);
    _pendingPopups.clear();
    for (final n in pending) {
      _displayPopup(messenger, n);
    }
  }

  void _displayPopup(ScaffoldMessengerState messenger, NotificationModel n) {

    IconData icon;
    Color color;
    switch (n.type) {
      case 'reminder':
        icon = Icons.alarm;
        color = const Color(0xFFFF5238);
        break;
      case 'checkin':
        icon = Icons.qr_code_2;
        color = const Color(0xFF0EA5E9);
        break;
      case 'registration':
        icon = Icons.person_add_alt_1;
        color = const Color(0xFFA855F7);
        break;
      default:
        icon = Icons.verified_user;
        color = const Color(0xFF10B981);
    }

    HapticFeedback.mediumImpact();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          backgroundColor: const Color(0xFF1E293B),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: color.withValues(alpha: 0.6)),
          ),
          content: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'VIEW',
            textColor: color,
            onPressed: () {
              if (mounted) NotificationCenterModal.show(context);
            },
          ),
        ),
      );
  }

  void _showRoleSelector(BuildContext context, AuthService auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Switch Segregated Role View',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Experience EventPulse from each participant perspective for academic demo:',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              _buildRoleItem(
                ctx,
                auth,
                role: UserRole.attendee,
                title: 'Attendee / Community Member',
                desc: 'Discover events, register & display dynamic QR check-in pass',
                icon: Icons.person_outline,
                color: const Color(0xFF3B82F6),
              ),
              const SizedBox(height: 10),
              _buildRoleItem(
                ctx,
                auth,
                role: UserRole.organizer,
                title: 'Event Organizer & Host',
                desc: 'Manage listings, attendee rosters & door scanner terminal',
                icon: Icons.business_center_outlined,
                color: const Color(0xFFFF5238),
              ),
              const SizedBox(height: 10),
              _buildRoleItem(
                ctx,
                auth,
                role: UserRole.admin,
                title: 'Platform Governance & Admin',
                desc: 'Review pending submissions, enforce safety & platform metrics',
                icon: Icons.shield_outlined,
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleItem(
    BuildContext context,
    AuthService auth, {
    required UserRole role,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = auth.currentRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        auth.switchRole(role);
        setState(() => _currentIndex = 0);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Reset tab index if role switched
    if (_lastRole != auth.currentRole) {
      _lastRole = auth.currentRole;
      _currentIndex = 0;
    }

    // Role-Segregated Views and Navigation Destinations
    List<Widget> activeViews;
    List<NavigationDestination> destinations;

    switch (auth.currentRole) {
      case UserRole.attendee:
        activeViews = [
          AttendeeEventsView(
            onNavigateToTicket: (eventId) {
              setState(() => _currentIndex = 1);
            },
          ),
          AttendeePassesView(
            onDiscoverEvents: () {
              setState(() => _currentIndex = 0);
            },
          ),
          const ProfileView(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, size: 22),
            selectedIcon: Icon(Icons.explore, color: Color(0xFFFF5238), size: 22),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_2_outlined, size: 22),
            selectedIcon: Icon(Icons.qr_code_2, color: Color(0xFFFF5238), size: 22),
            label: 'My Passes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 22),
            selectedIcon: Icon(Icons.person, color: Color(0xFFFF5238), size: 22),
            label: 'Profile',
          ),
        ];
        break;

      case UserRole.organizer:
        activeViews = [
          const OrganizerDashboardView(),
          const OrganizerScannerView(),
          AttendeeEventsView(
            onNavigateToTicket: (_) => setState(() => _currentIndex = 0),
          ),
          const ProfileView(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFFFF5238), size: 22),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined, size: 22),
            selectedIcon: Icon(Icons.qr_code_scanner, color: Color(0xFFFF5238), size: 22),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined, size: 22),
            selectedIcon: Icon(Icons.travel_explore, color: Color(0xFFFF5238), size: 22),
            label: 'Directory',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 22),
            selectedIcon: Icon(Icons.person, color: Color(0xFFFF5238), size: 22),
            label: 'Profile',
          ),
        ];
        break;

      case UserRole.admin:
        activeViews = [
          const AdminGovernanceView(),
          AttendeeEventsView(
            onNavigateToTicket: (_) => setState(() => _currentIndex = 0),
          ),
          const ProfileView(),
        ];
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.shield_outlined, size: 22),
            selectedIcon: Icon(Icons.shield, color: Color(0xFF10B981), size: 22),
            label: 'Governance',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined, size: 22),
            selectedIcon: Icon(Icons.view_list, color: Color(0xFF10B981), size: 22),
            label: 'All Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, size: 22),
            selectedIcon: Icon(Icons.person, color: Color(0xFF10B981), size: 22),
            label: 'Profile',
          ),
        ];
        break;
    }

    // Ensure _currentIndex is within bounds
    if (_currentIndex >= activeViews.length) {
      _currentIndex = 0;
    }

    final eventService = Provider.of<EventService>(context);
    final Color roleBadgeColor = auth.isAttendee
        ? const Color(0xFF3B82F6)
        : (auth.isOrganizer ? const Color(0xFFFF5238) : const Color(0xFF10B981));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5238),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'EP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'EventPulse',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          // Notification Bell
          Stack(
            children: [
              IconButton(
                tooltip: 'Notification Center',
                icon: const Icon(Icons.notifications_none, size: 20),
                onPressed: () => NotificationCenterModal.show(context),
              ),
              if (eventService.unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5238),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '${eventService.unreadNotificationsCount}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Role badge. Tapping switches roles only in offline demo mode.
          InkWell(
            onTap: auth.demoMode ? () => _showRoleSelector(context, auth) : null,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: roleBadgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleBadgeColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: auth.isAuthenticated ? roleBadgeColor : const Color(0xFFFF5238),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    auth.isAuthenticated ? auth.currentRole.name.toUpperCase() : 'GUEST',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: auth.isAuthenticated ? roleBadgeColor : const Color(0xFFFF5238),
                    ),
                  ),
                  if (auth.demoMode) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: auth.isAuthenticated ? roleBadgeColor : const Color(0xFFFF5238),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: auth.isDarkMode ? 'Light Theme' : 'Dark Theme',
            icon: Icon(auth.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 20),
            onPressed: () => auth.toggleDarkMode(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: activeViews,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) async {
            if (auth.isOrganizer && idx == 1 && _currentIndex != 1) {
              await CameraService.instance.checkBeforeOpeningScanner(
                context: context,
                featureTitle: 'Live Door QR Scanner',
                onGranted: () {
                  if (mounted) setState(() => _currentIndex = idx);
                },
                onDenied: () {
                  if (mounted) setState(() => _currentIndex = idx);
                },
              );
            } else {
              setState(() => _currentIndex = idx);
            }
          },
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF090D16) : Colors.white,
          indicatorColor: roleBadgeColor.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }
}

/// Convenience alias for default Flutter templates and test runners
typedef MyApp = EventPulseApp;
