# EventPulse: Complete Step-by-Step Setup Guide

Follow the parts in order. Each part says what to do, what you should see, and what to do if it does not work.
Commands are for **Windows PowerShell inside VS Code** (open the terminal with `` Ctrl+` ``).

Time needed: about 30 to 40 minutes the first time.

---

## Part 0: What you are building

| Piece | What it does | Where it lives |
| :--- | :--- | :--- |
| Flutter app | The screens (attendee, organizer, admin) | this folder |
| Firebase Authentication | Sign-up and login (email/password and Google) | Firebase console |
| Cloud Firestore | Events, tickets, notifications, users, organizer applications | Firebase console |
| Cloudinary | Image storage (event banners, profile photos) | cloudinary.com |
| `tools/seed` | One-time helper that puts demo events (with images) into Firebase and Cloudinary | this folder |

The app has two modes. **Demo mode** (no Firebase configured) uses built-in sample data. **Live mode** (after Part 3)
uses your Firebase and Cloudinary. You are in live mode when the role badge at the top no longer opens a role switcher.

---

## Part 1: Install the tools (once)

1. **Flutter SDK**: <https://docs.flutter.dev/get-started/install>. Then run `flutter doctor` and fix any red cross.
2. **Node.js 18 or newer**: <https://nodejs.org>. Check with `node --version`.
3. **VS Code** with the **Flutter** and **Dart** extensions.
4. **Android Studio** (for the Android SDK and emulator) or a real Android phone with USB debugging.
5. **Restart VS Code** so it sees the new tools.

Check everything:
```powershell
flutter --version
node --version
npm --version
```

---

## Part 2: Open the project and run it in demo mode

1. VS Code: **File > Open Folder** and choose this project folder.
2. In the terminal:
```powershell
flutter pub get
flutter analyze
flutter run
```
3. Pick a device when asked (`flutter devices` lists them). Chrome is quick: `flutter run -d chrome`.

You should see the app with sample events. If `flutter analyze` prints **errors**, fix or report them before continuing
(warnings and "info" lines can be ignored).

**Gradle / Kotlin "will soon be dropped" warnings** are only warnings. The build still works. To hide them:
`flutter run --android-skip-build-dependency-validation`.

---

## Part 3: Firebase

### 3.1 Create the project
1. Go to <https://console.firebase.google.com> and click **Add project**. Name it (e.g. `eventpulse`).
2. **Build > Authentication > Get started > Sign-in method**: enable **Email/Password** and **Google**
   (choose a support email for Google).
3. **Build > Firestore Database > Create database**: pick a nearby location, start in **production mode**.

### 3.2 Install the command-line tools
```powershell
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```
If `flutterfire` is "not recognized": add `%LOCALAPPDATA%\Pub\Cache\bin` to your PATH and restart VS Code.
If PowerShell blocks scripts: run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once.

### 3.3 Connect the app to your project
In the project root folder:
```powershell
flutterfire configure
```
Choose your project and tick **Android** (and **Web** if you use Chrome). This replaces `lib/firebase_options.dart`,
creates `android/app/google-services.json` and adds the Google services plugin to the Android Gradle files.
The Android application id is `com.example.eventpulse`.

### 3.4 Publish the security rules (do this every time `firestore.rules` changes)
```powershell
firebase use --add
firebase deploy --only firestore:rules
```
`firebase use --add` is needed only once (pick your project). Wait for **Deploy complete!**.
**Check:** Firebase console > Firestore Database > Rules should show your newest rules and a recent "Last published" time.

> The notifications, tickets and check-in all depend on these rules. If something shows **permission-denied**, the
> rules were not published (or you published to a different project).

### 3.5 Google sign-in on Android
Without this, "Continue with Google" fails on Android.
```powershell
cd android
.\gradlew signingReport
cd ..
```
Copy the **SHA1** and **SHA-256** lines under `Variant: debug`. In Firebase console: **Project settings > Your apps >
Android > Add fingerprint**, add both. Then run `flutterfire configure` again and fully restart the app.
(On Chrome, `localhost` must be listed under Authentication > Settings > Authorized domains, which is the default.)

---

## Part 4: Cloudinary

1. Create a free account at <https://cloudinary.com>. Copy your **Cloud name** from the dashboard.
2. **Settings > Upload > Upload presets > Add upload preset**:
   - **Signing mode: Unsigned**
   - Folder: `eventpulse` (optional)
   - Allowed formats: `jpg, png, webp`
   - Save, and copy the preset **name**.
3. Open `lib/config/app_config.dart` and fill in the two empty strings:
```dart
defaultValue: 'your-cloud-name',      // CLOUDINARY_CLOUD_NAME
defaultValue: 'your-unsigned-preset', // CLOUDINARY_UPLOAD_PRESET
```
Or pass them when running (nothing written in files):
```powershell
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=yourname --dart-define=CLOUDINARY_UPLOAD_PRESET=yourpreset
```

### What is secret and what is not

| Value | Secret? | Where it goes |
| :--- | :--- | :--- |
| Firebase config (`firebase_options.dart`, `google-services.json`) | No (your rules protect the data) | Generated by `flutterfire configure` |
| Cloudinary cloud name and unsigned preset name | No | `lib/config/app_config.dart` |
| Cloudinary API key / API secret | **Yes** | Never in the app. Not needed. |
| Firebase **service account key** (`serviceAccountKey.json`) | **Yes** | Only in `tools/seed/`. **Never zip, upload or share it.** |
| `tools/seed/.env` | Keep private | Only in `tools/seed/` |

---

## Part 5: Create your first admin

The admin role cannot be created inside the app (on purpose).

1. Run the app (live mode) and **register a normal account**. You must **verify the email** (open the link that is
   emailed to you; check Spam) before you can sign in.
2. Firebase console > **Firestore Database > Data > `users`** > open your document (find it by `email`).
3. Change `role` to `admin` (lowercase text) and `isOrganizerApproved` to `true` (boolean).
4. Return to the app. The admin screen appears (sign out and in if it does not).

**An older account that cannot sign in** is usually unverified. From `tools/seed` (after Part 6 steps 1 to 3):
```powershell
npm run verify -- your@email.com
```

Organizers: register with **Event Organizer**. The request appears in the admin tab under *Organizer Applications*.
Approving it upgrades the role. Organizer events start as *pending* until an admin approves them.

---

## Part 6: Load demo events (already in Firebase and Cloudinary)

1. Firebase console > **Project settings > Service accounts > Generate new private key**. Save the file as
   `tools\seed\serviceAccountKey.json`. **Do not share or zip it.**
2. Copy `tools\seed\.env.example` to `tools\seed\.env` (the name starts with a dot) and fill in:
```
CLOUDINARY_CLOUD_NAME=yourname
CLOUDINARY_UPLOAD_PRESET=yourpreset
ORGANIZER_EMAIL=an-existing-organizer-or-admin@example.com
```
3. Install and run:
```powershell
cd tools\seed
npm install
npm run seed
```

| Command | What it does |
| :--- | :--- |
| `npm run seed` | 7 hand-written events (5 approved, 2 pending for the approval demo) |
| `npm run seed:random` | those 7 plus 20 random events |
| `node seed.js --random 35` | any number up to 40 |
| `npm run reset` | puts approvals, spot counters and tickets back to the start (use after a rehearsal) |
| `npm run wipe` | deletes all seeded events and their tickets |
| `npm run verify -- email` | shows an account's sign-in types and role, and marks its email verified |

It is safe to run again. The script checks that every event has what the app needs for RSVP and tells you if not.
Your own photos: put `.jpg/.png/.webp` files in `tools\seed\images\` (see the README there).

---

## Part 7: Notifications (what pops up, and when)

A popup appears at the bottom of the screen (with a **VIEW** button) and the item is saved in the bell icon's list.

| Event | Who gets it |
| :--- | :--- |
| Attendee is checked in at the door | The **attendee** ("You're checked in!") and a confirmation for the **organizer** ("Checked in: name") |
| Someone registers for an event | The **organizer** ("New registration") |
| Event approved or declined | The **organizer** |
| Organizer application approved or declined | The **applicant** |
| Reminder (15 min, 1 hour, 3 hours or 1 day before the event, set on the pass) | The **attendee** |

Good to know:
- Popups appear **while the app is open**. Reminders are checked every 30 seconds while the app is open.
- When the app is closed, nothing can pop up. Real push notifications to a closed app need Firebase Cloud Messaging
  plus a paid Cloud Functions setup, which this project does not use. For the defense, keep the app open.
- To test: open the attendee app on one device or browser window and the organizer on another. Check the attendee in
  and watch both screens.
- Notifications use the rules from Part 3.4. **Publish the newest `firestore.rules`.**

---

## Part 8: Defense walkthrough

Prepare three accounts: an admin, an approved organizer, and an attendee.

1. **Guest:** browse events without signing in.
2. **Attendee:** sign in, RSVP to an event. A unique QR pass appears under *My Passes*. Turn on a reminder.
3. **Organizer:** the "New registration" popup appears. Create an event with tags and a banner uploaded from the device.
4. **Admin:** approve the organizer application and the pending event. The organizer gets a popup.
5. **Check-in:** the organizer scans the QR (or types the pass code). Both devices show a popup. Scan the same pass
   again to show the **duplicate pass** rejection.
6. **Proof:** show the data in Firestore and the banners in Cloudinary's Media Library.
7. Before presenting, run `npm run reset` (in `tools\seed`) so the counters and approvals start clean.

---

## Part 9: Troubleshooting

| Problem | Fix |
| :--- | :--- |
| `flutterfire` or `firebase` not recognized | Fix PATH (Part 3.2) and restart VS Code |
| `npm run ...` says `Cannot find module 'firebase-admin'` | Run `npm install` inside `tools\seed` |
| **permission-denied** on RSVP, notifications or check-in | Publish the newest rules: `firebase deploy --only firestore:rules` |
| No popup appears | Rules not published (Part 3.4), or the app is closed, or you are in demo mode (see Part 0) |
| Account cannot sign in | Email not verified: `npm run verify -- email`, or open the verification link from the email |
| Google sign-in fails on Android | Add SHA-1 and SHA-256 (Part 3.5), run `flutterfire configure` again, restart the app |
| Admin screen does not appear | `role` must be exactly `admin` (lowercase). Sign out and in |
| Events do not show | Only approved events are public. Check `approvalStatus` in Firestore |
| "Image upload is not set up yet" | Fill `app_config.dart` (Part 4) or use `--dart-define` |
| Cloudinary "preset not found" or "must be unsigned" | Preset name typo, or its signing mode is not *Unsigned* |
| App still shows a role switcher | Firebase not configured: run `flutterfire configure` (Part 3.3) |
| Anything else | Run `flutter analyze` and `flutter run`, and send the full message |

---

## Part 10: Keep the folder small

The source code is only a few MB. A folder that is hundreds of MB is full of **generated files that are safe to delete**:

```powershell
flutter clean                       # deletes build\ and .dart_tool\
Remove-Item -Recurse -Force android\.gradle -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force tools\seed\node_modules -ErrorAction SilentlyContinue
```
They are re-created automatically by `flutter pub get` / `flutter run` / `npm install`.
When you zip the project, leave out `build`, `.dart_tool`, `node_modules`, `tools\seed\serviceAccountKey.json` and
`tools\seed\.env`.

Removed from this version because nothing used them: old alias files in `lib/views`, the unused `shared_preferences`
and `cupertino_icons` packages, IDE files (`.idea`, `.iml`), the Linux and macOS platform folders, and two leftover
AI Studio files. (To bring a platform back: `flutter create --platforms=linux,macos .`)

---

## Project map

| Path | Purpose |
| :--- | :--- |
| `lib/main.dart` | App start, providers, top bar, notification popups |
| `lib/config/app_config.dart` | Cloudinary cloud name and preset |
| `lib/firebase_options.dart` | Firebase config (generated by `flutterfire configure`) |
| `lib/services/auth_service.dart` | Sign-in and up, Google, profile |
| `lib/services/event_service.dart` | Events, RSVP, check-in, approvals, notifications, reminders |
| `lib/services/cloudinary_service.dart` | Image picking and upload |
| `lib/services/demo_data.dart` | Offline sample data (demo mode only) |
| `lib/views/` | Screens (attendee, organizer, admin, shared) |
| `firestore.rules` | Database security rules |
| `tools/seed/` | Demo-data loader and account helper |
| `FIREBASE_SCHEMA_GUIDE.md` | Database collections and fields |
