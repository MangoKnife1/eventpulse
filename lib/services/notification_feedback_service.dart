import 'package:flutter/material.dart';

import '../models/notification_model.dart';
import '../views/shared/notification_center_modal.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Presents notifications that arrive while the app is in the foreground.
class NotificationFeedbackService {
  NotificationFeedbackService._();

  static final instance = NotificationFeedbackService._();

  bool _isShowing = false;

  Future<void> show(NotificationModel notification) async {
    final context = navigatorKey.currentContext;
    if (context == null || _isShowing) return;

    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(notification.title),
          content: Text(notification.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('DISMISS'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                NotificationCenterModal.show(context);
              },
              child: const Text('VIEW'),
            ),
          ],
        ),
      );
    } finally {
      _isShowing = false;
    }
  }
}
