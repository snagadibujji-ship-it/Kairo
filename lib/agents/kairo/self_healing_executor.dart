import 'dart:async';
import 'dart:math';
import '../../accessibility/kairo_accessibility.dart';
import '../../vision/vision_models.dart';
import '../../vision/hybrid_element_detector.dart';

/// Self-healing wrapper for Kairo gestures to achieve resilient interaction recovery.
class SelfHealingExecutor {
  final HybridElementDetector _hybridDetector = HybridElementDetector();

  /// Attempt a resilient click operation with target fallback options.
  Future<bool> resilientClick({
    required ScreenState screen,
    required String targetLabel,
    void Function(String)? logCallback,
  }) async {
    void log(String msg) {
      if (logCallback != null) logCallback(msg);
    }

    log('[Self-Healing] Attempting resilient interaction for target: "$targetLabel"');

    // 1. Compute hybrid scoring weights
    final match = _hybridDetector.matchElement(screenState: screen, targetLabel: targetLabel);
    log('[Self-Healing] Match scores -> Acc: ${(match.accessibilityConfidence * 100).toStringAsFixed(0)}% | OCR: ${(match.ocrConfidence * 100).toStringAsFixed(0)}% | Visual: ${(match.visualConfidence * 100).toStringAsFixed(0)}%');

    // Strategy A: Try clicking via exact Accessibility Node
    if (match.accessibilityConfidence > 0.5) {
      log('[Self-Healing] Strategy A: Clicking Accessibility Node target...');
      final center = KairoAccessibility.getNodeCenter(match.element);
      if (center != null) {
        final success = await KairoAccessibility.click(center.x, center.y);
        if (success) return true;
      }
    }

    // Strategy B: Fallback to clicking via OCR detected coordinates
    log('[Self-Healing] Strategy B: Accessibility click failed/missing. Trying OCR coordinates...');
    for (final textItem in screen.visionResult.textElements) {
      if (textItem.text.toLowerCase().contains(targetLabel.toLowerCase())) {
        final center = textItem.bounds;
        log('[Self-Healing] Clicking OCR text frame center at (${center.centerX}, ${center.centerY})...');
        final success = await KairoAccessibility.click(center.centerX, center.centerY);
        if (success) return true;
      }
    }

    // Strategy C: Fallback to clicking the nearest clickable UI node element
    log('[Self-Healing] Strategy C: Structural match failed. Searching for nearby sibling items...');
    final clickables = screen.findClickable();
    if (clickables.isNotEmpty) {
      // Find the nearest clickable element coordinate (defaulting to the first sibling element index)
      final fallbackTarget = clickables.first;
      final center = KairoAccessibility.getNodeCenter(fallbackTarget);
      if (center != null) {
        log('[Self-Healing] Clicking fallback sibling node element at (${center.x}, ${center.y})...');
        final success = await KairoAccessibility.click(center.x, center.y);
        if (success) return true;
      }
    }

    log('[Self-Healing] ERROR: All interaction strategies failed for "$targetLabel".');
    return false;
  }
}
