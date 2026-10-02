import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import '../../services/service_exception.dart';
import '../../services/camera_service.dart';
import '../../models/event_model.dart';
import '../../models/ticket_model.dart';
import '../shared/camera_qr_scanner_widget.dart';

class AttendeeEventScannerModal extends StatefulWidget {
  final Function(String? eventId)? onViewPass;

  const AttendeeEventScannerModal({super.key, this.onViewPass});

  static Future<void> show(BuildContext context, {Function(String? eventId)? onViewPass}) async {
    // Check and request camera permission via CameraService before opening the QR scanner modal
    await CameraService.instance.checkBeforeOpeningScanner(
      context: context,
      featureTitle: 'Event Poster Scanner',
      onGranted: () {
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AttendeeEventScannerModal(onViewPass: onViewPass),
          );
        }
      },
      onDenied: () {
        // If denied, still allow opening for manual event registration code entry
        if (context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AttendeeEventScannerModal(onViewPass: onViewPass),
          );
        }
      },
    );
  }

  @override
  State<AttendeeEventScannerModal> createState() => _AttendeeEventScannerModalState();
}

class _AttendeeEventScannerModalState extends State<AttendeeEventScannerModal> {
  final TextEditingController _codeController = TextEditingController();
  String? _statusTitle;
  String? _statusMessage;
  bool _isSuccess = false;
  TicketModel? _registeredTicket;
  EventModel? _registeredEvent;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleProcessCode(String code, EventService eventService, AuthService authService) async {
    final clean = code.trim();
    if (clean.isEmpty) return;

    // Match by exact registration code first, then by event id inside the code or by title
    final upper = clean.toUpperCase();
    EventModel? matchedEvent = eventService.getEventByRegistrationCode(clean);
    if (matchedEvent?.approvalStatus != ApprovalStatus.approved) matchedEvent = null;
    if (matchedEvent == null) {
      for (final evt in eventService.openEvents) {
        if (upper.contains(evt.id.toUpperCase()) ||
            evt.title.toLowerCase().contains(clean.toLowerCase())) {
          matchedEvent = evt;
          break;
        }
      }
    }

    if (matchedEvent == null) {
      setState(() {
        _isSuccess = false;
        _statusTitle = 'Unrecognized Event Code';
        _statusMessage = 'Could not find any active meetup matching "$clean".';
      });
      return;
    }

    // Check if already registered
    if (eventService.isUserRegisteredFor(matchedEvent.id, authService.currentUser.id)) {
      final existing = eventService.getTicketForEvent(matchedEvent.id, authService.currentUser.id);
      setState(() {
        _isSuccess = true;
        _registeredEvent = matchedEvent;
        _registeredTicket = existing;
        _statusTitle = 'Already Registered!';
        _statusMessage = 'You already hold a pass for "${matchedEvent!.title}".';
      });
      return;
    }

    // Register user
    final TicketModel ticket;
    try {
      ticket = await eventService.registerUserForEvent(
        event: matchedEvent,
        user: authService.currentUser,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _statusTitle = 'Could not register';
        _statusMessage = friendlyError(e);
      });
      return;
    }
    if (!mounted) return;

    setState(() {
      _isSuccess = true;
      _registeredEvent = matchedEvent;
      _registeredTicket = ticket;
      _statusTitle = 'Registration Confirmed!';
      _statusMessage = 'You are now RSVP\'d for "${matchedEvent!.title}". Your QR pass has been added to your wallet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventService = Provider.of<EventService>(context);
    final authService = Provider.of<AuthService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5238).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_scanner, color: Color(0xFFFF5238), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Event QR to RSVP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Point camera at host flyer or screen',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // If registered, show confirmation banner
                if (_statusMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isSuccess
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isSuccess
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isSuccess ? Icons.check_circle : Icons.error_outline,
                              color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _statusTitle ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                        if (_isSuccess && _registeredEvent != null) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.qr_code_2, size: 16),
                            label: const Text('View My Digital Pass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(context);
                              if (widget.onViewPass != null) {
                                widget.onViewPass!(_registeredEvent!.id);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                // Camera Viewfinder Box
                CameraQrScannerWidget(
                  title: 'Attendee RSVP Scanner',
                  onScan: (scannedCode) {
                    _handleProcessCode(scannedCode, eventService, authService);
                  },
                ),

                const SizedBox(height: 20),

                // Test / Sample event registration codes
                Text(
                  'Quick Event Registration Passes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                ...eventService.approvedEvents.take(3).map((ev) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        _handleProcessCode('EP-REG-${ev.id}', eventService, authService);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.qr_code_2, size: 20, color: Color(0xFFFF5238)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ev.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Code: EP-REG-${ev.id} • ${ev.venueName}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFFF5238)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
