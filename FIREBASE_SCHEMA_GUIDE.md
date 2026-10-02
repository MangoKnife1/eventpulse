# EventPulse Firebase Database Schema & Migration Guide

This reference documents the Firestore database collections ("tables"), schemas, fields, and sample JSON documents for **EventPulse**. Use this guide to set up and manage collections directly in the [Firebase Console](https://console.firebase.google.com/).

---

## 1. Overview of Collections

| Collection Name | Description | Key Security Rule |
| :--- | :--- | :--- |
| `users` | Profiles for Attendees, Organizers, and Admins | Users can read/write own record; Admins manage roles |
| `events` | Community meetups, venues, dates, capacity, QR reg | Approved events publicly viewable; Organizers publish |
| `tickets` | Digital entry passes, QR codes, check-in timestamps | Attendee reads own pass; Organizer verifies & checks in |
| `organizerApplications` | Vetting applications for community host status | Applicant reads own; Admins approve/reject |
| `notifications` | In-app notification tray, door alerts & reminders | Recipient or broadcast read access |

---

## 2. Collection Schemas & Field Definitions

### A. Collection: `users`
**Document ID Pattern:** `{userId}` (matches Firebase Auth `uid`, e.g. `usr_attendee_01` or `auth.uid`)

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Unique identifier (UID) |
| `name` | `string` | User display name |
| `email` | `string` | Email address |
| `role` | `string` | Role enum: `"user"`, `"attendee"`, `"organizer"`, or `"admin"` |
| `avatar` / `avatarUrl` | `string` | Profile image URL |
| `organization` | `string` | Organization / club name (e.g. "Computer Science Society") |
| `isOrganizerApproved` | `boolean` | True if verified as organizer |
| `bio` | `string` | Short biography |
| `joinedDate` | `string` | Registration date (YYYY-MM-DD) |
| `authProvider` | `string` | `"email"` or `"google"` |

#### Sample Organizer Document for Firebase Console:
```json
{
  "id": "usr_organizer_02",
  "name": "Elena Rostova",
  "email": "elena.rostova@techhub.org",
  "role": "organizer",
  "avatarUrl": "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150",
  "organization": "Tech Collective San Francisco",
  "isOrganizerApproved": true,
  "bio": "Community organizer focusing on cross-platform mobile architecture.",
  "joinedDate": "2026-01-15",
  "authProvider": "email"
}
```

#### Sample Admin Document for Firebase Console (Insert for Admin Role):
**Document ID:** `admin_xymonn78` (or your Firebase Auth `uid`)
```json
{
  "id": "admin_xymonn78",
  "name": "Xymon (Admin)",
  "email": "xymonn78@gmail.com",
  "role": "admin",
  "avatarUrl": "https://api.dicebear.com/7.x/avataaars/svg?seed=xymonn78@gmail.com",
  "organization": "EventPulse Platform Governance",
  "isOrganizerApproved": true,
  "bio": "Platform Administrator & Campus Safety Lead for EventPulse.",
  "joinedDate": "2026-09-26",
  "authProvider": "google"
}
```

---

### B. Collection: `events`
**Document ID Pattern:** `{eventId}` (e.g. `evt_01` or `evt_1726912345678`)

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Unique event ID |
| `title` | `string` | Event title |
| `description` | `string` | Detailed description and agenda |
| `category` | `string` | Domain (e.g. `"Technology"`, `"Design"`, `"Music & Arts"`, `"Community"`) |
| `date` / `dateTime` | `string` | ISO 8601 timestamp (e.g. `"2026-09-25T18:00:00Z"`) |
| `time` | `string` | Human-readable time window (e.g. `"6:30 PM - 9:00 PM"`) |
| `location` | `string` | Street address or virtual link |
| `venueName` | `string` | Venue name (e.g. `"The Foundry Hub"`) |
| `imageUrl` / `bannerUrl` | `string` | High-resolution banner image URL |
| `organizerId` | `string` | UID of the event host |
| `organizerName` | `string` | Name of the host |
| `organizerAvatar` | `string` | Host photo URL |
| `organizerEmail` | `string` | Host contact email |
| `capacity` | `number` | Maximum attendee limit |
| `registeredCount` | `number` | Total current RSVPs |
| `price` | `number` | Admission price (`0.0` for free) |
| `status` | `string` | `"upcoming"`, `"inProgress"`, `"completed"`, or `"cancelled"` |
| `approvalStatus` | `string` | `"approved"`, `"pending"`, or `"rejected"` |
| `tags` | `array` | Category and topic tags (e.g. `["Tech", "Flutter", "Architecture"]`) |
| `registrationCode` | `string` | Quick-register QR payload for on-site posters |
| `isVirtual` | `boolean` | Online virtual event flag |
| `meetingLink` | `string` | Video conferencing URL if virtual |

#### Sample Document for Firebase Console:
```json
{
  "id": "evt_01",
  "title": "NextGen Mobile Dev & Flutter 3.x Meetup",
  "description": "Deep dive into modern declarative Flutter architectures, custom render objects, and cross-platform performance profiling.",
  "category": "Technology",
  "dateTime": "2026-09-28T18:30:00Z",
  "date": "2026-09-28",
  "time": "6:30 PM - 9:00 PM",
  "location": "500 Howard St, Suite 400",
  "venueName": "The Foundry Hub, San Francisco",
  "imageUrl": "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800",
  "bannerUrl": "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800",
  "organizerId": "usr_organizer_02",
  "organizerName": "Elena Rostova",
  "organizerAvatar": "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150",
  "organizerEmail": "elena.rostova@techhub.org",
  "capacity": 80,
  "registeredCount": 64,
  "price": 0.0,
  "status": "upcoming",
  "approvalStatus": "approved",
  "tags": ["Technology", "Flutter", "Mobile", "Architecture"],
  "registrationCode": "EP-EVT-NEXTGEN26",
  "isVirtual": false
}
```

---

### C. Collection: `tickets`
**Document ID Pattern:** `{eventId}_{userId}` (one ticket per person per event; enforced by the security rules)

| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `string` | Ticket ID |
| `ticketCode` / `qrPayload` | `string` | Unique cryptographically verifiable QR payload (e.g. `"EP-TKT-MWA26-ALEXR9"`) |
| `eventId` | `string` | Reference to parent `events` document |
| `eventTitle` | `string` | Meetup title |
| `eventDateTime` | `string` | Event ISO timestamp |
| `eventDate` | `string` | Event date string |
| `eventTime` | `string` | Event time string |
| `venueName` | `string` | Venue name |
| `location` | `string` | Venue address |
| `bannerUrl` | `string` | Event artwork URL |
| `seatType` | `string` | Tier (e.g. `"General Admission"`, `"VIP Pass"`) |
| `organizerId` | `string` | UID of the event host (lets organizers query their own tickets) |
| `userId` | `string` | Attendee UID |
| `userName` | `string` | Attendee full name |
| `userEmail` | `string` | Attendee email |
| `issuedAt` / `registeredAt`| `string` | Issuance ISO timestamp |
| `checkedIn` | `boolean` | True if scanned at door |
| `status` | `string` | `"valid"`, `"checkedIn"`, or `"cancelled"` |
| `checkedInAt` | `string` / `null` | Check-in timestamp or null if unredeemed |
| `reminderEnabled` | `boolean` | Reminder status |
| `reminderTiming` | `string` | Notification lead time (e.g. `"1 hour before"`) |

#### Sample Document for Firebase Console:
```json
{
  "id": "tkt_01",
  "ticketCode": "EP-TKT-FLUTTER26-ALEX01",
  "qrPayload": "EP-TKT-FLUTTER26-ALEX01",
  "eventId": "evt_01",
  "eventTitle": "NextGen Mobile Dev & Flutter 3.x Meetup",
  "eventDateTime": "2026-09-28T18:30:00Z",
  "eventDate": "2026-09-28",
  "eventTime": "6:30 PM - 9:00 PM",
  "venueName": "The Foundry Hub, San Francisco",
  "location": "500 Howard St, Suite 400",
  "bannerUrl": "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800",
  "seatType": "General Admission",
  "userId": "usr_attendee_01",
  "userName": "Alex Rivera",
  "userEmail": "alex.rivera@campus.edu",
  "issuedAt": "2026-09-20T10:00:00Z",
  "checkedIn": false,
  "status": "valid",
  "checkedInAt": null,
  "reminderEnabled": true,
  "reminderTiming": "1 hour before"
}
```

---

### D. Collection: `organizerApplications`
**Document ID Pattern:** `{applicationId}` (e.g. `app_01`)

```json
{
  "id": "app_01",
  "userId": "usr_attendee_01",
  "userName": "Alex Rivera",
  "userEmail": "alex.rivera@campus.edu",
  "organizationName": "Bay Area Mobile Guild",
  "reason": "We want to host bi-weekly study jams and mentorship cohorts.",
  "experience": "Co-organized local tech meetups and student hackathons in 2025.",
  "status": "pending",
  "submittedAt": "2026-09-20T14:30:00Z"
}
```

---

### E. Collection: `notifications`
**Document ID Pattern:** `{notificationId}` (e.g. `notif_01`)

```json
{
  "id": "notif_01",
  "userId": "usr_attendee_01",
  "title": "NextGen Flutter Meetup Tomorrow",
  "message": "Doors open at 6:00 PM at The Foundry Hub. Have your QR pass ready.",
  "timestamp": "2026-09-27T17:00:00Z",
  "isRead": false,
  "read": false,
  "type": "reminder",
  "eventId": "evt_01"
}
```

---

## 3. Implementation note

`EventService` is already migrated to Firestore (see `lib/services/event_service.dart`, `SETUP_GUIDE.md`). The snippet below is kept for reference only. Also note: the admin document is created by editing `role` in the console after registering, not by inserting a hand-made document.

### Reference snippet (older, simplified)

When migrating `EventService` from mock in-memory state to Firestore:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EventService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of approved events
  Stream<List<EventModel>> get eventsStream {
    return _firestore
        .collection('events')
        .where('approvalStatus', isEqualTo: 'approved')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EventModel.fromJson(doc.data()))
            .toList());
  }

  // Check in ticket atomically
  Future<Map<String, dynamic>> checkInTicketInFirestore(String qrPayload) async {
    final cleanPayload = qrPayload.trim().toUpperCase();
    final query = await _firestore
        .collection('tickets')
        .where('qrPayload', isEqualTo: cleanPayload)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'success': false, 'message': 'Invalid pass: QR not found.'};
    }

    final doc = query.docs.first;
    final ticketData = doc.data();
    if (ticketData['checkedIn'] == true) {
      return {'success': false, 'message': 'Duplicate ticket! Already checked in.'};
    }

    await doc.reference.update({
      'checkedIn': true,
      'status': 'checkedIn',
      'checkedInAt': DateTime.now().toIso8601String(),
    });

    return {'success': true, 'message': 'Entry Approved for ${ticketData['userName']}'};
  }
}
```
