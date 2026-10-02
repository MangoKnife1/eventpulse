import '../models/event_model.dart';
import '../models/notification_model.dart';
import '../models/organizer_application_model.dart';
import '../models/ticket_model.dart';
import '../models/user_model.dart';

/// Offline sample data used ONLY when Firebase is not configured (demo mode).
/// With Firebase enabled none of this is ever loaded.
class DemoData {
  DemoData._();

  static List<UserModel> profiles() => [
    UserModel(
      id: 'usr_attendee_01',
      name: 'Alex Rivera',
      email: 'alex.rivera@campus.edu',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      role: UserRole.attendee,
      organization: 'Computer Science Society',
      bio: 'Active participant in tech and campus workshops.',
      joinedDate: '2026-09-20',
      authProvider: 'email',
    ),
    UserModel(
      id: 'usr_organizer_02',
      name: 'Elena Rostova',
      email: 'elena.rostova@techhub.org',
      avatarUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      role: UserRole.organizer,
      organization: 'Tech Collective San Francisco',
      isOrganizerApproved: true,
      bio: 'Host and curator for mobile developer and design meetups.',
      joinedDate: '2026-09-15',
      authProvider: 'email',
    ),
    UserModel(
      id: 'admin_xymonn78',
      name: 'Xymon (Admin)',
      email: 'xymonn78@gmail.com',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      role: UserRole.admin,
      organization: 'EventPulse Platform Governance',
      isOrganizerApproved: true,
      bio: 'Lead Platform Administrator & Campus Governance Coordinator.',
      joinedDate: '2026-09-26',
      authProvider: 'google',
    ),
  ];


  static List<NotificationModel> notifications() => [
    NotificationModel(
      id: 'notif_01',
      title: 'NextGen Flutter Meetup Tomorrow',
      message: 'Doors open at 6:00 PM at The Foundry Hub. Have your QR pass ready.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      isRead: false,
      type: 'reminder',
      eventId: 'evt_01',
    ),
    NotificationModel(
      id: 'notif_02',
      title: 'Pass Issued: Design Lab',
      message: 'Your dynamic pass for Minimalist Product Design is ready in your wallet.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      type: 'checkin',
      eventId: 'evt_02',
    ),
    NotificationModel(
      id: 'notif_03',
      title: 'Campus Safety Verified',
      message: 'Governance team has approved your venue request for next week.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
      type: 'approval',
    ),
  ];

  static List<EventModel> events() => [
    EventModel(
      id: 'evt_01',
      title: 'NextGen Mobile Dev & Flutter 3.x Meetup',
      description:
          'Deep dive into modern declarative Flutter architectures, custom render objects, and cross-platform performance profiling. Includes live code demonstrations and networking with Bay Area mobile leads.',
      category: 'Technology',
      dateTime: DateTime.now().add(const Duration(days: 2, hours: 4)),
      location: '500 Howard St, Suite 400',
      venueName: 'The Foundry Hub, San Francisco',
      imageUrl:
          'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800&auto=format&fit=crop&q=80',
      organizerId: 'usr_organizer_02',
      organizerName: 'Elena Rostova',
      organizerAvatar:
          'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      organizerEmail: 'elena.rostova@techhub.org',
      capacity: 80,
      registeredCount: 64,
      price: 0.0,
      status: EventStatus.upcoming,
      approvalStatus: ApprovalStatus.approved,
      tags: const ['Technology', 'Tech', 'Flutter', 'Networking'],
      registrationCode: 'EP-EVT-NEXTGEN26',
    ),
    EventModel(
      id: 'evt_02',
      title: 'Minimalist Product Design & Typography Lab',
      description:
          'A hands-on workshop dissecting typographic rhythm, anti-slop design philosophy, and micro-interactions for modern iOS and Android apps. Bring your laptop and Figma or Sketch files.',
      category: 'Design',
      dateTime: DateTime.now().add(const Duration(days: 4, hours: 2)),
      location: '120 2nd St, Floor 3',
      venueName: 'Atelier Creative Loft',
      imageUrl:
          'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=800&auto=format&fit=crop&q=80',
      organizerId: 'usr_organizer_02',
      organizerName: 'Elena Rostova',
      organizerAvatar:
          'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      organizerEmail: 'elena.rostova@techhub.org',
      capacity: 45,
      registeredCount: 42,
      price: 15.0,
      status: EventStatus.upcoming,
      approvalStatus: ApprovalStatus.approved,
      tags: const ['Design', 'UX/UI', 'Typography', 'Social'],
      registrationCode: 'EP-EVT-DESIGNLAB26',
    ),
    EventModel(
      id: 'evt_03',
      title: 'SoundBath & Ambient Synthesis Showcase',
      description:
          'An intimate acoustic and modular synthesis listening session designed for mental recovery and deep auditory relaxation. Tea service provided by local botanists.',
      category: 'Music & Arts',
      dateTime: DateTime.now().add(const Duration(days: 6, hours: 7)),
      location: '780 Mission St',
      venueName: 'St. Jude Sanctuary Gardens',
      imageUrl:
          'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop&q=80',
      organizerId: 'usr_organizer_04',
      organizerName: 'Julian Thorne',
      organizerAvatar:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      organizerEmail: 'julian.thorne@ambientarts.org',
      capacity: 35,
      registeredCount: 20,
      price: 10.0,
      status: EventStatus.upcoming,
      approvalStatus: ApprovalStatus.approved,
      tags: const ['Music', 'Music & Arts', 'Social', 'Wellness'],
      registrationCode: 'EP-EVT-SOUNDBATH26',
    ),
    EventModel(
      id: 'evt_04',
      title: 'Urban Micro-Forest Tree Planting & Clean-up',
      description:
          'Join fellow community members in planting 120 indigenous trees and shrubs in the community park. Gloves, shovels, and hydration stations will be supplied.',
      category: 'Community',
      dateTime: DateTime.now().add(const Duration(days: 8, hours: 1)),
      location: 'Dolores Park South Lawn',
      venueName: 'Dolores Community Grounds',
      imageUrl:
          'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&auto=format&fit=crop&q=80',
      organizerId: 'usr_organizer_05',
      organizerName: 'Sarah Jenkins',
      organizerAvatar:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      organizerEmail: 'sarah.jenkins@greencampus.org',
      capacity: 100,
      registeredCount: 88,
      price: 0.0,
      status: EventStatus.upcoming,
      approvalStatus: ApprovalStatus.approved,
      tags: const ['Community', 'Social', 'Eco', 'Volunteering'],
      registrationCode: 'EP-EVT-ECOCLEAN26',
    ),
    EventModel(
      id: 'evt_05',
      title: 'Indie Game Jam & Rapid Prototyping Showcase',
      description:
          '48-hour challenge showcase where student developers display experimental shaders, game mechanics, and audio design on mobile and desktop platforms.',
      category: 'Gaming',
      dateTime: DateTime.now().add(const Duration(days: 10, hours: 5)),
      location: 'Campus Tech Hall, Room B12',
      venueName: 'University Innovation Pavilion',
      imageUrl:
          'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800&auto=format&fit=crop&q=80',
      organizerId: 'usr_organizer_02',
      organizerName: 'Elena Rostova',
      organizerAvatar:
          'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      organizerEmail: 'elena.rostova@techhub.org',
      capacity: 60,
      registeredCount: 30,
      price: 0.0,
      status: EventStatus.upcoming,
      approvalStatus: ApprovalStatus.pending,
      tags: const ['Tech', 'Gaming', 'Networking'],
      registrationCode: 'EP-EVT-GAMEJAM26',
    ),
  ];


