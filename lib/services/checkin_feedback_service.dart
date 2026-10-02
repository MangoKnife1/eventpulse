import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CheckinFeedbackService {
  CheckinFeedbackService._();

  static final CheckinFeedbackService instance = CheckinFeedbackService._();

  static const _channelId = 'checkin_alerts';
  static const _channelName = 'Check-in alerts';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> notifyCheckIn({required String message}) async {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts when a pass is successfully checked in',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Pass checked in',
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      'Pass checked in',
      message.isEmpty ? 'Entry approved' : message,
      const NotificationDetails(android: androidDetails),
    );
  }
}