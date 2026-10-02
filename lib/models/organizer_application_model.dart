import '../utils/json_utils.dart';

enum ApplicationStatus {
  pending,
  approved,
  rejected,
}

class OrganizerApplicationModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String organizationName;
  final String reason;
  final String experience;
  final ApplicationStatus status;
  final DateTime submittedAt;

  OrganizerApplicationModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.organizationName,
    required this.reason,
    this.experience = '',
    this.status = ApplicationStatus.pending,
    required this.submittedAt,
  });

  factory OrganizerApplicationModel.fromJson(Map<String, dynamic> json) {
    final parsedDate = parseDate(json['submittedAt']) ?? DateTime.now();

    final rawStatus = (json['status'] ?? 'pending').toString().toLowerCase();
    ApplicationStatus parsedStatus;
    if (rawStatus == 'approved') {
      parsedStatus = ApplicationStatus.approved;
    } else if (rawStatus == 'rejected') {
      parsedStatus = ApplicationStatus.rejected;
    } else {
      parsedStatus = ApplicationStatus.pending;
    }

    return OrganizerApplicationModel(
      id: (json['id'] ?? '') as String,
      userId: (json['userId'] ?? '') as String,
      userName: (json['userName'] ?? '') as String,
      userEmail: (json['userEmail'] ?? '') as String,
      organizationName: (json['organizationName'] ?? '') as String,
      reason: (json['reason'] ?? '') as String,
      experience: (json['experience'] ?? '') as String,
      status: parsedStatus,
      submittedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'organizationName': organizationName,
      'reason': reason,
      'experience': experience,
      'status': status.name,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }
}
