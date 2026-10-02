import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// A user-presentable error. The [message] is safe to show in a SnackBar.
class ServiceException implements Exception {
  final String message;
  const ServiceException(this.message);

  @override
  String toString() => message;
}

/// Turns any thrown object into text that is safe to show to the user.
/// Firebase errors keep their short code, e.g. "(permission-denied)", so a
/// problem can be diagnosed from a screenshot.
String friendlyError(Object error) {
  if (error is ServiceException) return error.message;
  debugPrint('Unexpected error: $error');
  if (error is FirebaseException) {
    return '${firebaseErrorText(error)} (${error.code})';
  }
  return kDebugMode
      ? 'Something went wrong: $error'
      : 'Something went wrong. Please try again.';
}

String firebaseErrorText(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Not allowed by the database rules. If this is unexpected, publish the latest firestore.rules';
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-request-failed':
      return 'An internet connection is required for this action. Please reconnect and try again';
    case 'failed-precondition':
      return 'The database needs an index or the data changed. Please try again';
    case 'not-found':
      return 'That item no longer exists';
    case 'aborted':
      return 'Too many people at once. Please try again';
    default:
      return 'Could not complete that action';
  }
}
