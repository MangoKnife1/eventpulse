import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../lib/services/event_service.dart';
import '../lib/services/camera_service.dart';
import '../lib/models/ticket_model.dart';
import '../lib/views/shared/camera_qr_scanner_widget.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('EventService Ticket Check-In Unit Tests', () {
    late EventService eventService;

    setUp(() {
      eventService = EventService();
    });

    test('valid ticket approval succeeds and marks ticket as checkedIn', () async {
      // Find a ready (valid) ticket from seed data
      final validTicket = eventService.userTickets.firstWhere(
        (t) => t.status == TicketStatus.valid,
      );

      final result = await eventService.checkInTicketWithCode(validTicket.qrPayload);

      expect(result['success'], isTrue);
      expect(result['status'], 'valid');
      expect(result['message'], contains('Entry Approved'));

      // Verify ticket state updated in service
      final updatedTicket = eventService.userTickets.firstWhere((t) => t.id == validTicket.id);
      expect(updatedTicket.status, TicketStatus.checkedIn);
      expect(updatedTicket.checkedInAt, isNotNull);
    });

    test('successful check-in pops up a notification and notifies the attendee', () async {
      final popups = <String>[];
      final sub = eventService.incomingNotifications.listen((n) => popups.add(n.title));

      final validTicket = eventService.userTickets.firstWhere(
        (t) => t.status == TicketStatus.valid,
      );
      final before = eventService.notifications.length;
      await eventService.checkInTicketWithCode(validTicket.qrPayload);
      await Future<void>.delayed(Duration.zero);

      expect(popups.any((t) => t.startsWith('Checked in:')), isTrue);
      expect(eventService.notifications.length, before + 1); // attendee's saved notification
      await sub.cancel();
    });

    test('a rejected check-in does not pop up anything', () async {
      final popups = <String>[];
      final sub = eventService.incomingNotifications.listen((n) => popups.add(n.title));
      await eventService.checkInTicketWithCode('EP-NOT-A-REAL-CODE');
      await Future<void>.delayed(Duration.zero);
      expect(popups, isEmpty);
      await sub.cancel();
    });

    test('invalid ticket rejection returns success false and invalid status', () async {
      final result = await eventService.checkInTicketWithCode('FORGED-OR-NONEXISTENT-CODE-999');

      expect(result['success'], isFalse);
      expect(result['status'], 'invalid');
      expect(result['message'], contains('Invalid QR Code'));
    });

    test('already checked-in ticket returns duplicate rejection', () async {
      // Find a valid ticket and check it in first
      final ticket = eventService.userTickets.firstWhere(
        (t) => t.status == TicketStatus.valid,
      );
      final firstCheckIn = await eventService.checkInTicketWithCode(ticket.qrPayload);
      expect(firstCheckIn['success'], isTrue);

      // Second check-in attempt with the same code
      final secondCheckIn = await eventService.checkInTicketWithCode(ticket.qrPayload);
      expect(secondCheckIn['success'], isFalse);
      expect(secondCheckIn['status'], 'already_used');
      expect(secondCheckIn['message'], contains('Duplicate Pass'));
    });

    test('wrong event target rejection prevents check-in at mismatched gate', () async {
      final ticket = eventService.userTickets.firstWhere(
        (t) => t.status == TicketStatus.valid,
      );

      // Attempt check-in specifying a different target event ID
      final result = await eventService.checkInTicketWithCode(
        ticket.qrPayload,
        targetEventId: 'completely_different_event_id',
      );

      expect(result['success'], isFalse);
      expect(result['status'], 'wrong_event');
      expect(result['message'], contains('Wrong Event'));
    });
  });

  group('CameraService Permission Scenarios', () {
    test('CameraService singleton is initialized', () {
      expect(CameraService.instance, isNotNull);
    });
  });

  group('CameraQrScannerWidget Lifecycle and UI Tests', () {
    testWidgets('renders the production live scanner surface', (WidgetTester tester) async {
      final eventService = EventService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EventService>.value(
              value: eventService,
              child: const CameraQrScannerWidget(
                title: 'Door Terminal Scanner',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Title rendered
      expect(find.text('Door Terminal Scanner'), findsOneWidget);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('QUICK VERIFICATION ALTERNATIVES'), findsNothing);
      expect(find.text('Upload Ticket Image'), findsNothing);
    });

    testWidgets('renders sound effect and subtle haptic feedback controls and toggles', (WidgetTester tester) async {
      final eventService = EventService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EventService>.value(
              value: eventService,
              child: const CameraQrScannerWidget(
                title: 'Door Terminal Scanner',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify sound and haptic control icon buttons exist in header
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
      expect(find.byIcon(Icons.vibration), findsOneWidget);

      // Tap sound toggle to mute sound effect
      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();
      expect(find.byIcon(Icons.volume_off), findsOneWidget);

      // Tap haptic toggle to disable haptic feedback
      await tester.tap(find.byIcon(Icons.vibration));
      await tester.pump();
      expect(find.byIcon(Icons.mobile_off), findsOneWidget);
    });

    testWidgets('scanner controller disposes safely when unmounted', (WidgetTester tester) async {
      final eventService = EventService();

      // Mount widget
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<EventService>.value(
              value: eventService,
              child: const CameraQrScannerWidget(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Unmount widget cleanly
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );
      await tester.pump();

      // No unhandled exceptions on dispose
      expect(find.byType(CameraQrScannerWidget), findsNothing);
    });
  });
}
