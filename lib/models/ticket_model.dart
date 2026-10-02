import '../utils/json_utils.dart';

enum TicketStatus {
  valid,
  checkedIn,
  cancelled,
}

class TicketModel {
  final String id;
  final String eventId;
  final String eventTitle;
  final DateTime eventDateTime;
  final String venueName;
  final String location;
  final String bannerUrl;
  final String seatType;
  final String organizerId; // denormalised so organizers can query their own tickets
  final String userId;
  final String userName;
  final String userEmail;
  final String qrPayload;
  final DateTime issuedAt;
  final TicketStatus status;
  final DateTime? checkedInAt;
  final bool reminderEnabled;
  final String reminderTiming;

  TicketModel({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.eventDateTime,
    required this.venueName,
    required this.location,
    this.bannerUrl = '',
    this.seatType = 'General Admission',
    this.organizerId = '',
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.qrPayload,
    required this.issuedAt,
    this.status = TicketStatus.valid,
    this.checkedInAt,
    this.reminderEnabled = true,
    this.reminderTiming = '1 hour before',
  });

  bool get isCheckedIn => status == TicketStatus.checkedIn;
  bool get checkedIn => isCheckedIn;
  String get ticketCode => qrPayload;

  TicketModel copyWith({
    TicketStatus? status,
    DateTime? checkedInAt,
    bool? reminderEnabled,
    String? reminderTiming,
    String? seatType,
    String? bannerUrl,
  }) {
    return TicketModel(
      id: id,
      eventId: eventId,
      eventTitle: eventTitle,
      eventDateTime: eventDateTime,
      venueName: venueName,
      location: location,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      seatType: seatType ?? this.seatType,
      organizerId: organizerId,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      qrPayload: qrPayload,
      issuedAt: issuedAt,
      status: status ?? this.status,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTiming: reminderTiming ?? this.reminderTiming,
    );
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final parsedEventDateTime = parseDate(json['eventDateTime']) ??
        parseDate(json['eventDate']) ??
        DateTime.now();
    final parsedIssuedAt =
        parseDate(json['issuedAt']) ?? parseDate(json['registeredAt']) ?? DateTime.now();

    final code = (json['qrPayload'] ?? json['ticketCode'] ?? '') as String;
    final isCheckedInBool = json['checkedIn'] == true;
    final statusStr = json['status']?.toString().toLowerCase();

    TicketStatus resolvedStatus;
    if (isCheckedInBool || statusStr == 'checkedin' || statusStr == 'used') {
      resolvedStatus = TicketStatus.checkedIn;
    } else if (statusStr == 'cancelled') {
      resolvedStatus = TicketStatus.cancelled;
    } else {
      resolvedStatus = TicketStatus.valid;
    }

    return TicketModel(
      id: (json['id'] ?? '') as String,
      eventId: (json['eventId'] ?? '') as String,
      eventTitle: (json['eventTitle'] ?? 'Community Event') as String,
      eventDateTime: parsedEventDateTime,
      venueName: (json['venueName'] ?? json['eventLocation'] ?? json['location'] ?? 'Community Venue') as String,
      location: (json['location'] ?? json['eventLocation'] ?? 'SF Bay Area') as String,
      bannerUrl: (json['bannerUrl'] ?? '') as String,
      seatType: (json['seatType'] ?? 'General Admission') as String,
      organizerId: (json['organizerId'] ?? '') as String,
      userId: (json['userId'] ?? '') as String,
      userName: (json['userName'] ?? json['attendeeName'] ?? 'Attendee') as String,
      userEmail: (json['userEmail'] ?? '') as String,
      qrPayload: code,
      issuedAt: parsedIssuedAt,
      status: resolvedStatus,
      checkedInAt: parseDate(json['checkedInAt']),
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      reminderTiming: (json['reminderTiming'] ?? '1 hour before') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketCode': qrPayload,
      'qrPayload': qrPayload,
      'eventId': eventId,
      'eventTitle': eventTitle,
      'eventDateTime': eventDateTime.toIso8601String(),
      'eventDate': eventDateTime.toIso8601String().split('T').first,
      'eventTime': '${eventDateTime.hour.toString().padLeft(2, '0')}:${eventDateTime.minute.toString().padLeft(2, '0')}',
      'venueName': venueName,
      'location': location,
      'eventLocation': location,
      'bannerUrl': bannerUrl,
      'seatType': seatType,
      'organizerId': organizerId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'registeredAt': issuedAt.toIso8601String(),
      'issuedAt': issuedAt.toIso8601String(),
      'checkedIn': isCheckedIn,
      'status': status.name,
      'checkedInAt': checkedInAt?.toIso8601String(),
      'reminderEnabled': reminderEnabled,
      'reminderTiming': reminderTiming,
    };
  }
}

typedef TicketItem = TicketModel;
