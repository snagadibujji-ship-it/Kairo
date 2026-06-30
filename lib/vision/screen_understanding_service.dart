import 'dart:typed_data';
import '../accessibility/kairo_accessibility.dart';
import 'screen_capture_service.dart';
import 'ocr_service.dart';
import 'ui_element_detector.dart';
import 'screenshot_cache.dart';
import 'vision_models.dart';

/// Unifies UI element extraction, screenshots, and OCR to build Kairo's ScreenState.
class ScreenUnderstandingService {
  final ScreenCaptureService _captureService = ScreenCaptureService();
  final OcrService _ocrService = OcrService();
  final UiElementDetector _elementDetector = UiElementDetector();
  final ScreenshotCache _cache = ScreenshotCache();

  ScreenCaptureService get captureService => _captureService;

  /// Retrieve the current unified screen state.
  Future<ScreenState> getScreenState() async {
    // 1. Capture screen hierarchy nodes
    final Map<String, dynamic> layout = await KairoAccessibility.getScreenHierarchy();
    final String packageName = _extractPackageName(layout);

    // 2. Capture physical screen frame
    final Uint8List? frame = await _captureService.captureScreenshot();
    VisionResult visionRes;

    if (frame != null) {
      final cached = _cache.getCachedResult(frame);
      if (cached != null) {
        visionRes = cached;
      } else {
        // Run OCR text recognition on frame
        final textElements = await _ocrService.detectText(frame);
        // Parse elements from hierarchy
        final visualElements = _elementDetector.detectElementsFromLayout(layout);
        
        visionRes = VisionResult(
          textElements: textElements,
          visualElements: visualElements,
          width: 1080.0, // Default base scaling, updated dynamically in production
          height: 2400.0,
        );
        _cache.cacheFrame(frame, visionRes);
      }
    } else {
      // Vision fallback: extract visual coordinates purely from hierarchy
      final visualElements = _elementDetector.detectElementsFromLayout(layout);
      visionRes = VisionResult(
        textElements: [],
        visualElements: visualElements,
        width: 1080.0,
        height: 2400.0,
      );
    }

    return ScreenState(
      packageName: packageName,
      layoutTree: layout,
      visionResult: visionRes,
    );
  }

  String _extractPackageName(Map<String, dynamic> layout) {
    final root = layout['root'];
    if (root != null && root is Map<String, dynamic>) {
      return root['packageName'] ?? 'unknown';
    }
    return 'unknown';
  }
}
