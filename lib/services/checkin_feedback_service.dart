import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class CheckinFeedbackService {
  CheckinFeedbackService._();

  static final CheckinFeedbackService instance = CheckinFeedbackService._();

  static const _channelId = 'checkin_alerts';
  static const _channelName = 'Check-in alerts';
  static const _registrationChannelId = 'registration_alerts';
  static const _registrationChannelName = 'Registration alerts';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings: settings);

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
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: 'Pass checked in',
      body: message.isEmpty ? 'Entry approved' : message,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> notifyRegistration({required String eventTitle}) async {
    const androidDetails = AndroidNotificationDetails(
      _registrationChannelId,
      _registrationChannelName,
      channelDescription: 'Alerts when an event registration is complete',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'Registration complete',
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: 'Registration complete',
      body: 'Your pass for $eventTitle is ready.',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
