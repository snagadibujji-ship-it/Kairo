import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'vision_models.dart';

/// Caches screenshot frames and their parsed vision outputs to minimize processing.
class ScreenshotCache {
  Uint8List? _lastFrame;
  String? _lastHash;
  VisionResult? _lastResult;

  /// Store a frame and its vision result.
  void cacheFrame(Uint8List frame, VisionResult result) {
    _lastFrame = frame;
    _lastResult = result;
    _lastHash = _calculateHash(frame);
  }

  /// Get the cached vision result if the image matches the cached frame.
  VisionResult? getCachedResult(Uint8List frame) {
    if (_lastResult == null || _lastHash == null) return null;
    final hash = _calculateHash(frame);
    if (hash == _lastHash) {
      return _lastResult;
    }
    return null;
  }

  /// Clear the cache.
  void clear() {
    _lastFrame = null;
    _lastResult = null;
    _lastHash = null;
  }

  String _calculateHash(Uint8List data) {
    return sha256.convert(data).toString();
  }
}
