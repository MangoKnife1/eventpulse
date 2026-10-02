# CHAPTER 2: SYSTEM ANALYSIS AND DESIGN
## Project: EventPulse (Community Event & QR Ticketing System)

---

## 2.1 Project Overview

### What is EventPulse?
**EventPulse** is a cross-platform mobile and web application designed for campus and community events. It allows members to discover events, register with one click, receive a digital ticket with a unique QR code, and check in at the venue entrance using a live camera scanner.

### The Problems It Solves
1. **Messy Manual Tracking:** Organizers usually juggle Google Forms, spreadsheets, and printed paper rosters at the door, which creates long lines and confusion.
2. **Fake or Shared Tickets:** People can easily share screenshots of basic tickets. EventPulse uses unique, verifiable QR ticket codes (`EP-TKT-...`) that can only be scanned once.
3. **No Role Separation:** Standard apps don't separate roles well. EventPulse gives dedicated views for **Attendees**, **Event Hosts (Organizers)**, and **Campus Admins**.

---

## 2.2 Comparison with Existing Systems

| Feature | Eventbrite | Luma / Google Forms | EventPulse |
| :--- | :--- | :--- | :--- |
| **Target Audience** | Big paid commercial events | Casual meetups / basic forms | Campus clubs & local communities |
| **Door Check-In** | Requires separate paid app | Web link or paper list | Built-in camera scanner with flashlight |
| **Duplicate Ticket Warning**| Yes | No (easy to reuse screenshots) | Yes (instant alert if ticket is already scanned) |
| **Role Views** | Organizer vs Buyer | Single form viewer | 3 separate views: Attendee, Organizer, Admin |
| **Event Approval Queue** | Automated / None | None | Admin review queue to keep events safe |
| **Cost & Open Source** | High fees on paid tickets | Subscription / basic tool | Free, open Flutter + Firebase system |

---

## 2.3 Conceptual Framework (How the System Works)

The system follows a simple **Input – Process – Output** flow:

```
[ INPUTS ]
• User login (Email or Google)
• Event details (Title, Date, Time, Venue, Max Capacity, Poster Image)
• Attendee RSVP click
• Camera QR scan at the door
• Admin approval or rejection click

       │
       ▼
[ PROCESSES ]
• Check user role (Attendee, Organizer, or Admin)
• Reserve spot and reduce available capacity
• Create ticket with unique QR code payload (EP-TKT-XXXX)
• Scan QR code using phone camera
• Prevent duplicate entry (mark ticket as "used" immediately upon scan)
• Send in-app notification alerts

       │
       ▼
[ OUTPUTS ]
• Event list with live available seats
• Digital pass with dynamic QR code
• Instant door check-in feedback (Green = Valid, Amber = Already Used, Red = Invalid)
• Organizer live attendance dashboard
• Admin moderation log
```

---

## 2.4 User Roles & Personas

### 1. Attendee (Community Member / Student)
- **Goal:** Find fun workshops and meetups, sign up quickly, and get into the event without hassle.
- **Key Actions:**
  - Browse events by category (Tech, Design, Social, Workshops).
  - Tap "Register" to get a pass.
  - Show the QR code on the "My Passes" screen at the entrance.

### 2. Organizer (Host / Club Officer)
- **Goal:** Host events, fill seats, and check people in quickly at the door.
- **Key Actions:**
  - Create event listings and submit for approval.
  - Open the camera scanner to verify attendee QR codes.
  - See real-time counts of who has arrived.

### 3. Administrator (Campus Coordinator)
- **Goal:** Keep the community safe by vetting events and organizers.
- **Key Actions:**
  - Review submitted events (Approve or Reject with feedback).
  - Review host applications.
  - Audit tickets to verify authenticity.

---

## 2.5 System Requirements

### Functional Requirements (What the app does):
- **FR-01 (Login & Roles):** Users sign in and get the right navigation tabs for their role.
- **FR-02 (Event Directory):** Browse approved events and filter by category or search by keyword.
- **FR-03 (One-Tap RSVP):** Register for an event; the app automatically updates remaining spots.
- **FR-04 (Digital QR Pass):** Display a clean ticket pass with the attendee's name, event details, and unique QR code.
- **FR-05 (Camera Door Scanner):** Organizers scan tickets using the phone camera with an aiming box and flashlight toggle.
- **FR-06 (Duplicate Scan Guard):** The app accepts a ticket on the first scan, but blocks any repeated scan with an alert: *"Already Checked In"*.
- **FR-07 (Host Dashboard):** Hosts see total registered attendees and live check-in progress.
- **FR-08 (Admin Governance):** Admins approve or reject pending events before they show up in the public list.
- **FR-09 (Notifications):** In-app banner alerts for ticket confirmations and event updates.

