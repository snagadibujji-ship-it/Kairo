import '../vision/vision_models.dart';

enum FailureType {
  nodeNotFound,
  appCrash,
  screenTimeout,
  permissionBlock,
  unknown
}

/// Details of classified action failures.
class ClassifiedFailure {
  final FailureType type;
  final String description;

  const ClassifiedFailure({
    required this.type,
    required this.description,
  });
}

/// Identifies failure classification types.
class FailureClassifier {
  
  /// Classifies failures depending on target states and exceptions.
  ClassifiedFailure classify({
    required ScreenState beforeState,
    required ScreenState afterState,
    String? targetElement,
    Exception? exception,
  }) {
    if (exception != null) {
      final message = exception.toString().toLowerCase();
      if (message.contains('timeout')) {
        return const ClassifiedFailure(
          type: FailureType.screenTimeout,
          description: 'Timeout elapsed during execution.',
        );
      }
      if (message.contains('permission') || message.contains('denied')) {
        return const ClassifiedFailure(
          type: FailureType.permissionBlock,
          description: 'Android OS permissions blocked this action.',
        );
      }
    }

    // Check if expected package crashed/exited
    if (afterState.packageName == 'com.android.launcher' || afterState.packageName.contains('launcher')) {
      if (beforeState.packageName != 'unknown' && !afterState.packageName.contains(beforeState.packageName)) {
        return const ClassifiedFailure(
          type: FailureType.appCrash,
          description: 'Application terminated abnormally or returned to launcher.',
        );
      }
    }

    // Check if node is missing
    if (targetElement != null) {
      return ClassifiedFailure(
        type: FailureType.nodeNotFound,
        description: 'Failed to locate target element "$targetElement" in layout bounds or OCR maps.',
      );
    }

    return const ClassifiedFailure(
      type: FailureType.unknown,
      description: 'An unresolved execution error occurred.',
    );
  }
}
