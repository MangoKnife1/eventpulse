# EventPulse - Flutter Community Event Organizer
## Plug-and-Play Quickstart

This Flutter project is pre-configured with Android Gradle Plugin **8.7.3**, Kotlin **2.0.21**, Gradle **8.11.1**, and Java **17** compatibility so you can run it immediately without Gradle version errors.

### Running in 2 Simple Steps:

Open your terminal inside this project folder:
```bash
flutter pub get
flutter run
```

---

### Firebase & Cloudinary
The app starts in offline demo mode. To switch to live data (Firebase Auth + Firestore) and image uploads (Cloudinary), follow **[SETUP_FIREBASE_CLOUDINARY.md](SETUP_FIREBASE_CLOUDINARY.md)**.

### If using VS Code:
1. Open this folder (`File` -> `Open Folder...`).
2. Press `Ctrl + Shift + P` -> **Flutter: Select Device** -> Pick your Android emulator (or connected phone).
3. Press **F5** to start debugging.

### Project Architecture & Role Modules:
- **State Management**: `provider` (`ChangeNotifierProvider`)
- **Services**: `auth_service.dart` (Firebase Auth + profile), `event_service.dart` (Firestore events/tickets/notifications), `cloudinary_service.dart` (image upload), `demo_data.dart` (offline sample data)
- **Attendee Flow**:
  - `lib/views/attendee/attendee_events_view.dart`: Browse, filter, search community events, RSVP.
  - `lib/views/attendee/attendee_passes_view.dart`: Perforated tickets with dynamic QR codes.
  - `lib/views/attendee/attendee_event_scanner_modal.dart`: Live camera QR scanner to scan event posters.
- **Organizer Flow**:
  - `lib/views/organizer/organizer_dashboard_view.dart`: Host metrics, revenue, check-in stats, create event dialog.
  - `lib/views/organizer/organizer_scanner_view.dart`: Check-in terminal with camera scanner, flashlight, test code presets, duplicate ticket guard.
- **Admin Flow**:
  - `lib/views/admin/admin_governance_view.dart`: Queue review, approve/reject events, ticket security auditor with cryptographic hash check.
- **Shared / Global**:
  - `lib/views/shared/notification_center_modal.dart`: Real-time notification tray with sound and badges.
  - `lib/views/shared/camera_qr_scanner_widget.dart`: Reusable camera scanner with animated laser & flashlight.
  - `lib/views/shared/profile_view.dart`: Profile photo upload, dark/light theme; the role switcher appears in demo mode only.
