import '../vision/vision_models.dart';
import 'state_validator.dart';
import 'failure_classifier.dart';

/// Verification details returned after step execution.
class StepVerification {
  final bool success;
  final ClassifiedFailure? failure;
  final double confidenceScore;
  final String expectedState;
  final String observedState;
  final String? failureCause;
  final String? repairRecommendation;
  final String? retryRecommendation;

  const StepVerification({
    required this.success,
    this.failure,
    required this.confidenceScore,
    required this.expectedState,
    required this.observedState,
    this.failureCause,
    this.repairRecommendation,
    this.retryRecommendation,
  });
}

/// Verifies individual action executions (clicks, swipes, launches).
class ActionVerifier {
  final StateValidator _validator = StateValidator();
  final FailureClassifier _classifier = FailureClassifier();

  /// Verify if an app launch succeeded.
  StepVerification verifyLaunch({
    required ScreenState beforeState,
    required ScreenState afterState,
    required String targetPackage,
  }) {
    final validation = _validator.validateState(
      actualState: afterState,
      expectedPackage: targetPackage,
    );

    if (validation.isValid) {
      return StepVerification(
        success: true,
        confidenceScore: validation.confidenceScore,
        expectedState: 'Active package: $targetPackage',
        observedState: 'Active package: ${afterState.packageName}',
      );
    }

    final failure = _classifier.classify(
      beforeState: beforeState,
      afterState: afterState,
      targetElement: targetPackage,
    );

    return StepVerification(
      success: false,
      failure: failure,
      confidenceScore: 0.0,
      expectedState: 'Active package: $targetPackage',
      observedState: 'Active package: ${afterState.packageName}',
      failureCause: failure.description,
      repairRecommendation: 'Verify the application "$targetPackage" is installed on the device.',
      retryRecommendation: 'Relaunch target package after a brief delay.',
    );
  }

  /// Verify if a click tap registered successfully.
  StepVerification verifyClick({
    required ScreenState beforeState,
    required ScreenState afterState,
    required String elementLabel,
  }) {
    final validation = _validator.validateState(
      actualState: afterState,
      expectedText: elementLabel,
    );

    if (afterState.packageName != beforeState.packageName) {
      return StepVerification(
        success: true,
        confidenceScore: 0.9,
        expectedState: 'Screen transition triggered by clicking "$elementLabel"',
        observedState: 'Package transitioned from ${beforeState.packageName} to ${afterState.packageName}',
      );
    }

    return StepVerification(
      success: true,
      confidenceScore: validation.isValid ? 0.8 : 0.5,
      expectedState: 'Clicked element: "$elementLabel"',
      observedState: 'Screen layout loaded.',
      repairRecommendation: validation.isValid ? null : 'Element "$elementLabel" still visible. Check if gesture hit target.',
      retryRecommendation: validation.isValid ? null : 'Re-verify coordinates and click again.',
    );
  }

  /// Verify if a swipe scroll registered successfully.
  StepVerification verifySwipe({
    required ScreenState beforeState,
    required ScreenState afterState,
  }) {
    final beforeNodes = beforeState.layoutTree.toString();
    final afterNodes = afterState.layoutTree.toString();

    if (beforeNodes != afterNodes) {
      return StepVerification(
        success: true,
        confidenceScore: 0.95,
        expectedState: 'Screen hierarchy content shift',
        observedState: 'Layout changed (scroll registered)',
      );
    }

    return StepVerification(
      success: false,
      failure: const ClassifiedFailure(
        type: FailureType.unknown,
        description: 'Screen hierarchy did not change after swipe.',
      ),
      confidenceScore: 0.0,
      expectedState: 'Screen hierarchy content shift',
      observedState: 'No layout changes (scroll ignored)',
      failureCause: 'Scroll limit bounds reached or gesture coordinates invalid.',
      repairRecommendation: 'Attempt swipe gesture in a different screen region or check swipe distance.',
      retryRecommendation: 'Retry swipe with altered duration or path.',
    );
  }
}
