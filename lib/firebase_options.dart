import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// PLACEHOLDER — replaced when you run `flutterfire configure`.
///
/// Until then, `main.dart` catches the error below and the app runs in
/// offline demo mode (mock data, simulated login).
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    throw UnsupportedError(
      'Firebase is not configured yet. Run `flutterfire configure` '
      '(see SETUP_GUIDE.md).',
    );
  }
}
