import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// CameraService provides a centralized API for checking, requesting,
/// and auditing CAMERA permissions using the permission_handler package.
///
/// It ensures the app gracefully handles:
/// 1. Pre-flight checks before opening the QR scanner component.
/// 2. User-friendly rationale modal explaining why camera access is required.
/// 3. Redirection to system app settings if permission is permanently denied.
class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  /// Check whether CAMERA permission is currently granted
  Future<bool> hasCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('CameraService.hasCameraPermission error: $e');
      return false;
    }
  }

  /// Get detailed current permission status (granted, denied, restricted, permanentlyDenied)
  Future<PermissionStatus> getCameraStatus() async {
    try {
      return await Permission.camera.status;
    } catch (e) {
      debugPrint('CameraService.getCameraStatus error: $e');
      return PermissionStatus.denied;
    }
  }

  /// Direct OS request for camera permission
  Future<PermissionStatus> requestPermission() async {
    try {
      return await Permission.camera.request();
    } catch (e) {
      debugPrint('CameraService.requestPermission error: $e');
      return PermissionStatus.denied;
    }
  }

  /// Open Android/iOS system application settings page
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (e) {
      debugPrint('CameraService.openSettings error: $e');
      return false;
    }
  }

  /// Pre-flight check before opening the QR scanner component.
  /// 
  /// Flow:
  /// - If already granted: executes [onGranted] immediately and returns true.
  /// - If permanently denied: presents a dialog with a direct action to open App Settings.
  /// - If denied / not yet requested: presents an informative rationale dialog before requesting.
  /// - If granted after prompt: triggers haptic feedback, shows toast, and invokes [onGranted].
  /// - If denied: invokes [onDenied] and allows fallback to manual code entry.
  Future<bool> checkBeforeOpeningScanner({
    required BuildContext context,
    VoidCallback? onGranted,
    VoidCallback? onDenied,
    String? featureTitle,
  }) async {
    try {
      final status = await Permission.camera.status;

      // 1. Already granted - open scanner immediately
      if (status.isGranted) {
        if (onGranted != null) {
          onGranted();
        }
        return true;
      }

      // 2. Permanently denied - guide user to App Settings
      if (status.isPermanentlyDenied || status.isRestricted) {
        if (!context.mounted) return false;
        final shouldOpen = await showPermanentlyDeniedDialog(context);
        if (shouldOpen == true) {
          await openAppSettings();
        }
        if (onDenied != null) {
          onDenied();
        }
        return false;
      }

      // 3. Needs request - display transparent rationale dialog
      if (!context.mounted) return false;
      final userAgreed = await showPermissionRationaleDialog(
        context,
        featureTitle: featureTitle ?? 'Door QR Scanner',
      );

      if (!userAgreed) {
        if (onDenied != null) {
          onDenied();
        }
        return false;
      }

      // 4. Request from OS
      final newStatus = await Permission.camera.request();

      if (newStatus.isGranted) {
        HapticFeedback.mediumImpact();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera access granted! Opening scanner...'),
              backgroundColor: Color(0xFF10B981),
              duration: Duration(seconds: 2),
            ),
          );
        }
        if (onGranted != null) {
          onGranted();
        }
        return true;
      } else if (newStatus.isPermanentlyDenied) {
        if (context.mounted) {
          final shouldOpen = await showPermanentlyDeniedDialog(context);
          if (shouldOpen == true) {
            await openAppSettings();
          }
        }
        if (onDenied != null) {
          onDenied();
        }
        return false;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera access was denied. You can enter ticket codes manually below.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        if (onDenied != null) {
          onDenied();
        }
        return false;
      }
    } catch (e) {
      debugPrint('CameraService.checkBeforeOpeningScanner error: $e');
      // If error occurs, invoke onGranted or onDenied gracefully
      if (onGranted != null) {
        onGranted();
      }
      return true;
    }
  }

  /// Informative rationale dialog detailing why CAMERA access is necessary
  Future<bool> showPermissionRationaleDialog(
    BuildContext context, {
    String featureTitle = 'Door QR Scanner',
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5238).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.camera_alt, color: Color(0xFFFF5238), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Camera Permission',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    featureTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EventPulse requires camera access to scan attendee QR tickets and verify admissions at the door.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.security, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '100% On-Device: Video feed is processed locally to parse QR codes. No photos or video frames are saved or transmitted.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Not Now',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5238),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue & Allow', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Dialog shown when user has selected "Don't ask again" or blocked camera in system settings
  Future<bool> showPermanentlyDeniedDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.no_photography, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Camera Access Blocked',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera permission was previously disabled in system settings. To use the live QR scanner, please enable Camera permission in App Settings.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Steps: Settings > Apps > EventPulse > Permissions > Camera > Allow.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5238),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
