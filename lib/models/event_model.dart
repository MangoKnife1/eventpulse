import '../utils/json_utils.dart';

enum EventStatus {
  upcoming,
  inProgress,
  completed,
  cancelled,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime dateTime;
  final String location;
  final String venueName;
  final String imageUrl;
  final String organizerId;
  final String organizerName;
  final String organizerAvatar;
  final String organizerEmail;
  final int capacity;
  final int registeredCount;
  final double price; // 0 for free
  final EventStatus status;
  final ApprovalStatus approvalStatus;
  final List<String> tags;
  final String? registrationCode;
  final bool isVirtual;
  final String? meetingLink;
  final String? rejectionReason;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.dateTime,
    required this.location,
    required this.venueName,
    required this.imageUrl,
    required this.organizerId,
    required this.organizerName,
    required this.organizerAvatar,
    this.organizerEmail = '',
    required this.capacity,
    required this.registeredCount,
    this.price = 0.0,
    this.status = EventStatus.upcoming,
    this.approvalStatus = ApprovalStatus.approved,
    this.tags = const [],
    this.registrationCode,
    this.isVirtual = false,
    this.meetingLink,
    this.rejectionReason,
  });

  bool get isFull => registeredCount >= capacity;
  int get spotsRemaining => capacity - registeredCount;
  String get bannerUrl => imageUrl;

  EventModel copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? dateTime,
    String? location,
    String? venueName,
    String? imageUrl,
    String? organizerEmail,
    int? capacity,
    int? registeredCount,
    double? price,
    EventStatus? status,
    ApprovalStatus? approvalStatus,
    List<String>? tags,
    String? registrationCode,
    bool? isVirtual,
    String? meetingLink,
    String? rejectionReason,
  }) {
    return EventModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      location: location ?? this.location,
      venueName: venueName ?? this.venueName,
      imageUrl: imageUrl ?? this.imageUrl,
      organizerId: organizerId,
      organizerName: organizerName,
      organizerAvatar: organizerAvatar,
      organizerEmail: organizerEmail ?? this.organizerEmail,
      capacity: capacity ?? this.capacity,
      registeredCount: registeredCount ?? this.registeredCount,
      price: price ?? this.price,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      tags: tags ?? this.tags,
      registrationCode: registrationCode ?? this.registrationCode,
      isVirtual: isVirtual ?? this.isVirtual,
      meetingLink: meetingLink ?? this.meetingLink,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  factory EventModel.fromJson(Map<String, dynamic> json) {
    final parsedDateTime =
        parseDate(json['dateTime']) ?? parseDate(json['date']) ?? DateTime.now();

    final rawTags = json['tags'];
    List<String> parsedTags = [];
    if (rawTags is List) {
      parsedTags = rawTags.map((t) => t.toString()).toList();
    }

    return EventModel(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? 'Untitled Meetup') as String,
      description: (json['description'] ?? '') as String,
      category: (json['category'] ?? 'Technology') as String,
      dateTime: parsedDateTime,
      location: (json['location'] ?? 'SF Bay Area') as String,
      venueName: (json['venueName'] ?? json['location'] ?? 'Community Hub') as String,
      imageUrl: (json['imageUrl'] ?? json['bannerUrl'] ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800') as String,
      organizerId: (json['organizerId'] ?? '') as String,
      organizerName: (json['organizerName'] ?? 'Community Host') as String,
      organizerAvatar: (json['organizerAvatar'] ?? '') as String,
      organizerEmail: (json['organizerEmail'] ?? '') as String,
      capacity: (json['capacity'] as num?)?.toInt() ?? 50,
      registeredCount: ((json['registeredCount'] ?? json['registeredAttendees']) as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      status: EventStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status']?.toString().toLowerCase()),
        orElse: () => EventStatus.upcoming,
      ),
      approvalStatus: ApprovalStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['approvalStatus']?.toString().toLowerCase()),
        orElse: () => json['status'] == 'approved' ? ApprovalStatus.approved : ApprovalStatus.pending,
      ),
      tags: parsedTags,
      registrationCode: json['registrationCode'] as String?,
      isVirtual: json['isVirtual'] as bool? ?? false,
      meetingLink: json['meetingLink'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'dateTime': dateTime.toIso8601String(),
      'date': dateTime.toIso8601String().split('T').first,
      'time': '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
      'location': location,
      'venueName': venueName,
      'imageUrl': imageUrl,
      'bannerUrl': imageUrl,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'organizerAvatar': organizerAvatar,
      'organizerEmail': organizerEmail,
      'capacity': capacity,
      'registeredCount': registeredCount,
      'price': price,
      'status': status.name,
      'approvalStatus': approvalStatus.name,
      'tags': tags,
      'registrationCode': registrationCode,
      'isVirtual': isVirtual,
      'meetingLink': meetingLink,
      'rejectionReason': rejectionReason,
    };
  }
}