### Non-Functional Requirements (How well it performs):
- **Speed:** Door scanner verifies a ticket in less than 1 second.
- **Security:** Firestore security rules prevent unauthorized edits and stop anyone from faking check-ins.
- **Look & Feel:** Clean Material 3 design with full Dark Mode and Light Mode support.
- **Reliability:** Works smoothly on both Android and Web.

---

## 2.6 Step-by-Step Use Cases

### Use Case 1: Registering for an Event
1. Attendee opens the **Discover** tab.
2. Taps on an event (e.g., *"NextGen Mobile Dev Meetup"*).
3. Taps **"Register for Free Pass"**.
4. The system checks if there are spots left.
5. If open, the system generates a ticket with code `EP-TKT-...` and saves it to the database.
6. Attendee is redirected to **My Passes** where their ticket appears.

### Use Case 2: Checking In at the Door (Organizer)
1. Organizer opens the **Scanner** tab on their phone.
2. Points camera at attendee's screen.
3. System reads the QR code:
   - **If Valid & Not Used:** Screen flashes Green, plays success chime, marks ticket as used with timestamp.
   - **If Already Used:** Screen flashes Amber with warning: *"Duplicate Ticket! Already scanned at 6:32 PM"*.
   - **If Wrong Event:** Screen flashes Red: *"Invalid Pass for this Event"*.
4. Total checked-in count updates automatically.

### Use Case 3: Admin Approving a New Event
1. Organizer submits a new event. It is marked as `pending`.
2. Admin opens the **Governance** tab.
3. Admin reviews event title, date, venue, and description.
4. Admin clicks **"Approve"**.
5. The event status changes to `approved` and immediately appears on the public Discover feed.

---

## 2.7 Database Structure (Google Cloud Firestore)

The database uses 5 simple collections:

### 1. `users`
Stores user accounts and permissions.
- `id` (Text) - User ID
- `name` (Text) - Full Name
- `email` (Text) - Email Address
- `role` (Text) - `"user"`, `"organizer"`, or `"admin"`
- `organization` (Text) - Club or department name

### 2. `events`
Stores all event details.
- `id` (Text) - Event ID
- `title` (Text) - Event Title
- `category` (Text) - Category (e.g. Technology, Design, Workshops)
- `dateTime` (Text) - Date & Time
- `venueName` (Text) - Hall or Room Name
- `capacity` (Number) - Max attendees allowed
- `registeredCount` (Number) - Number of people who RSVP'd
- `organizerId` (Text) - User ID of the host
- `approvalStatus` (Text) - `"pending"`, `"approved"`, or `"rejected"`

### 3. `tickets`
Stores each individual issued ticket.
- `id` (Text) - Ticket ID
- `ticketCode` (Text) - Unique QR text (e.g. `EP-TKT-FLUTTER26-ALEX01`)
- `eventId` (Text) - ID of the event
- `userId` (Text) - ID of the attendee
- `userName` (Text) - Name of attendee
- `checkedIn` (True/False) - Whether scanned at door
- `checkedInAt` (Text/Null) - Time scanned at door
- `status` (Text) - `"valid"`, `"checkedIn"`, or `"cancelled"`

### 4. `organizerApplications`
Stores requests from members who want to become event hosts.
- `userId`, `organizationName`, `reason`, `status` (`"pending"`, `"approved"`)

### 5. `notifications`
Stores in-app messages and reminders.
- `userId`, `title`, `message`, `timestamp`, `read` (True/False)

---

## 2.8 Screen Layouts

1. **Discover Screen:** Top search bar, category chips (`All`, `Tech`, `Design`, `Social`), and event cards showing cover image, date, venue, and remaining spots.
2. **My Passes Screen:** Perforated ticket cards showing event name, date, time, and a large, high-contrast QR code for door scanning.
3. **Scanner Screen (Organizer):** Live camera view with an aiming square, a flashlight switch, and instant check-in confirmation popups.
4. **Host Studio (Organizer):** Summary cards showing total events hosted, total attendees, and a button to create a new event.
5. **Governance Screen (Admin):** Clean list of pending events waiting for admin approval, with one-click "Approve" or "Reject" buttons.

---

## 2.9 Technology Stack

- **Mobile App:** Flutter 3.x (Dart), running on Android and iOS.
- **Web App:** React 19, TypeScript, Tailwind CSS, Vite.
- **Database & Auth:** Google Cloud Firestore (real-time NoSQL) and Firebase Authentication.
- **State Management:** Provider pattern for reactive UI updates.
- **Hardware Integration:** Device camera with auto-focus and flashlight for QR decoding.

---

## 2.10 Summary

Chapter 2 outlines the design and structure of **EventPulse**. By replacing paper sign-in sheets and easily duplicated screenshots with dynamic QR passes, a fast camera check-in terminal, and an administrative approval queue, EventPulse offers a simple, secure, and modern way to run community events.
