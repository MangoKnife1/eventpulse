import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/event_service.dart';
import '../../services/camera_service.dart';
import '../../services/checkin_feedback_service.dart';
import '../../models/ticket_model.dart';

class CameraQrScannerWidget extends StatefulWidget {
  final String title;
  final String? targetEventId;
  final Function(String scannedCode)? onScan;
  final VoidCallback? onClose;

  const CameraQrScannerWidget({
    super.key,
    this.title = 'Live Door QR Scanner',
    this.targetEventId,
    this.onScan,
    this.onClose,
  });

  @override
  State<CameraQrScannerWidget> createState() => _CameraQrScannerWidgetState();
}

class _CameraQrScannerWidgetState extends State<CameraQrScannerWidget>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  MobileScannerController? _scannerController;
  bool _cameraActive = false;
  bool _hasCameraPermission = false;
  bool _permissionDenied = false;
  bool _isStartingCamera = false;
  bool _isCameraError = false;
  String? _cameraErrorMessage;

  // Duplicate suppression
  String? _lastScannedCode;
  DateTime? _lastScanTimestamp;
  bool _scanCooldown = false;

  // Sound effect and subtle haptic feedback settings
  bool _soundEnabled = true;
  bool _hapticEnabled = true;

  // Verification result state
  bool? _lastScanSuccess;
  String? _lastScanStatus;
  String? _lastScanMessage;
  TicketModel? _matchedTicket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _scanAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Instantiate controller safely without auto-starting
    _createScannerController();

    // Check camera permission using centralized CameraService
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final granted = await CameraService.instance.hasCameraPermission();
      if (granted) {
        _startCamera();
      } else {
        _requestCameraPermission();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_scannerController == null || !_hasCameraPermission) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerController?.stop();
    } else if (state == AppLifecycleState.resumed &&
        _cameraActive &&
        !_isCameraError) {
      _scannerController?.start();
    }
  }

  Future<void> _startCamera() async {
    if (_isStartingCamera || !mounted) return;
    _isStartingCamera = true;
    try {
      _scannerController ??= MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      if (!_hasCameraPermission && mounted) {
        setState(() {
          _hasCameraPermission = true;
          _permissionDenied = false;
        });
      }

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await _scannerController?.start();
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
          _permissionDenied = false;
          _cameraActive = true;
          _isCameraError = false;
          _cameraErrorMessage = null;
        });
        _animController.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('Error starting mobile_scanner: $e');
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
          _cameraActive = false;
          _isCameraError = true;
          _cameraErrorMessage = e.toString();
        });
        _animController.stop();
      }
    } finally {
      _isStartingCamera = false;
    }
  }

  void _createScannerController() {
    _scannerController = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  Future<void> _retryCamera() async {
    if (_isStartingCamera || !mounted) return;

    setState(() {
      _isCameraError = false;
      _cameraErrorMessage = null;
      _cameraActive = false;
    });
    _animController.stop();

    final previousController = _scannerController;
    _scannerController = null;
    await previousController?.dispose();
    if (!mounted) return;
    _createScannerController();
    await _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final granted = await CameraService.instance.checkBeforeOpeningScanner(
      context: context,
      featureTitle: widget.title,
      onGranted: () {
        if (mounted) {
          _startCamera();
        }
      },
      onDenied: () {
        if (mounted) {
          setState(() {
            _hasCameraPermission = false;
            _permissionDenied = true;
            _cameraActive = false;
          });
          _animController.stop();
          _scannerController?.stop();
        }
      },
    );

    if (granted && mounted) {
      _startCamera();
    }
  }

  Future<void> _toggleCameraFacing() async {
    try {
      await _scannerController?.switchCamera();
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error switching camera facing: $e');
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController?.toggleTorch();
      HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController?.dispose();
    _scannerController = null;
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCodeScanned(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || _scanCooldown) return;

    final now = DateTime.now();
    // Guard against duplicate reads while the same QR code remains visible in frame
    if (_lastScannedCode != null &&
        _lastScannedCode!.toUpperCase() == code.toUpperCase() &&
        _lastScanTimestamp != null &&
        now.difference(_lastScanTimestamp!).inMilliseconds < 2500) {
      return;
    }

    setState(() {
      _lastScannedCode = code;
      _lastScanTimestamp = now;
      _scanCooldown = true;
    });

    final eventService = Provider.of<EventService>(context, listen: false);
    final res = await eventService.checkInTicketWithCode(
      code,
      targetEventId: widget.targetEventId ?? 'all',
    );
    if (!mounted) return;

    final success = res['success'] as bool? ?? false;
    final status =
        res['status'] as String? ?? (success ? 'approved' : 'invalid');
    final message = res['message'] as String? ?? '';

    if (success) {
      await CheckinFeedbackService.instance.notifyCheckIn(message: message);
      // Subtle haptic feedback & sound effect trigger for verified QR pass
      if (_hapticEnabled) {
        HapticFeedback.lightImpact();
      }
      if (_soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }
    } else {
      if (_hapticEnabled) {
        HapticFeedback.selectionClick();
      }
    }

    setState(() {
      _lastScanSuccess = success;
      _lastScanStatus = status;
      _lastScanMessage = message;

      try {
        // Prefer the ticket returned by the check-in itself: the live list may lag a moment.
        _matchedTicket = (res['ticket'] as TicketModel?) ??
            eventService.userTickets.firstWhere(
              (t) =>
                  t.qrPayload.toUpperCase() == code.toUpperCase() ||
                  t.id.toUpperCase() == code.toUpperCase() ||
                  t.ticketCode.toUpperCase() == code.toUpperCase(),
            );
      } catch (_) {
        _matchedTicket = null;
      }
    });

    widget.onScan?.call(code);

    // 2.0s cooldown before next camera scan
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _scanCooldown = false);
      }
    });
  }

  void _resetResult() {
    setState(() {
      _lastScanSuccess = null;
      _lastScanStatus = null;
      _lastScanMessage = null;
      _matchedTicket = null;
    });
  }

  Widget _buildCameraErrorView(String errorMsg) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5238).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off,
                  color: Color(0xFFFF5238), size: 28),
            ),
            const SizedBox(height: 10),
            const Text(
              'Camera Feed Unavailable',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              errorMsg.toLowerCase().contains('permission')
                  ? 'Camera permission is required to stream live video.'
                  : 'Hardware camera is busy or unavailable. You can retry or verify tickets manually below.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5238),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry Camera',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _isStartingCamera ? null : _retryCamera,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF090D16).withValues(alpha: 0.7)
                  : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5238).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Color(0xFFFF5238), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Live QR detection with auto-check-in',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Flashlight / Torch Toggle Button (Synced with actual controller state)
                if (_scannerController != null)
                  ListenableBuilder(
                    listenable: _scannerController!,
                    builder: (context, child) {
                      final isOn =
                          _scannerController!.value.torchState == TorchState.on;
                      return IconButton(
                        tooltip:
                            isOn ? 'Turn Off Flashlight' : 'Turn On Flashlight',
                        icon: Icon(
                          isOn ? Icons.flash_on : Icons.flash_off,
                          size: 18,
                          color: isOn
                              ? const Color(0xFFF59E0B)
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                        onPressed: _toggleTorch,
                      );
                    },
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.flash_off,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    onPressed: null,
                  ),

                // Camera Flip Button (Synced with actual controller state)
                if (_scannerController != null)
                  ListenableBuilder(
                    listenable: _scannerController!,
                    builder: (context, child) {
                      final isFront =
                          _scannerController!.value.cameraDirection ==
                              CameraFacing.front;
                      return IconButton(
                        tooltip: isFront
                            ? 'Switch to Rear Lens'
                            : 'Switch to Front Lens',
                        icon: Icon(
                          Icons.flip_camera_ios,
                          size: 18,
                          color: isFront
                              ? const Color(0xFFFF5238)
                              : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                        ),
                        onPressed: _toggleCameraFacing,
                      );
                    },
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.flip_camera_ios,
                      size: 18,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                    onPressed: null,
                  ),

                // Sound Effect Toggle Button
                IconButton(
                  tooltip: _soundEnabled
                      ? 'Mute Sound Effect'
                      : 'Enable Sound Effect',
                  icon: Icon(
                    _soundEnabled ? Icons.volume_up : Icons.volume_off,
                    size: 18,
                    color: _soundEnabled
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                  onPressed: () {
                    setState(() {
                      _soundEnabled = !_soundEnabled;
                    });
                    if (_soundEnabled) {
                      SystemSound.play(SystemSoundType.click);
                    }
                  },
                ),

                // Subtle Haptic Feedback Toggle Button
                IconButton(
                  tooltip: _hapticEnabled
                      ? 'Disable Haptic Feedback'
                      : 'Enable Subtle Haptic Feedback',
                  icon: Icon(
                    _hapticEnabled ? Icons.vibration : Icons.mobile_off,
                    size: 18,
                    color: _hapticEnabled
                        ? const Color(0xFF10B981)
                        : (isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B)),
                  ),
                  onPressed: () {
                    setState(() {
                      _hapticEnabled = !_hapticEnabled;
                    });
                    if (_hapticEnabled) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),

                // Optional Close Button
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // 2. Viewfinder Viewport with MobileScanner live feed
          Container(
            width: double.infinity,
            height: 240,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Live MobileScanner Preview
                if (_hasCameraPermission &&
                    _scannerController != null &&
                    !_isCameraError)
                  Positioned.fill(
                    child: ClipRect(
                      child: MobileScanner(
                        controller: _scannerController!,
                        onDetect: (BarcodeCapture capture) {
                          if (_scanCooldown || !_cameraActive) return;
                          for (final barcode in capture.barcodes) {
                            final raw = barcode.rawValue;
                            if (raw != null && raw.trim().isNotEmpty) {
                              _handleCodeScanned(raw.trim());
                              break;
                            }
                          }
                        },
                        errorBuilder: (context, error) {
                          return _buildCameraErrorView(error.toString());
                        },
                        placeholderBuilder: (context) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5238),
                              strokeWidth: 2.5,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else if (_isCameraError)
                  Positioned.fill(
                    child: _buildCameraErrorView(_cameraErrorMessage ??
                        'Camera unavailable on this device'),
                  )
                else
                  // Subtle Background Camera Grid Watermark
                  Icon(
                    Icons.qr_code_2,
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),

                // Reticle Overlay (Square with 4 Corner Brackets)
                Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _lastScanSuccess == true
                            ? const Color(0xFF10B981)
                            : (_lastScanSuccess == false
                                ? Colors.redAccent
                                : const Color(0xFFFF5238)
                                    .withValues(alpha: 0.8)),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 36,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Top-Left Corner Bracket
                        Positioned(
                          top: -2,
                          left: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                                left: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                              ),
                            ),
                          ),
                        ),
                        // Top-Right Corner Bracket
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                                right: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-Left Corner Bracket
                        Positioned(
                          bottom: -2,
                          left: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                                left: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-Right Corner Bracket
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                                right: BorderSide(
                                    color: Color(0xFFFB923C), width: 3.5),
                              ),
                            ),
                          ),
                        ),

                        // Animated Scanning Laser Beam
                        if (_cameraActive && !_isCameraError)
                          AnimatedBuilder(
                            animation: _scanAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: 180 * _scanAnimation.value,
                                left: 8,
                                right: 8,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFFFB923C),
                                        Color(0xFFFF5238),
                                        Color(0xFFFB923C),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF5238)
                                            .withValues(alpha: 0.9),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Floating Guide Pill
                Positioned(
                  bottom: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: Text(
                      !_hasCameraPermission
                          ? 'Camera Permission Required'
                          : (_isCameraError
                              ? 'Camera Feed Paused'
                              : 'Point camera at attendee QR pass'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // Overlay when camera permission is not yet granted
                if (!_hasCameraPermission)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.90),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5238)
                                  .withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFFF5238)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Icon(
                              _permissionDenied
                                  ? Icons.no_photography
                                  : Icons.camera_alt,
                              color: const Color(0xFFFF5238),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _permissionDenied
                                ? 'Camera Access Blocked'
                                : 'Camera Permission Required',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _permissionDenied
                                ? 'Camera access was denied. Tap below to request permission or open system settings.'
                                : 'EventPulse needs camera permission to scan attendee QR passes at the door.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5238),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _requestCameraPermission,
                            icon: const Icon(Icons.lock_open, size: 16),
                            label: Text(
                              _permissionDenied
                                  ? 'Manage Permission'
                                  : 'Grant Camera Access',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Verification Result Card
          if (_lastScanMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_lastScanSuccess == true
                        ? const Color(0xFF10B981)
                        : (_lastScanStatus == 'wrong_event'
                            ? const Color(0xFFF59E0B)
                            : Colors.redAccent))
                    .withValues(alpha: 0.12),
                border: Border(
                  bottom: BorderSide(
                    color: _lastScanSuccess == true
                        ? const Color(0xFF10B981)
                        : (_lastScanStatus == 'wrong_event'
                            ? const Color(0xFFF59E0B)
                            : Colors.redAccent),
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastScanSuccess == true
                        ? Icons.check_circle
                        : (_lastScanStatus == 'wrong_event'
                            ? Icons.warning_amber_rounded
                            : Icons.cancel),
                    color: _lastScanSuccess == true
                        ? const Color(0xFF10B981)
                        : (_lastScanStatus == 'wrong_event'
                            ? const Color(0xFFF59E0B)
                            : Colors.redAccent),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lastScanSuccess == true
                              ? 'ENTRY APPROVED / PASS VALIDATED'
                              : (_lastScanStatus == 'wrong_event'
                                  ? 'WRONG EVENT PASS'
                                  : (_lastScanStatus == 'duplicate'
                                      ? 'DUPLICATE / ALREADY CHECKED IN'
                                      : 'CHECK-IN REJECTED')),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: _lastScanSuccess == true
                                ? const Color(0xFF10B981)
                                : (_lastScanStatus == 'wrong_event'
                                    ? const Color(0xFFF59E0B)
                                    : Colors.redAccent),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _lastScanMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (_matchedTicket != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'Attendee: ${_matchedTicket!.userName} • ${_matchedTicket!.ticketCode}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: _resetResult,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
