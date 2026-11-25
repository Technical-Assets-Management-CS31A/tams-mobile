import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
          top: 12,
          right: 12,
          child: ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isRunning ||
                  state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton.filledTonal(
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
                onPressed: _controller.toggleTorch,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
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
    final theme = Theme.of(context);
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
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Allow TAMS to use the camera to scan asset labels.'
                    : 'Close this screen and try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              if (denied) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: AppSettings.openAppSettings,
                  icon: const Icon(Icons.settings),
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

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) => Center(
    child: FractionallySizedBox(
      widthFactor: 0.65,
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    ),
  );
}
