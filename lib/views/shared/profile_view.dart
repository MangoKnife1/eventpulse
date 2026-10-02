import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../models/organizer_application_model.dart';
import 'user_avatar.dart';
import '../../services/cloudinary_service.dart';
import '../../services/service_exception.dart';
import 'auth_modal_bottom_sheet.dart';
import 'legal_documents_view.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar(AuthService auth) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploadingAvatar = true);
    try {
      final url =
          await CloudinaryService.pickAndUpload(folder: 'eventpulse/avatars');
      if (url != null) {
        await auth.updateProfile(avatarUrl: url);
        messenger.showSnackBar(
            const SnackBar(content: Text('Profile photo updated.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// Wraps the avatar so signed-in users can tap it to upload a new photo.
  Widget _buildAvatar(AuthService auth, Widget avatar) {
    if (!auth.isAuthenticated) return avatar;
    return GestureDetector(
      onTap: _uploadingAvatar ? null : () => _changeAvatar(auth),
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          if (_uploadingAvatar)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Color(0xFFFF5238), shape: BoxShape.circle),
              child:
                  const Icon(Icons.camera_alt, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final eventService = Provider.of<EventService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final application = eventService.ownApplication;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            // Profile In-page Header
            Text(
              'Profile & Settings',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Current User Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  _buildAvatar(
                    auth,
                    UserAvatar(
                      radius: 28,
                      url: auth.isAuthenticated
                          ? auth.currentUser.avatarUrl
                          : '',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                auth.isAuthenticated
                                    ? auth.currentUser.name
                                    : 'Guest User',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (auth.isAuthenticated) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 15, color: Color(0xFF0EA5E9)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.isAuthenticated
                              ? auth.currentUser.email
                              : 'Sign in to register and save passes',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF5238).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            auth.isAuthenticated
                                ? 'ROLE: ${auth.currentUser.role.name.toUpperCase()}'
                                : 'ROLE: GUEST',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF5238),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!auth.isAuthenticated)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5238),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => AuthModalBottomSheet.show(context),
                      icon: const Icon(Icons.login, size: 14),
                      label: const Text('Sign In',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      tooltip: 'Sign Out to Guest Mode',
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                      onPressed: () {
                        auth.signOut();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content:
                                Text('Signed out. Viewing meetups as a guest.'),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            if (auth.isAuthenticated &&
                auth.currentUser.role.name == 'attendee' &&
                application != null) ...[
              _buildApplicationStatus(application, isDark),
              const SizedBox(height: 18),
            ],

            // App Preferences
            Text(
              'Preferences',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      activeTrackColor: const Color(0xFFFF5238),
                      secondary: Icon(
                          auth.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                      title: const Text('Dark Mode Appearance',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      value: auth.isDarkMode,
                      onChanged: (_) => auth.toggleDarkMode(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Text(
              'Legal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.policy_outlined),
                  title: const Text('Privacy & Terms',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Read how EventPulse handles data and use of the service',
                      style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const LegalDocumentsView()),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationStatus(
      OrganizerApplicationModel application, bool isDark) {
    final isPending = application.status == ApplicationStatus.pending;
    final isApproved = application.status == ApplicationStatus.approved;
    final color = isPending
        ? const Color(0xFFF59E0B)
        : (isApproved ? const Color(0xFF10B981) : Colors.redAccent);
    final title = isPending
        ? 'Organizer application under review'
        : (isApproved
            ? 'Organizer application approved'
            : 'Organizer application declined');
    final detail = isPending
        ? 'An admin will review ${application.organizationName}.'
        : (isApproved
            ? 'Sign in again to access the organizer dashboard and scanner.'
            : 'You can submit a new application with updated information.');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
              isPending
                  ? Icons.hourglass_top
                  : (isApproved ? Icons.check_circle : Icons.info),
              color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text(detail,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
