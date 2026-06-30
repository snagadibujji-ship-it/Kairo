import 'vision_models.dart';

/// Detects interactive UI elements from screen metadata and vision maps.
class UiElementDetector {
  
  /// Extracts elements from an Android Accessibility node hierarchy tree.
  List<DetectedElement> detectElementsFromLayout(Map<String, dynamic> layoutTree) {
    final List<DetectedElement> elements = [];
    final root = layoutTree['root'];
    if (root != null && root is Map<String, dynamic>) {
      _extractNodesRecursively(root, elements);
    }
    return elements;
  }

  void _extractNodesRecursively(Map<String, dynamic> node, List<DetectedElement> elements) {
    final bool clickable = node['clickable'] ?? false;
    final bool scrollable = node['scrollable'] ?? false;
    final String className = node['className'] ?? '';
    final String text = node['text'] ?? '';
    final String contentDesc = node['contentDescription'] ?? '';
    final Map<String, dynamic>? bounds = node['bounds'];

    if (bounds != null && (clickable || scrollable || className.contains('Button') || className.contains('EditText'))) {
      String type = 'view';
      if (className.contains('Button')) {
        type = 'button';
      } else if (className.contains('EditText') || className.contains('TextField')) {
        type = 'input';
      } else if (scrollable) {
        type = 'scrollable';
      } else if (clickable) {
        type = 'clickable';
      }

      final label = text.isNotEmpty ? text : contentDesc;
      elements.add(
        DetectedElement(
          elementType: type,
          label: label,
          confidence: 1.0,
          bounds: BoundingBox(
            left: (bounds['left'] ?? 0.0).toDouble(),
            top: (bounds['top'] ?? 0.0).toDouble(),
            right: (bounds['right'] ?? 0.0).toDouble(),
            bottom: (bounds['bottom'] ?? 0.0).toDouble(),
          ),
        ),
      );
    }

    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _extractNodesRecursively(child, elements);
        }
      }
    }
  }
}
