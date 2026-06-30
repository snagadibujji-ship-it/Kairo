import 'dart:convert';

/// Represents a detected text element from OCR.
class DetectedText {
  final String text;
  final double confidence;
  final BoundingBox bounds;

  const DetectedText({
    required this.text,
    required this.confidence,
    required this.bounds,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'confidence': confidence,
      'bounds': bounds.toMap(),
    };
  }

  factory DetectedText.fromMap(Map<String, dynamic> map) {
    return DetectedText(
      text: map['text'] ?? '',
      confidence: (map['confidence'] ?? 0.0).toDouble(),
      bounds: BoundingBox.fromMap(map['bounds'] ?? {}),
    );
  }
}

/// Represents a detected visual element (buttons, inputs, icons).
class DetectedElement {
  final String elementType;
  final String label;
  final BoundingBox bounds;
  final double confidence;

  const DetectedElement({
    required this.elementType,
    required this.label,
    required this.bounds,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'elementType': elementType,
      'label': label,
      'bounds': bounds.toMap(),
      'confidence': confidence,
    };
  }

  factory DetectedElement.fromMap(Map<String, dynamic> map) {
    return DetectedElement(
      elementType: map['elementType'] ?? 'unknown',
      label: map['label'] ?? '',
      bounds: BoundingBox.fromMap(map['bounds'] ?? {}),
      confidence: (map['confidence'] ?? 0.0).toDouble(),
    );
  }
}

/// Represents a bounding box in absolute screen pixels.
class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
  double get centerX => left + width / 2.0;
  double get centerY => top + height / 2.0;

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
    };
  }

  factory BoundingBox.fromMap(Map<String, dynamic> map) {
    return BoundingBox(
      left: (map['left'] ?? 0.0).toDouble(),
      top: (map['top'] ?? 0.0).toDouble(),
      right: (map['right'] ?? 0.0).toDouble(),
      bottom: (map['bottom'] ?? 0.0).toDouble(),
    );
  }
}

/// Aggregated result of a single vision analysis frame.
class VisionResult {
  final List<DetectedText> textElements;
  final List<DetectedElement> visualElements;
  final double width;
  final double height;

  const VisionResult({
    required this.textElements,
    required this.visualElements,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() {
    return {
      'textElements': textElements.map((e) => e.toMap()).toList(),
      'visualElements': visualElements.map((e) => e.toMap()).toList(),
      'width': width,
      'height': height,
    };
  }

  factory VisionResult.fromMap(Map<String, dynamic> map) {
    return VisionResult(
      textElements: (map['textElements'] as List? ?? [])
          .map((e) => DetectedText.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      visualElements: (map['visualElements'] as List? ?? [])
          .map((e) => DetectedElement.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      width: (map['width'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
    );
  }
}

/// Represents Kairo's understanding of the current screen.
class ScreenState {
  final String packageName;
  final Map<String, dynamic> layoutTree;
  final VisionResult visionResult;
  final DateTime timestamp;

  ScreenState({
    required this.packageName,
    required this.layoutTree,
    required this.visionResult,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'layoutTree': layoutTree,
      'visionResult': visionResult.toMap(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Find element containing text in layout or OCR
  Map<String, dynamic>? findByText(String text) {
    final root = layoutTree['root'];
    if (root != null && root is Map<String, dynamic>) {
      final found = _searchNodeText(root, text);
      if (found != null) return found;
    }
    for (final element in visionResult.textElements) {
      if (element.text.toLowerCase().contains(text.toLowerCase())) {
        return {
          'text': element.text,
          'bounds': element.bounds.toMap(),
          'clickable': true,
        };
      }
    }
    return null;
  }

  /// Collect all clickable regions from layout and vision elements
  List<Map<String, dynamic>> findClickable() {
    final List<Map<String, dynamic>> clickables = [];
    final root = layoutTree['root'];
    if (root != null && root is Map<String, dynamic>) {
      _collectClickables(root, clickables);
    }
    for (final element in visionResult.visualElements) {
      if (element.elementType == 'button' || element.elementType == 'clickable') {
        clickables.add({
          'text': element.label,
          'bounds': element.bounds.toMap(),
          'clickable': true,
        });
      }
    }
    return clickables;
  }

  /// Find editable input fields
  List<Map<String, dynamic>> findInputField() {
    final List<Map<String, dynamic>> inputs = [];
    final root = layoutTree['root'];
    if (root != null && root is Map<String, dynamic>) {
      _collectInputs(root, inputs);
    }
    return inputs;
  }

  /// Finds the best matching element for a target query
  Map<String, dynamic>? findBestMatch(String query) {
    final node = findByText(query);
    if (node != null) return node;

    final clickables = findClickable();
    for (final element in clickables) {
      final label = (element['text'] ?? '').toString().toLowerCase();
      if (label.contains(query.toLowerCase())) {
        return element;
      }
    }
    return null;
  }

  Map<String, dynamic>? _searchNodeText(Map<String, dynamic> node, String text) {
    final String nodeText = node['text'] ?? '';
    final String contentDesc = node['contentDescription'] ?? '';
    if (nodeText.toLowerCase().contains(text.toLowerCase()) || 
        contentDesc.toLowerCase().contains(text.toLowerCase())) {
      return node;
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final found = _searchNodeText(child, text);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  void _collectClickables(Map<String, dynamic> node, List<Map<String, dynamic>> list) {
    if (node['clickable'] == true && node['bounds'] != null) {
      list.add(node);
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _collectClickables(child, list);
        }
      }
    }
  }

  void _collectInputs(Map<String, dynamic> node, List<Map<String, dynamic>> list) {
    final String className = node['className'] ?? '';
    if ((className.contains('EditText') || className.contains('TextField')) && node['bounds'] != null) {
      list.add(node);
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _collectInputs(child, list);
        }
      }
    }
  }
}
