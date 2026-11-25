import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/theme/brand.dart';

typedef ScanCameraBuilder = Widget Function(ValueChanged<String> onCode);

final scanCameraProvider = Provider<ScanCameraBuilder>(
  (ref) =>
      (onCode) => AssetQrCamera(onCode: onCode),
);

class AssetQrCamera extends StatefulWidget {
  const AssetQrCamera({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<AssetQrCamera> createState() => _AssetQrCameraState();
}

class _AssetQrCameraState extends State<AssetQrCamera> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detected(BarcodeCapture capture) {
    for (final code in capture.barcodes) {
      final value = code.rawValue;
      if (value != null) widget.onCode(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => CameraUnavailable(error: error),
        ),
        const IgnorePointer(child: _Viewfinder()),
        Positioned(
          top: 16,
          right: 16,
          child: ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isRunning ||
                  state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
                onPressed: _controller.toggleTorch,
                style: IconButton.styleFrom(
                  backgroundColor: on
                      ? Colors.white
                      : Colors.black.withValues(alpha: 0.45),
                  foregroundColor: on ? BrandColors.ink : Colors.white,
                  fixedSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  size: 20,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class CameraUnavailable extends StatelessWidget {
  const CameraUnavailable({super.key, required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                denied ? 'Camera access is off' : "The camera didn't start",
                textAlign: TextAlign.center,
                style: brandText(
                  17,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Allow TAMS to use the camera to scan asset labels.'
                    : 'Close this screen and try again.',
                textAlign: TextAlign.center,
                style: brandText(
                  14,
                  color: Colors.white70,
                ).copyWith(height: 1.4),
              ),
              if (denied) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: AppSettings.openAppSettings,
                  style: BrandButtons.primary(),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Four rounded white corner brackets marking where to hold the label.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => const Center(
    child: FractionallySizedBox(
      widthFactor: 0.62,
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(painter: _CornersPainter()),
      ),
    ),
  );
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  static const _radius = 20.0;
  static const _arm = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    const r = _radius;
    const a = _arm;

    // One L per corner, each with a rounded bend.
    final corners = Path()
      ..moveTo(0, a)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(a, 0)
      ..moveTo(w - a, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, a)
      ..moveTo(w, h - a)
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(w - a, h)
      ..moveTo(a, h)
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
      ..lineTo(0, h - a);
    canvas.drawPath(corners, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter oldDelegate) => false;
}
