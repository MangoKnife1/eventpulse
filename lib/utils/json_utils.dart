/// Reads a date from an ISO-8601 string, a [DateTime], or a Firestore
/// `Timestamp` (anything exposing `toDate()`), so documents edited by hand in
/// the Firebase console don't crash the app.
DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final converted = (value as dynamic).toDate();
    if (converted is DateTime) return converted;
  } catch (_) {}
  return null;
}
