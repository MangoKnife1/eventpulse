# EventPulse: Complete Setup & Defense Guide

This is the one document you need: installing tools, connecting Firebase and Cloudinary, creating the admin,
loading demo data, running the app, and demonstrating it at your defense.

---

## 0. How the app works (read once)

The app has **two modes**, using the same screens:

| Mode | When it is active | Data |
| :--- | :--- | :--- |
| **Demo** | Firebase is not configured yet | Built-in sample data, simulated login, role switcher on the profile screen |
| **Live** | After `flutterfire configure` | Firebase Auth + Cloud Firestore for data, Cloudinary for images |

So `flutter run` works from the very first minute. You can tell you are in **live** mode when the role badge at the top
no longer opens a role switcher.

**What is stored where**

| Service | Stores |
| :--- | :--- |
| Firebase Auth | Logins (email + hashed password, or Google account) |
| Cloud Firestore | `users`, `events`, `tickets`, `notifications`, `organizerApplications` |
| Cloudinary | Images only: event banners (`eventpulse/banners`) and profile photos (`eventpulse/avatars`). Firestore keeps just the image link. |

**Roles:** everyone registers as an **attendee**. Organizers apply and an admin approves them. Admins are set by hand in
the Firebase console. The app cannot grant roles (enforced by `firestore.rules`).

---

## 1. Install the tools (one time)

| Tool | Get it | Check with |
| :--- | :--- | :--- |
| Flutter SDK | <https://docs.flutter.dev/get-started/install> | `flutter --version` |
| Node.js 18 or newer | <https://nodejs.org> | `node --version` |
| VS Code + Flutter and Dart extensions | <https://code.visualstudio.com> | |
| Android Studio (for the emulator / Android SDK) | <https://developer.android.com/studio> | `flutter doctor` |

Run `flutter doctor` and fix anything marked with a red cross. **Restart VS Code** after installing anything so it
picks up the new PATH.

---

## 2. First run (demo mode, no setup)

Open the project folder in VS Code (*File > Open Folder*), then open the terminal with `` Ctrl+` ``:

```bash
flutter pub get
flutter analyze
flutter run
```

`flutter run` asks which device to use if several are available. Useful choices:

- `flutter run -d chrome` for web
- `flutter run -d windows` for Windows desktop
- an Android emulator or phone (start it first; check with `flutter devices`)

`flutter analyze` should report no **errors**. If it does, send them to me.

---

## 3. Firebase setup

### 3.1 Create the project
1. Go to <https://console.firebase.google.com> > **Add project** (Analytics is optional).
2. **Build > Authentication > Get started > Sign-in method**: enable **Email/Password** and **Google**.
   (For Google, pick a support email when asked.)
3. **Build > Firestore Database > Create database**: choose a location near you and **production mode**.

### 3.2 Install the command-line tools
```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
```
If `flutterfire` is "not recognized", add Dart's pub cache to your PATH and restart VS Code:
Windows `%LOCALAPPDATA%\Pub\Cache\bin`, macOS/Linux `$HOME/.pub-cache/bin`.

### 3.3 Connect the app to your project
In the project folder:
```bash
flutterfire configure
```
Choose your Firebase project and tick the platforms you use (Android, and Web if you run in Chrome). This
**overwrites `lib/firebase_options.dart`** and downloads `android/app/google-services.json`.
The Android application id is `com.example.eventpulse`.

If an Android build later complains about `google-services.json` or the Google services plugin, add it manually:
- `android/settings.gradle`, inside the `plugins { }` block:
  `id "com.google.gms.google-services" version "4.4.2" apply false`
- `android/app/build.gradle`, inside its `plugins { }` block:
  `id "com.google.gms.google-services"`

### 3.4 Publish the security rules
```bash
firebase use --add          # pick your project once (creates .firebaserc)
firebase deploy --only firestore:rules
```
Alternative: copy the contents of `firestore.rules` into *Firestore > Rules* in the console and click **Publish**.

### 3.5 Google sign-in on Android (only if you use it)
Get your debug fingerprints (Windows PowerShell):
```powershell
cd android
.\gradlew signingReport
```
Copy the **SHA1** and **SHA-256** lines under `Variant: debug`. Alternative without Gradle:
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```
Add the **SHA-1** and **SHA-256** under *Project settings > Your apps > Android app*, then run
`flutterfire configure` again. (Web sign-in works on `localhost` without this.)

---

## 4. Cloudinary setup

1. Create a free account at <https://cloudinary.com>. Copy your **Cloud name** from the dashboard.
2. **Settings > Upload > Upload presets > Add upload preset**
   - **Signing mode: Unsigned**
   - Folder: `eventpulse` (optional)
   - Allowed formats: `jpg, png, webp`; set a max file size if you like
3. Put the two values in **`lib/config/app_config.dart`**:
   ```dart
   defaultValue: 'your-cloud-name',      // CLOUDINARY_CLOUD_NAME
   defaultValue: 'your-unsigned-preset', // CLOUDINARY_UPLOAD_PRESET
   ```
   or pass them when running (nothing written in files):
   ```bash
   flutter run --dart-define=CLOUDINARY_CLOUD_NAME=yourname --dart-define=CLOUDINARY_UPLOAD_PRESET=yourpreset
   ```

