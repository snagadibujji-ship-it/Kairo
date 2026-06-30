import 'dart:async';
import 'package:get/get.dart';
import 'kairo_executor.dart';
import 'action_recorder.dart';
import '../../vision/screen_understanding_service.dart';
import '../../vision/vision_models.dart';
import '../../verifier/action_verifier.dart';
import '../../verifier/success_detector.dart';
import '../../verifier/retry_manager.dart';
import '../../verifier/state_validator.dart';
import '../../planner/task_planner.dart';
import '../../planner/execution_plan.dart';

/// Central runtime engine for Kairo agent loops (Goal -> Plan -> Act -> Verify).
class KairoRuntime {
  final TaskPlanner _planner = TaskPlanner();
  final ScreenUnderstandingService _eyes = ScreenUnderstandingService();
  final KairoExecutor _executor = KairoExecutor();
  final SuccessDetector _successDetector = SuccessDetector();
  final RetryManager _retryManager = RetryManager(maxRetries: 3);
  final ActionRecorder _recorder = Get.put(ActionRecorder());

  /// Executes a high-level goal from start to finish.
  Future<ExecutionPlan> executeGoal(String goal, {void Function(String)? logCallback}) async {
    void log(String message) {
      if (logCallback != null) logCallback(message);
    }

    log('Kairo Runtime: Initiating task for goal: "$goal"');

    // 1. Plan the execution steps
    final plan = await _planner.formulatePlan(goal);
    plan.status = 'running';
    log('Planner: Formulated plan with ${plan.steps.length} steps.');

    // 2. Loop through and execute each step
    for (final step in plan.steps) {
      step.status = 'running';
      log('Executor: Executing Step ${step.index + 1}: ${step.description}');

      bool stepPassed = false;
      _retryManager.reset(step.index);

      while (!stepPassed) {
        // Capture screen state before action
        final beforeState = await _eyes.getScreenState();

        try {
          // Delegate step execution to KairoExecutor
          final verification = await _executor.executeStep(step, beforeState, goal);

          if (verification.success) {
            log('Verifier: Step ${step.index + 1} succeeded. Confidence: ${verification.confidenceScore}');
            step.status = 'success';
            stepPassed = true;
          } else {
            final validationResult = ValidationResult(
              isValid: false,
              confidenceScore: 0.0,
              description: verification.failureCause ?? 'Action verification failed.',
            );
            final retryRec = _retryManager.evaluateAttempts(step.index, validationResult);
            if (retryRec.shouldRetry) {
              log('Verifier: ${retryRec.rationale}. Backing off for ${retryRec.backoffDuration.inSeconds}s...');
              await Future.delayed(retryRec.backoffDuration);
            } else {
              log('Verifier: Step failed permanently. ${retryRec.rationale}');
              step.status = 'failed';
              plan.status = 'failed';
              await _recorder.saveSession(goal);
              return plan;
            }
          }
        } catch (e) {
          log('Executor: Exception occurred during execution: $e');
          step.status = 'failed';
          plan.status = 'failed';
          await _recorder.saveSession(goal);
          return plan;
        }
      }
    }

    // 3. Final goal verification check
    log('SuccessDetector: Performing final goal validation...');
    final finalState = await _eyes.getScreenState();
    final goalValidation = _successDetector.evaluateSuccess(finalState, goal);

    if (goalValidation.isValid) {
      log('SuccessDetector: Goal achieved! Confidence: ${goalValidation.confidenceScore}');
      plan.status = 'success';
    } else {
      log('SuccessDetector: Goal failed. ${goalValidation.description}');
      plan.status = 'failed';
    }

    // Persist session trajectory
    await _recorder.saveSession(goal);
    return plan;
  }
}
