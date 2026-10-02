import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/service_exception.dart';
import '../../models/event_model.dart';
import '../../models/user_model.dart';

enum _AuthMode {
  login,
  registerAttendee,
  registerOrganizer,
}

class AuthModalBottomSheet extends StatefulWidget {
  final EventModel? pendingEvent;
  final VoidCallback? onSuccess;

  const AuthModalBottomSheet({
    super.key,
    this.pendingEvent,
    this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    EventModel? pendingEvent,
    VoidCallback? onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AuthModalBottomSheet(
        pendingEvent: pendingEvent,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<AuthModalBottomSheet> createState() => _AuthModalBottomSheetState();
}

class _AuthModalBottomSheetState extends State<AuthModalBottomSheet> {
  _AuthMode _mode = _AuthMode.login;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _orgController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _orgController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handlePostAuth(UserModel user, {String? notice}) async {
    final eventService = Provider.of<EventService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    String? snackText = notice;
    Color snackColor = const Color(0xFF10B981);

    if (widget.pendingEvent != null) {
      try {
        final tkt = await eventService.registerUserForEvent(
          event: widget.pendingEvent!,
          user: user,
        );
        snackText = 'Registration complete! Pass code: ${tkt.qrPayload}';
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = friendlyError(e));
        }
        return;
      }
    }

    if (snackText != null) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: snackColor,
          behavior: SnackBarBehavior.floating,
          content: Text(snackText, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess?.call();
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    if (_mode == _AuthMode.registerOrganizer && !auth.demoMode) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Organizer accounts need an application. Fill in the form below and register with email.';
      });
      return;
    }
    try {
      final preferredRole = _mode == _AuthMode.registerOrganizer
          ? UserRole.organizer
          : UserRole.attendee;
      final user = await auth.loginWithGoogle(preferredRole: preferredRole);
      await _handlePostAuth(user);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitForm() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text; // never trim a password
    final name = _nameController.text.trim();
    final org = _orgController.text.trim();
    final reason = _reasonController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      UserModel user;
      String? notice;
      if (_mode == _AuthMode.login) {
        user = await auth.loginWithEmail(email, password);
      } else if (_mode == _AuthMode.registerAttendee) {
        if (name.isEmpty) {
          setState(() {
            _errorMessage = 'Please provide your full name';
            _isLoading = false;
          });
          return;
        }
        user = await auth.registerAsAttendee(name, email, password);
      } else {
        if (name.isEmpty) {
          setState(() {
            _errorMessage = 'Please provide your full name';
            _isLoading = false;
          });
          return;
        }
        if (org.isEmpty) {
          setState(() {
            _errorMessage = 'Please enter your club or organization name';
            _isLoading = false;
          });
          return;
        }
        user = await auth.registerAsOrganizer(
          name,
          email,
          org,
          reason: reason,
          password: password,
        );
        if (!auth.demoMode) {
          notice = 'Application submitted! An admin will review it. '
              'You can attend events in the meantime.';
        }
      }

      await _handlePostAuth(user, notice: notice);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.92),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5238),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'EP',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'EventPulse',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5238).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF5238).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'Firebase & OAuth',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFF5238),
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _mode == _AuthMode.login
                      ? 'Sign In to EventPulse'
                      : _mode == _AuthMode.registerAttendee
                          ? 'Register as Attendee'
                          : _mode == _AuthMode.registerOrganizer
                              ? 'Register as Event Organizer'
                              : 'Admin Role Profile Setup',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.pendingEvent != null
                      ? 'Sign in required to claim your pass for: ${widget.pendingEvent!.title}'
                      : 'Discover community meetups, get dynamic QR passes, or host events',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.pendingEvent != null
                        ? const Color(0xFFFF5238)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    fontWeight: widget.pendingEvent != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),

                // Pending Event 1-Step RSVP Banner
                if (widget.pendingEvent != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5238).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF5238).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.event_available, color: Color(0xFFFF5238), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '1-Step RSVP: ${widget.pendingEvent!.title}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Your ticket with unique QR code will be generated immediately after sign-in.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Mode Tabs
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton('Sign In', _AuthMode.login),
                      _buildTabButton('Attendee', _AuthMode.registerAttendee),
                      _buildTabButton('Host / Club', _AuthMode.registerOrganizer),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                ...[
                  // Google OAuth Button
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
                        side: BorderSide(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitGoogle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                            height: 18,
                            width: 18,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.g_mobiledata,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Continue with Google / Gmail',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR WITH EMAIL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Name Field for Attendee or Organizer
                  if (_mode != _AuthMode.login) ...[
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Alex Rivera',
                      icon: Icons.person_outline,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Organizer fields
                  if (_mode == _AuthMode.registerOrganizer) ...[
                    _buildTextField(
                      controller: _orgController,
                      label: 'Club / Organization / Company Name',
                      hint: 'e.g. ACM Student Chapter / Tech Guild',
                      icon: Icons.business,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _reasonController,
                      label: 'Event Mission / Topics (Optional)',
                      hint: 'e.g. Mobile workshops, hackathons & networking',
                      icon: Icons.lightbulb_outline,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Email
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'name@example.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 10),

                  // Password
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: '••••••••',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 16),

                  // Submit button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5238),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submitForm,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _mode == _AuthMode.login
                                      ? 'Sign In to EventPulse'
                                      : _mode == _AuthMode.registerAttendee
                                          ? 'Create Attendee Account'
                                          : 'Create Event Organizer Account',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 16),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, _AuthMode mode) {
    final isSelected = _mode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _mode = mode;
            _errorMessage = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF5238)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              prefixIcon: Icon(
                icon,
                size: 18,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }

}
