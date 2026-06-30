import 'vision_models.dart';

/// Scored item containing fused detection metrics.
class HybridMatchResult {
  final Map<String, dynamic> element;
  final double accessibilityConfidence;
  final double ocrConfidence;
  final double visualConfidence;
  final double finalConfidence;

  const HybridMatchResult({
    required this.element,
    required this.accessibilityConfidence,
    required this.ocrConfidence,
    required this.visualConfidence,
    required this.finalConfidence,
  });
}

/// Hybrid visual and structural matching engine.
class HybridElementDetector {
  
  /// Computes fused target match confidence metrics.
  HybridMatchResult matchElement({
    required ScreenState screenState,
    required String targetLabel,
  }) {
    double accConfidence = 0.0;
    double ocrConfidence = 0.0;
    double visualConfidence = 0.0;

    Map<String, dynamic>? bestNode;

    // 1. Accessibility Tree Match Heuristics
    final root = screenState.layoutTree['root'];
    if (root != null && root is Map<String, dynamic>) {
      bestNode = _searchAccessibilityNode(root, targetLabel);
      if (bestNode != null) {
        final text = (bestNode['text'] ?? '').toString().toLowerCase();
        final desc = (bestNode['contentDescription'] ?? '').toString().toLowerCase();
        final query = targetLabel.toLowerCase();
        
        if (text == query || desc == query) {
          accConfidence = 1.0;
        } else if (text.contains(query) || desc.contains(query)) {
          accConfidence = 0.75;
        } else {
          accConfidence = 0.5;
        }
      }
    }

    // 2. OCR Text Match Heuristics
    for (final textItem in screenState.visionResult.textElements) {
      final text = textItem.text.toLowerCase();
      final query = targetLabel.toLowerCase();
      
      if (text == query) {
        ocrConfidence = max(ocrConfidence, textItem.confidence);
      } else if (text.contains(query)) {
        ocrConfidence = max(ocrConfidence, textItem.confidence * 0.8);
      }
    }

    // 3. Visual Template Fallback Match Heuristics
    for (final visItem in screenState.visionResult.visualElements) {
      final label = visItem.label.toLowerCase();
      final query = targetLabel.toLowerCase();
      if (label == query) {
        visualConfidence = max(visualConfidence, visItem.confidence);
      } else if (label.contains(query)) {
        visualConfidence = max(visualConfidence, visItem.confidence * 0.7);
      }
    }

    // Fuse using weighted average
    final double finalScore = (accConfidence * 0.5) + (ocrConfidence * 0.3) + (visualConfidence * 0.2);

    // Build returned match element node representation
    final elementRepr = bestNode ?? {
      'text': targetLabel,
      'clickable': true,
    };

    return HybridMatchResult(
      element: elementRepr,
      accessibilityConfidence: accConfidence,
      ocrConfidence: ocrConfidence,
      visualConfidence: visualConfidence,
      finalConfidence: finalScore,
    );
  }

  Map<String, dynamic>? _searchAccessibilityNode(Map<String, dynamic> node, String query) {
    final String text = node['text'] ?? '';
    final String desc = node['contentDescription'] ?? '';
    if (text.toLowerCase().contains(query.toLowerCase()) || 
        desc.toLowerCase().contains(query.toLowerCase())) {
      return node;
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final found = _searchAccessibilityNode(child, query);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  double max(double a, double b) => a > b ? a : b;
}