### What is secret and what is not

| Value | Secret? | Where it goes |
| :--- | :--- | :--- |
| Firebase config (`firebase_options.dart`, `google-services.json`) | No. Your Firestore rules protect the data. | Generated by `flutterfire configure` |
| Cloudinary cloud name, unsigned preset name | No | `lib/config/app_config.dart` |
| Cloudinary **API key / API secret** | **Yes** | **Never in the app.** Not needed. |
| Firebase **service account key** (`serviceAccountKey.json`) | **Yes** | Only `tools/seed/`, git-ignored. Never share it. |

---

## 5. Create your first admin

The admin role cannot be created inside the app.

1. Run the app in live mode and **register a normal account**.
2. Firebase console > **Firestore Database > Data > `users`** > open your document (find it by `email`).
3. Change `role` to `admin` (lowercase string) and `isOrganizerApproved` to `true` (boolean).
4. Go back to the app. It updates by itself; if not, sign out and in. The admin governance screen appears.

**Admin can:** approve/decline organizer applications, approve/decline events, see all events and tickets, and create
events that publish immediately.

**Organizers:** register with **Event Organizer**. The request appears in the admin tab under *Organizer Applications*.
After approval they can create events (which start as *pending* until an admin approves them) and scan passes.

---

## 6. Load demo data (already in Firebase + Cloudinary)

The seeder uploads banners to **your** Cloudinary and inserts events into **your** Firestore. Their spot counters start
at 0, so registering live shows honest numbers.

1. Have an organizer or admin account (section 5) and note its email.
2. Firebase console > **Project settings > Service accounts > Generate new private key**.
   Save it as `tools/seed/serviceAccountKey.json`. **Never commit or share it.**
3. Copy `tools/seed/.env.example` to `tools/seed/.env` and fill in:
   ```
   CLOUDINARY_CLOUD_NAME=yourname
   CLOUDINARY_UPLOAD_PRESET=yourpreset
   ORGANIZER_EMAIL=the-account@example.com
   ```
4. Run it:
   ```bash
   cd tools/seed
   npm install
   npm run seed            # 7 hand-written events (5 approved, 2 pending for the approval demo)
   npm run seed:random     # those 7 + 20 random events across all categories
   node seed.js --random 35   # any number up to 40
   ```

| Command | What it does |
| :--- | :--- |
| `npm run seed` / `seed:random` | Insert or refresh events. Safe to re-run: same ids, banners not re-uploaded, dates moved back to "upcoming". |
| `npm run reset` | Put approvals, spot counters and tickets back to the starting state (use after a rehearsal). |
| `npm run wipe` | Delete **all** seeded events (ids starting `seed_`) and their tickets. Events you made in the app stay. |

Random events are the same on every run (fixed seed), so the data you rehearse with is the data you defend with.
About 1 in 8 is left **pending** for the admin approval step.

### Using your own photos (recommended for a nicer demo)
Drop `.jpg`, `.png` or `.webp` files into `tools/seed/images/` (or per category, e.g. `images/technology/`,
`images/design/`, `images/music-arts/`, `images/community/`, `images/gaming/`). The script uploads them to Cloudinary and
uses them as banners. With no files there, it uses online sample photos (and a placeholder photo if one of those links
is dead). Good free sources: Unsplash, Pexels, Pixabay. Landscape, about 1200x675, under 1 MB each.

Delete banners later in Cloudinary's Media Library (they carry the tag `eventpulse-seed`).

### Editing by hand in the Firebase console
Open **Firestore > events** to change a title, venue, capacity or `approvalStatus` (`approved`, `pending`, `rejected`).
The app updates live. To add a single event with a photo: upload the image in the app (Create Meetup) or in Cloudinary's
Media Library, then paste its link into the event's `imageUrl` field.

### Profile pictures
New accounts have **no photo**: the app shows a grey silhouette (built in, nothing to download). Users add one by tapping
their avatar on the Profile screen, which uploads to Cloudinary. Accounts created by older versions that still have the
old stock default are shown as silhouettes too.

## 7. Defense walkthrough

Prepare **three accounts** ahead of time: an admin, an organizer (approved), and an attendee.

1. **Guest:** open the app without signing in and browse events. Point out that registering asks you to sign in.
2. **Attendee:** sign in, open an event, register. A QR pass is issued under *My Passes*. Note the spot counter going down.
3. **Organizer application (optional):** register a fresh organizer account. It files an application.
4. **Admin:** approve the application, then approve one of the two pending events. Show that the organizer is notified.
5. **Organizer:** create a new event with a banner uploaded from the phone or computer (this goes to Cloudinary). It
   appears as *pending* until the admin approves it.
6. **Check-in:** as organizer, scan the attendee's QR (or type the pass code). Scan it a second time to show the
   **duplicate pass** rejection.
