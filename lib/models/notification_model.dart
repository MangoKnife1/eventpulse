import '../utils/json_utils.dart';

class NotificationModel {
  final String id;
  final String userId; // recipient ('' = local/demo notification)
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'reminder', 'checkin', 'approval', 'system'
  final String? eventId;

  NotificationModel({
    required this.id,
    this.userId = '',
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = 'reminder',
    this.eventId,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    String? eventId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      eventId: eventId ?? this.eventId,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final parsedTime = parseDate(json['timestamp']) ?? DateTime.now();

    return NotificationModel(
      id: (json['id'] ?? '') as String,
      userId: (json['userId'] ?? '') as String,
      title: (json['title'] ?? 'Notification') as String,
      message: (json['message'] ?? '') as String,
      timestamp: parsedTime,
      isRead: (json['isRead'] ?? json['read']) as bool? ?? false,
      type: (json['type'] ?? 'reminder') as String,
      eventId: json['eventId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'read': isRead,
      'type': type,
      'eventId': eventId,
    };
  }
}
