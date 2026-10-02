import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/event_service.dart';
import '../../models/notification_model.dart';

class NotificationCenterModal extends StatefulWidget {
  final Function(String? eventId)? onNavigateToPasses;

  const NotificationCenterModal({super.key, this.onNavigateToPasses});

  static void show(BuildContext context, {Function(String? eventId)? onNavigateToPasses}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationCenterModal(onNavigateToPasses: onNavigateToPasses),
    );
  }

  @override
  State<NotificationCenterModal> createState() => _NotificationCenterModalState();
}

class _NotificationCenterModalState extends State<NotificationCenterModal> {
  String _activeFilter = 'all'; // 'all', 'reminder', 'checkin', 'approval'

  @override
  Widget build(BuildContext context) {
    final eventService = Provider.of<EventService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = eventService.notifications;
    final unreadCount = eventService.unreadNotificationsCount;

    final filteredNotifs = notifications.where((n) {
      if (_activeFilter == 'all') return true;
      return n.type == _activeFilter;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
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
                      child: const Icon(Icons.notifications_active, color: Color(0xFFFF5238), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Notification Center',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5238),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'In-app reminders & event alerts',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (unreadCount > 0)
                  TextButton.icon(
                    onPressed: () => eventService.markAllNotificationsAsRead(),
                    icon: const Icon(Icons.done_all, size: 16, color: Color(0xFFFF5238)),
                    label: const Text(
                      'Read all',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFF5238)),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${notifications.length})', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('reminder', 'Reminders', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('checkin', 'Passes', isDark),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

          // Notifications List
          Expanded(
            child: filteredNotifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                        const SizedBox(height: 10),
                        Text(
                          'No notifications in this filter',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredNotifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notif = filteredNotifs[index];
                      return _buildNotificationCard(notif, isDark, eventService);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notif, bool isDark, EventService eventService) {
    final timeStr = DateFormat('h:mm a').format(notif.timestamp);

    IconData typeIcon;
    Color typeColor;
    if (notif.type == 'reminder') {
      typeIcon = Icons.alarm;
      typeColor = const Color(0xFFFF5238);
    } else if (notif.type == 'checkin') {
      typeIcon = Icons.qr_code_2;
      typeColor = const Color(0xFF0EA5E9);
    } else if (notif.type == 'registration') {
      typeIcon = Icons.person_add_alt_1;
      typeColor = const Color(0xFFA855F7);
    } else {
      typeIcon = Icons.verified_user;
      typeColor = const Color(0xFF10B981);
    }

    return InkWell(
      onTap: () {
        eventService.markNotificationAsRead(notif.id);
        if (notif.eventId != null && widget.onNavigateToPasses != null) {
          Navigator.pop(context);
          widget.onNavigateToPasses!(notif.eventId);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: notif.isRead
              ? (isDark ? const Color(0xFF131B2E) : Colors.white)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
                : const Color(0xFFFF5238).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, size: 16, color: typeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 4),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5238),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