7. **Proof of storage:** show the Firestore data in the Firebase console and the uploaded banners in Cloudinary's Media Library.
8. **Security (optional):** try to set your own role in the app: it cannot. Mention `firestore.rules`.

Tip: keep a second device or browser window for the attendee so you don't have to sign out and in repeatedly.

---

## 8. Troubleshooting

| Problem | Fix |
| :--- | :--- |
| Older account (e.g. your admin) **won't sign in** | The app now requires a **verified email** for email/password accounts. Accounts made before that are unverified. Easiest fix: `cd tools/seed` then `npm run verify -- your@email.com` (also shows the account's sign-in types and role). Or sign in once: a verification link is emailed (check Spam); open it, then sign in again. |
| "Continue with Google" fails on **Android** | Add the debug **SHA-1 and SHA-256** in Firebase > Project settings > Your apps > Android, then run `flutterfire configure` again and fully restart the app (section 3.5). The error now shows a short code. |
| Google sign-in fails on **web/Chrome** | Firebase > Authentication > Settings > Authorized domains must include `localhost`; allow popups; Google must be enabled under Sign-in method. |
| Gradle / AGP / Kotlin "will soon be dropped" warnings | Only warnings; the build still works. Ignore them for now, or add `--android-skip-build-dependency-validation` to `flutter run`. The "Note: ... unchecked or unsafe operations" lines are normal. |
| RSVP / "Get Free Ticket" fails with **(permission-denied)** | The latest `firestore.rules` is not published. Run `firebase deploy --only firestore:rules` (or paste the file into Firestore > Rules > Publish). Older rules blocked the "do I already have a ticket?" check. |
| RSVP error text is hidden | Errors now appear inside the event sheet, in red, above the button, with a short code you can screenshot. |
| A seeded event shows the wrong spots left after failed tries | `cd tools/seed && npm run reset` |
| Tag filter chips missing | The chips are built from the tags of approved events. Add tags when creating events (organizer form) or run the seeder. |
| `flutterfire` / `firebase` not recognized | Fix PATH (section 3.2) and restart VS Code |
| PowerShell blocks `npm` / `firebase` scripts | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or use Command Prompt |
| "permission denied" messages in the app | Rules not deployed: `firebase deploy --only firestore:rules`. Also check roles/spelling in `users`. |
| Admin screen doesn't appear | `role` must be exactly `admin` (lowercase). Sign out and back in. |
| Events don't show up | Approved events only. Check `approvalStatus` is `approved` in Firestore; pending ones are in the admin tab. |
| "Image upload is not set up yet" | Fill in the two values in `app_config.dart` (or use `--dart-define`) |
| Cloudinary "Upload preset not found" / "must be unsigned" | Preset name typo, or signing mode isn't *Unsigned* |
| Google sign-in fails on Android | Add SHA-1/SHA-256 and re-run `flutterfire configure` (section 3.5) |
| Seed: "No account found for ..." | Register that email in the app first |
| Seed: "Missing serviceAccountKey.json" | Section 6, step 2 |
| Build error about `minSdk` | Already set to 23 in `android/app/build.gradle` (required by Firebase) |
| App runs but still shows demo role switcher | Firebase isn't configured: `lib/firebase_options.dart` is still the placeholder. Re-run `flutterfire configure`. |
| Something else | Run `flutter analyze` and `flutter run` and send me the full message |

---

## 9. Project map

| Path | Purpose |
| :--- | :--- |
| `lib/main.dart` | App start, Firebase init, providers, top bar |
| `lib/config/app_config.dart` | Cloudinary cloud name + preset |
| `lib/firebase_options.dart` | Firebase config (generated by `flutterfire configure`) |
| `lib/services/auth_service.dart` | Sign in/up, Google, profile, sign out |
| `lib/services/event_service.dart` | Events, registration, check-in, approvals, notifications |
| `lib/services/cloudinary_service.dart` | Image picking and upload |
| `lib/services/demo_data.dart` | Offline sample data (demo mode only) |
| `lib/views/shared/user_avatar.dart`, `network_banner.dart` | Silhouette avatar; banner with loading/error states |
| `lib/models/` | Data classes (user, event, ticket, notification, application) |
| `lib/views/` | Screens (attendee, organizer, admin, shared) |
| `firestore.rules` | Security rules |
| `tools/seed/` | Demo-data loader (Firebase + Cloudinary) |
| `FIREBASE_SCHEMA_GUIDE.md` | Firestore collections and fields |

## 10. Good to know
- **Each ticket has its own QR code.** The pass code is `EP-<event>-<attendee fingerprint>-<random>`: the fingerprint is derived
  from that attendee + that event, so two attendees (or two events) never share a code. It holds no name or email.
  Ticket ids are `<eventId>_<userId>`, so one person cannot hold two tickets for the same event.
- Registration and check-in use Firestore **transactions**: no overbooking, one ticket per person per event, and a QR
  pass cannot be admitted twice, even from two scanners.
- Pass codes are random and contain no personal data.
- `firebase-applet-config.json` and `firebase-blueprint.json` came from the AI Studio export and are **not used**.
- The app was not built or run on my side, so run `flutter analyze` once and report any errors.
