import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import '../lib/main.dart';

void main() {
  setUpAll(() {
    // Disable HTTP runtime font fetching in widget tests to avoid NetworkException / HttpException
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('EventPulseApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EventPulseApp());
    await tester.pumpAndSettle();

    // Verify root app and navigation bar are rendered
    expect(find.byType(EventPulseApp), findsOneWidget);
    expect(find.byType(MainMobileNavigation), findsOneWidget);
  });
}
