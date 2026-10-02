enum UserRole {
  attendee,
  organizer,
  admin,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final UserRole role;
  final String organization;
  final bool isOrganizerApproved;
  final String bio;
  final String joinedDate;
  final String authProvider;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.role,
    this.organization = '',
    this.isOrganizerApproved = false,
    this.bio = '',
    this.joinedDate = '',
    this.authProvider = 'email',
  });

  /// Empty = "no photo": the UI draws a neutral silhouette (see UserAvatar).
  static const String defaultAvatar = '';

  /// Older versions stored this stock photo as the default for new accounts.
  /// It is treated as "no photo" when reading existing profiles.
  static const String _legacyDefaultAvatar =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150';

  String get avatar => avatarUrl;

  bool get isGuest => id == 'guest' || id.isEmpty;

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? bio,
    String? organization,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role,
      organization: organization ?? this.organization,
      isOrganizerApproved: isOrganizerApproved,
      bio: bio ?? this.bio,
      joinedDate: joinedDate,
      authProvider: authProvider,
    );
  }

  factory UserModel.guest() {
    return UserModel(
      id: 'guest',
      name: 'Guest User',
      email: '',
      avatarUrl: '',
      role: UserRole.attendee,
      organization: '',
      isOrganizerApproved: false,
      bio: 'Exploring community meetups.',
      joinedDate: '',
      authProvider: 'none',
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleRaw = (json['role'] ?? 'attendee').toString().toLowerCase();
    UserRole parsedRole;
    if (roleRaw == 'admin') {
      parsedRole = UserRole.admin;
    } else if (roleRaw == 'organizer') {
      parsedRole = UserRole.organizer;
    } else {
      parsedRole = UserRole.attendee; // handles 'user', 'attendee', etc.
    }

    return UserModel(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? 'User') as String,
      email: (json['email'] ?? '') as String,
      avatarUrl: (() {
        final raw = ((json['avatarUrl'] ?? json['avatar'] ?? '') as String).trim();
        return raw == _legacyDefaultAvatar ? defaultAvatar : raw;
      })(),
      role: parsedRole,
      organization: (json['organization'] ?? '') as String,
      isOrganizerApproved: json['isOrganizerApproved'] as bool? ?? false,
      bio: (json['bio'] ?? '') as String,
      joinedDate: (json['joinedDate'] ?? '') as String,
      authProvider: (json['authProvider'] ?? 'email') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'avatar': avatarUrl,
      'role': role.name,
      'organization': organization,
      'isOrganizerApproved': isOrganizerApproved,
      'bio': bio,
      'joinedDate': joinedDate,
      'authProvider': authProvider,
    };
  }
}
