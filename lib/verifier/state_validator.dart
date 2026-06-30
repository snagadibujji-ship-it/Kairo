import '../vision/vision_models.dart';

/// Validation output for state checks.
class ValidationResult {
  final bool isValid;
  final double confidenceScore;
  final String description;

  const ValidationResult({
    required this.isValid,
    required this.confidenceScore,
    required this.description,
  });
}

/// Validates screen states against target templates.
class StateValidator {
  
  /// Compares actual ScreenState with expected configurations.
  ValidationResult validateState({
    required ScreenState actualState,
    String? expectedPackage,
    String? expectedText,
  }) {
    if (expectedPackage != null && actualState.packageName != expectedPackage) {
      return ValidationResult(
        isValid: false,
        confidenceScore: 0.0,
        description: 'Package mismatch. Expected: $expectedPackage, Actual: ${actualState.packageName}',
      );
    }

    if (expectedText != null) {
      // Look for text in layouts
      final foundInLayout = _findTextInLayout(actualState.layoutTree, expectedText);
      // Look for text in OCR
      final foundInOcr = actualState.visionResult.textElements.any(
        (t) => t.text.toLowerCase().contains(expectedText.toLowerCase()),
      );

      if (foundInLayout || foundInOcr) {
        final score = (foundInLayout ? 0.7 : 0.0) + (foundInOcr ? 0.3 : 0.0);
        return ValidationResult(
          isValid: true,
          confidenceScore: score,
          description: 'Text "$expectedText" verified successfully.',
        );
      } else {
        return ValidationResult(
          isValid: false,
          confidenceScore: 0.0,
          description: 'Expected text "$expectedText" was not found on screen.',
        );
      }
    }

    return const ValidationResult(
      isValid: true,
      confidenceScore: 1.0,
      description: 'State validated successfully (no constraints failed).',
    );
  }

  bool _findTextInLayout(Map<String, dynamic> layout, String text) {
    final root = layout['root'];
    if (root != null && root is Map<String, dynamic>) {
      return _searchNodeText(root, text);
    }
    return false;
  }

  bool _searchNodeText(Map<String, dynamic> node, String text) {
    final String nodeText = node['text'] ?? '';
    final String contentDesc = node['contentDescription'] ?? '';
    if (nodeText.toLowerCase().contains(text.toLowerCase()) || 
        contentDesc.toLowerCase().contains(text.toLowerCase())) {
      return true;
    }
    final children = node['children'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic> && _searchNodeText(child, text)) {
          return true;
        }
      }
    }
    return false;
  }
}
