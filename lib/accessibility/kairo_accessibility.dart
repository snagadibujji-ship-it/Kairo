import 'dart:convert';
import 'package:flutter/services.dart';

/// Dart bridge for Kairo's Android Accessibility Service integration.
/// Provides screen element inspection and gesture dispatch capabilities.
class KairoAccessibility {
  static const MethodChannel _channel = MethodChannel('com.ghias.mobile/accessibility');

  /// Check if Kairo's Accessibility Service is currently active in Android settings.
  static Future<bool> isServiceEnabled() async {
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isServiceEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      print('[KairoAccessibility] isServiceEnabled failed: $e');
      return false;
    }
  }

  /// Perform a tap gesture at coordinate ([x], [y]) in screen coordinates.
  static Future<bool> click(double x, double y) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('click', {
        'x': x,
        'y': y,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print('[KairoAccessibility] click failed: $e');
      return false;
    }
  }

  /// Perform a swipe gesture from ([startX], [startY]) to ([endX], [endY]) lasting [duration] milliseconds.
  static Future<bool> swipe(
    double startX,
    double startY,
    double endX,
    double endY, {
    int duration = 300,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('swipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'duration': duration,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print('[KairoAccessibility] swipe failed: $e');
      return false;
    }
  }

  /// Launch an external app by its [packageName].
  static Future<bool> launchApp(String packageName) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('launchApp', {
        'packageName': packageName,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      print('[KairoAccessibility] launchApp failed: $e');
      return false;
    }
  }

  /// Fetch the current active screen hierarchy dumped as a raw JSON string.
  static Future<String> getRawScreenHierarchy() async {
    try {
      final String? hierarchy = await _channel.invokeMethod<String>('getScreenHierarchy');
      return hierarchy ?? '{}';
    } on PlatformException catch (e) {
      print('[KairoAccessibility] getScreenHierarchy failed: $e');
      return '{}';
    }
  }

  /// Fetch and parse the screen hierarchy into a Map.
  static Future<Map<String, dynamic>> getScreenHierarchy() async {
    final raw = await getRawScreenHierarchy();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    } catch (e) {
      print('[KairoAccessibility] jsonDecode failed: $e');
      return {};
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Node Traversal & Element Selection Helpers
  // ──────────────────────────────────────────────────────────────────────────

  /// Recursively traverse the node tree to find the first node matching [text] exactly or partially.
  static Map<String, dynamic>? findNodeByText(Map<String, dynamic> node, String text, {bool exact = false}) {
    final String nodeText = node['text'] ?? '';
    final String contentDesc = node['contentDescription'] ?? '';

    final matchesText = exact 
        ? (nodeText == text || contentDesc == text)
        : (nodeText.toLowerCase().contains(text.toLowerCase()) || contentDesc.toLowerCase().contains(text.toLowerCase()));

    if (matchesText) {
      return node;
    }

    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final found = findNodeByText(child, text, exact: exact);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  /// Recursively traverse the node tree to find a node by Android resource ID name ([viewId]).
  static Map<String, dynamic>? findNodeByViewId(Map<String, dynamic> node, String viewId) {
    final String currentId = node['viewId'] ?? '';
    if (currentId == viewId || currentId.endsWith('/$viewId')) {
      return node;
    }

    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          final found = findNodeByViewId(child, viewId);
          if (found != null) return found;
        }
      }
    }
    return null;
  }

  /// Recursively collect all clickable nodes present on the active screen.
  static List<Map<String, dynamic>> getClickableNodes(Map<String, dynamic> node) {
    final List<Map<String, dynamic>> results = [];
    if (node['clickable'] == true && node['bounds'] != null) {
      results.add(node);
    }

    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          results.addAll(getClickableNodes(child));
        }
      }
    }
    return results;
  }

  /// Extract the center screen coordinates `(x, y)` for a given node's bounds.
  static Point? getNodeCenter(Map<String, dynamic> node) {
    final bounds = node['bounds'];
    if (bounds == null) return null;

    final int left = bounds['left'] ?? 0;
    final int top = bounds['top'] ?? 0;
    final int right = bounds['right'] ?? 0;
    final int bottom = bounds['bottom'] ?? 0;

    final double centerX = left + (right - left) / 2.0;
    final double centerY = top + (bottom - top) / 2.0;

    return Point(centerX, centerY);
  }
}

/// Simple coordinate helper class.
class Point {
  final double x;
  final double y;
  const Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';
}
