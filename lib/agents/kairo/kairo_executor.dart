import 'dart:async';
import 'dart:typed_data';
import 'package:get/get.dart';
import '../../accessibility/kairo_accessibility.dart';
import '../../vision/screen_understanding_service.dart';
import '../../vision/vision_models.dart';
import '../../vision/screenshot_timeline.dart';
import '../../vision/hybrid_element_detector.dart';
import '../../verifier/action_verifier.dart';
import '../../verifier/state_validator.dart';
import '../../verifier/failure_classifier.dart';
import '../../planner/execution_plan.dart';
import 'action_recorder.dart';
import 'visual_debug_overlay.dart';
import 'self_healing_executor.dart';

/// Resilient execution engine coordinating gestures, self-healing fallbacks, timeline captures, and action logging.
class KairoExecutor {
  final ScreenUnderstandingService _eyes = ScreenUnderstandingService();
  final ActionVerifier _verifier = ActionVerifier();
  final ScreenshotTimeline _timeline = ScreenshotTimeline();
  final ActionRecorder _recorder = Get.put(ActionRecorder());
  final VisualDebugOverlayController _overlay = Get.put(VisualDebugOverlayController());
  final SelfHealingExecutor _selfHealer = SelfHealingExecutor();
  final HybridElementDetector _hybridDetector = HybridElementDetector();

  /// Execute a plan step, automatically managing timeline screenshots, debug overlays, and self-healing.
  Future<StepVerification> executeStep(PlanStep step, ScreenState beforeState, String goal) async {
    // 1. Calculate element count & confidence score prior to action
    final match = _hybridDetector.matchElement(screenState: beforeState, targetLabel: step.parameter);
    final elementCount = beforeState.visionResult.visualElements.length + beforeState.visionResult.textElements.length;

    // 2. Render initial execution details to Debug Overlay Panel
    _overlay.updateState(
      goal: goal,
      step: 'Step ${step.index + 1}: ${step.description}',
      action: 'Executing ${step.type.name} on "${step.parameter}"...',
      score: match.finalConfidence,
      elementCount: elementCount,
    );
    _overlay.show();

    final Uint8List? beforeFrame = await ScreenUnderstandingService().captureService.captureScreenshot();
    if (beforeFrame != null) {
      await _timeline.saveStepFrame(beforeFrame, step.index, isBefore: true);
    }

    bool actionSuccess = false;

    // 4. Perform step action with self-healing triggers
    switch (step.type) {
      case StepType.launch:
        actionSuccess = await KairoAccessibility.launchApp(step.parameter);
        break;
      case StepType.click:
        // Attempt self-healing resilient click (A: Acc node -> B: OCR coordinates -> C: sibling fallback)
        actionSuccess = await _selfHealer.resilientClick(
          screen: beforeState,
          targetLabel: step.parameter,
          logCallback: (msg) => print('[KairoExecutor] $msg'),
        );
        break;
      case StepType.swipe:
        if (step.parameter == 'up') {
          actionSuccess = await KairoAccessibility.swipe(540.0, 400.0, 540.0, 1600.0);
        } else {
          actionSuccess = await KairoAccessibility.swipe(540.0, 1600.0, 540.0, 400.0);
        }
        break;
      case StepType.verify:
        actionSuccess = true;
        break;
    }

    if (!actionSuccess && step.type != StepType.verify) {
      final failResult = StepVerification(
        success: false,
        confidenceScore: 0.0,
        expectedState: 'Execute ${step.type.name} on "${step.parameter}"',
        observedState: 'Action dispatch failed.',
        failureCause: 'Accessibility JNI dispatch returned false.',
        repairRecommendation: 'Ensure accessibility service is enabled and target is clickable.',
      );
      
      _recorder.record(
        action: step.description,
        screenStatePackage: beforeState.packageName,
        result: 'FAIL: Dispatch error',
        confidence: 0.0,
      );
      
      return failResult;
    }

    // Wait for frame settles
    await Future.delayed(const Duration(milliseconds: 800));

    // 5. Save "after" timeline screenshot frame
    final Uint8List? afterFrame = await ScreenUnderstandingService().captureService.captureScreenshot();
    if (afterFrame != null) {
      await _timeline.saveStepFrame(afterFrame, step.index, isBefore: false);
    }

    // 6. Observe resulting state & verify outcome
    final afterState = await _eyes.getScreenState();
    final verification = verifyResult(step, beforeState, afterState);

    // 7. Log outcome parameters to Action Recorder
    _recorder.record(
      action: step.description,
      screenStatePackage: afterState.packageName,
      result: verification.success ? 'SUCCESS' : 'FAIL: ${verification.failureCause}',
      confidence: verification.confidenceScore,
    );

    // 8. Refresh Debug Overlay details
    _overlay.updateState(
      goal: goal,
      step: 'Step ${step.index + 1}: ${step.description}',
      action: verification.success ? 'SUCCESS' : 'FAILED: ${verification.failureCause}',
      score: verification.confidenceScore,
      elementCount: elementCount,
    );

    return verification;
  }

  /// Verifies step results after execution.
  StepVerification verifyResult(PlanStep step, ScreenState beforeState, ScreenState afterState) {
    switch (step.type) {
      case StepType.launch:
        return _verifier.verifyLaunch(
          beforeState: beforeState,
          afterState: afterState,
          targetPackage: step.parameter,
        );
      case StepType.click:
        return _verifier.verifyClick(
          beforeState: beforeState,
          afterState: afterState,
          elementLabel: step.parameter,
        );
      case StepType.swipe:
        return _verifier.verifySwipe(
          beforeState: beforeState,
          afterState: afterState,
        );
      case StepType.verify:
        final validationResult = StateValidator().validateState(
          actualState: afterState,
          expectedText: step.parameter,
        );
        return StepVerification(
          success: validationResult.isValid,
          confidenceScore: validationResult.confidenceScore,
          expectedState: 'Verify element containing: "${step.parameter}"',
          observedState: validationResult.description,
          failureCause: validationResult.isValid ? null : 'Expected state condition mismatch.',
          repairRecommendation: validationResult.isValid ? null : 'Check layout tree or OCR snapshot.',
        );
    }
  }
}
