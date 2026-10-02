/// Central place for third-party configuration.
///
/// Values can be edited here or passed at build time, e.g.
///   flutter run --dart-define=CLOUDINARY_CLOUD_NAME=demo \
///               --dart-define=CLOUDINARY_UPLOAD_PRESET=eventpulse_unsigned
///
/// Never put a Cloudinary API *secret* in the app. Unsigned uploads only need
/// the cloud name and an unsigned upload preset.
class AppConfig {
  AppConfig._();

  // ── Cloudinary ────────────────────────────────────────────────────────────
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '', // TODO: your cloud name (Cloudinary dashboard)
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '', // TODO: an *unsigned* upload preset
  );

  static const String cloudinaryFolder = 'eventpulse';

  static bool get cloudinaryConfigured =>
      cloudinaryCloudName.isNotEmpty && cloudinaryUploadPreset.isNotEmpty;

  // ── Firestore ─────────────────────────────────────────────────────────────
  /// Use '(default)' for a normal Firebase project. Only change this if you
  /// created a named Firestore database.
  static const String firestoreDatabaseId = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
    defaultValue: '(default)',
  );
}
