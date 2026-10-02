import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../models/ticket_model.dart';
import '../shared/camera_qr_scanner_widget.dart';

class OrganizerScannerView extends StatefulWidget {
  final String? eventId;

  const OrganizerScannerView({super.key, this.eventId});

  @override
  State<OrganizerScannerView> createState() => _OrganizerScannerViewState();
}

class _OrganizerScannerViewState extends State<OrganizerScannerView> {
  String _selectedEventId = 'all';

  @override
  void initState() {
    super.initState();
    _selectedEventId = widget.eventId ?? 'all';
  }

  @override
  Widget build(BuildContext context) {
    final eventService = Provider.of<EventService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final currentUser = Provider.of<AuthService>(context).currentUser;
    final allEvents = eventService.eventsManagedBy(currentUser);
    final managedIds = allEvents.map((e) => e.id).toSet();
    final allTickets = eventService.userTickets
        .where((t) => managedIds.contains(t.eventId) && !t.isOrganizerPass)
        .toList();

    final scopedTickets = _selectedEventId == 'all'
        ? allTickets
        : allTickets.where((t) => t.eventId == _selectedEventId).toList();

    final checkedInCount =
        scopedTickets.where((t) => t.status == TicketStatus.checkedIn).length;
    final totalEventTickets =
        scopedTickets.isNotEmpty ? scopedTickets.length : 1;
    final checkInRate =
        (checkedInCount / totalEventTickets * 100).clamp(0, 100).toInt();

    final currentEventTitle = _selectedEventId != 'all'
        ? (allEvents
                .where((e) => e.id == _selectedEventId)
                .map((e) => e.title)
                .firstOrNull ??
            'All Active Meetups')
        : 'All Active Meetups';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: [
          // 1. In-Page Terminal Header (No redundant AppBar)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Door Check-In Terminal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentEventTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                    SizedBox(width: 6),
                    Text(
                      'READY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 2. Event Scope Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: Color(0xFFFF5238)),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedEventId,
                      isDense: true,
                      dropdownColor:
                          isDark ? const Color(0xFF131B2E) : Colors.white,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Events (Universal Gate)'),
                        ),
                        ...allEvents.map((evt) => DropdownMenuItem(
                              value: evt.id,
                              child: Text(evt.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedEventId = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Door Arrival Progress Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Door Arrival Progress',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '$checkInRate% ($checkedInCount/$totalEventTickets arrived)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalEventTickets > 0
                        ? (checkedInCount / totalEventTickets)
                        : 0,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. Live Camera QR Scanner Widget
          CameraQrScannerWidget(
            targetEventId: _selectedEventId,
            title: 'Live Door Terminal Scanner',
          ),

          const SizedBox(height: 20),

          // 5. Scoped Roster & Attendee Check-In History
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131B2E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
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
                        const Icon(Icons.people_alt,
                            size: 16, color: Color(0xFFFF5238)),
                        const SizedBox(width: 8),
                        Text(
                          'EVENT ROSTER & RECENT PASSES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${scopedTickets.length} Passes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (scopedTickets.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No tickets registered for this event yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scopedTickets.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final t = scopedTickets[index];
                      final isCheckedIn = t.status == TicketStatus.checkedIn;
                      return Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: (isCheckedIn
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFFF5238))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCheckedIn
                                  ? Icons.check_circle
                                  : Icons.confirmation_number,
                              color: isCheckedIn
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFFF5238),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.userName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Pass: ${t.ticketCode}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isCheckedIn
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6))
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCheckedIn ? 'Checked In' : 'Ready',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isCheckedIn
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
