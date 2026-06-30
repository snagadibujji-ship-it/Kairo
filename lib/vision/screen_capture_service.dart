import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Service responsible for managing MediaProjection screen capture.
class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.ghias.mobile/screen_capture');
  
  StreamController<Uint8List>? _frameController;
  Timer? _captureTimer;

  /// Request permission and start MediaProjection screen capture.
  Future<bool> requestCapturePermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('requestCapturePermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[ScreenCaptureService] requestCapturePermission error: $e');
      return false;
    }
  }

  /// Capture a single screenshot frame.
  Future<Uint8List?> captureScreenshot() async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>('captureScreenshot');
      return bytes;
    } on PlatformException catch (e) {
      print('[ScreenCaptureService] captureScreenshot error: $e');
      return null;
    }
  }

  /// Start continuous frame capture at the specified interval.
  Stream<Uint8List> startContinuousCapture({Duration interval = const Duration(seconds: 1)}) {
    _captureTimer?.cancel();
    _frameController?.close();
    _frameController = StreamController<Uint8List>.broadcast();

    _captureTimer = Timer.periodic(interval, (timer) async {
      final frame = await captureScreenshot();
      if (frame != null && _frameController != null && !_frameController!.isClosed) {
        _frameController!.add(frame);
      }
    });

    return _frameController!.stream;
  }

  /// Stop continuous frame capture.
  Future<void> stopContinuousCapture() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    await _frameController?.close();
    _frameController = null;
  }
}