  static List<TicketModel> tickets(List<EventModel> events) {
    final first = events[0];
    final second = events[1];
    return [
      // 1. Valid pass for event 0
      TicketModel(
        id: 'tkt_01',
        eventId: first.id,
        eventTitle: first.title,
        eventDateTime: first.dateTime,
        venueName: first.venueName,
        location: first.location,
        userId: 'usr_attendee_01',
        userName: 'Alex Rivera',
        userEmail: 'alex.rivera@campus.edu',
        qrPayload: 'EP-PASS-${first.id.toUpperCase()}-ALEXRIVERA-8839',
        issuedAt: DateTime.now().subtract(const Duration(days: 1)),
        status: TicketStatus.valid,
      ),
      // 2. Duplicate / already checked in pass for event 0
      TicketModel(
        id: 'tkt_02',
        eventId: first.id,
        eventTitle: first.title,
        eventDateTime: first.dateTime,
        venueName: first.venueName,
        location: first.location,
        userId: 'usr_attendee_02',
        userName: 'Sophia Chen',
        userEmail: 'sophia.chen@campus.edu',
        qrPayload: 'EP-PASS-${first.id.toUpperCase()}-SOPHIACHEN-4412',
        issuedAt: DateTime.now().subtract(const Duration(days: 2)),
        status: TicketStatus.checkedIn,
        checkedInAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      // 3. Valid pass for event 1 (wrong event test when door terminal is set to event 0)
      TicketModel(
        id: 'tkt_03',
        eventId: second.id,
        eventTitle: second.title,
        eventDateTime: second.dateTime,
        venueName: second.venueName,
        location: second.location,
        userId: 'usr_attendee_03',
        userName: 'Devon Taylor',
        userEmail: 'devon.taylor@campus.edu',
        qrPayload: 'EP-PASS-${second.id.toUpperCase()}-DEVONTAYLOR-7719',
        issuedAt: DateTime.now().subtract(const Duration(hours: 12)),
        status: TicketStatus.valid,
      ),
      // 4. Another valid pass for event 0
      TicketModel(
        id: 'tkt_04',
        eventId: first.id,
        eventTitle: first.title,
        eventDateTime: first.dateTime,
        venueName: first.venueName,
        location: first.location,
        userId: 'usr_attendee_04',
        userName: 'Jordan Miller',
        userEmail: 'jordan.m@campus.edu',
        qrPayload: 'EP-PASS-${first.id.toUpperCase()}-JORDANMILLER-2150',
        issuedAt: DateTime.now().subtract(const Duration(hours: 5)),
        status: TicketStatus.valid,
      ),
    ];
  }

  static List<OrganizerApplicationModel> applications() => [
    OrganizerApplicationModel(
      id: 'app_01',
      userId: 'usr_attendee_01',
      userName: 'Alex Rivera',
      userEmail: 'alex.rivera@campus.edu',
      organizationName: 'Bay Area Mobile Guild',
      reason: 'We want to host bi-weekly study jams and mentorship cohorts.',
      experience: 'Co-organized local tech meetups and student hackathons in 2025.',
      submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}
