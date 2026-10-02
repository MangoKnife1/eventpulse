import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/event_service.dart';
import '../../models/event_model.dart';
import '../../models/ticket_model.dart';
import '../../models/organizer_application_model.dart';
import '../../services/service_exception.dart';
import '../shared/camera_qr_scanner_widget.dart';

class AdminGovernanceView extends StatefulWidget {
  const AdminGovernanceView({super.key});

  @override
  State<AdminGovernanceView> createState() => _AdminGovernanceViewState();
}

class _AdminGovernanceViewState extends State<AdminGovernanceView> {
  String _activeSubTab = 'queue'; // 'queue', 'audit', 'inventory'
  String? _inspectedCode;
  TicketModel? _inspectedTicket;

  void _handleAuditScan(String code, EventService eventService) {
    setState(() {
      _inspectedCode = code.trim();
      try {
        _inspectedTicket = eventService.userTickets.firstWhere(
          (t) =>
              t.qrPayload.toUpperCase() == code.trim().toUpperCase() ||
              t.id.toUpperCase() == code.trim().toUpperCase(),
        );
      } catch (_) {
        _inspectedTicket = null;
      }
    });
  }

  /// Runs an admin action and reports success or a readable error.
  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Widget _buildApplicationCard(
    OrganizerApplicationModel app,
    EventService eventService,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            app.organizationName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${app.userName} • ${app.userEmail}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          if (app.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              app.reason,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                  ),
                  onPressed: () => _run(
                    () => eventService.rejectOrganizerApplication(app),
                    'Application from ${app.userName} declined.',
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () => _run(
                    () => eventService.approveOrganizerApplication(app),
                    '${app.userName} is now an organizer.',
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventService = Provider.of<EventService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pendingEvents = eventService.pendingApprovalEvents;
    final applications = eventService.pendingApplications;
    final allEvents = eventService.allEvents;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          children: [
            // Governance In-page Header
            Row(
              children: [
                Text(
                  'Governance & Safety',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'ADMIN TERMINAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Sub-tabs Segmented Control
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              children: [
                _buildSubTabItem(
                  id: 'queue',
                  label: 'Review (${pendingEvents.length})',
                  isDark: isDark,
                ),
                _buildSubTabItem(
                  id: 'audit',
                  label: 'QR Auditor',
                  isDark: isDark,
                ),
                _buildSubTabItem(
                  id: 'inventory',
                  label: 'Inventory (${allEvents.length})',
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. Review Queue Sub-Tab
          if (_activeSubTab == 'queue') ...[
            // Safety Standard Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Campus Safety Standard',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ENFORCED',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All student-hosted meetups require verified campus venues and capacity limits before appearing in public discovery.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            if (applications.isNotEmpty) ...[
              Text(
                'Organizer Applications (${applications.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ...applications.map((a) => _buildApplicationCard(a, eventService, isDark)),
              const SizedBox(height: 8),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Proposals (${pendingEvents.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (pendingEvents.isNotEmpty)
                  const Text(
                    'Action Required',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (pendingEvents.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF10B981), size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'All Proposals Reviewed!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'No meetups currently awaiting safety moderation.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...pendingEvents.map((evt) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            evt.category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFF5238),
                            ),
                          ),
                          Text(
                            'Cap: ${evt.capacity}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        evt.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${evt.venueName} • Organizer: ${evt.organizerName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _run(
                                () => eventService.rejectEvent(evt.id),
                                'Proposal for "${evt.title}" declined.',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _run(
                                () => eventService.approveEvent(evt.id),
                                '"${evt.title}" approved and live!',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
          ],

          // 2. QR Ticket Auditor Sub-Tab
          if (_activeSubTab == 'audit') ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF9333EA).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF9333EA).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.security, color: Color(0xFFA855F7), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Security Ticket Inspector',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA855F7),
                          ),
                        ),
                        Text(
                          'Scan any attendee pass to verify cryptographic validity, host meetup, and re-entry status.',
                          style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Live Auditor Camera Scanner
            CameraQrScannerWidget(
              title: 'Administrator Ticket Auditor',
              onScan: (code) => _handleAuditScan(code, eventService),
            ),

            const SizedBox(height: 16),

            // Inspection Result Banner
            if (_inspectedCode != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _inspectedTicket != null
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _inspectedTicket != null
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _inspectedTicket != null ? Icons.check_circle : Icons.warning_amber_rounded,
                              size: 18,
                              color: _inspectedTicket != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _inspectedTicket != null ? 'Authentic Ticket Registered' : 'Unregistered or Forged Pass',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _inspectedTicket != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _inspectedTicket?.status == TicketStatus.checkedIn ? 'CHECKED IN' : 'VALID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _inspectedTicket != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Payload: $_inspectedCode',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                    if (_inspectedTicket != null) ...[
                      const SizedBox(height: 8),
                      Text('Attendee: ${_inspectedTicket!.userName} (${_inspectedTicket!.userEmail})'),
                      Text('Meetup: ${_inspectedTicket!.eventTitle}'),
                      Text('Venue: ${_inspectedTicket!.venueName}'),
                    ],
                  ],
                ),
              ),
          ],

          // 3. Inventory Sub-Tab
          if (_activeSubTab == 'inventory') ...[
            Text(
              'All Registered Events (${allEvents.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            ...allEvents.map((evt) {
              Color statusColor;
              String statusLabel;
              if (evt.approvalStatus == ApprovalStatus.approved) {
                statusColor = const Color(0xFF10B981);
                statusLabel = 'APPROVED';
              } else if (evt.approvalStatus == ApprovalStatus.pending) {
                statusColor = Colors.orangeAccent;
                statusLabel = 'PENDING';
              } else {
                statusColor = Colors.redAccent;
                statusLabel = 'REJECTED';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(evt.imageUrl),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            evt.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${evt.category} • ${evt.registeredCount}/${evt.capacity} RSVPs',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
      )
    );
  }

  Widget _buildSubTabItem({
    required String id,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _activeSubTab == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeSubTab = id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF9333EA)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ),
        ),
      ),
    );
  }
}
