import 'state_validator.dart';

/// Recommendation action for step failure.
class RetryRecommendation {
  final bool shouldRetry;
  final Duration backoffDuration;
  final String rationale;

  const RetryRecommendation({
    required this.shouldRetry,
    required this.backoffDuration,
    required this.rationale,
  });
}

/// Orchestrates attempt counters and retry heuristics.
class RetryManager {
  final int maxRetries;
  final Map<int, int> _stepAttempts = {};

  RetryManager({this.maxRetries = 3});

  /// Evaluates failure details to recommend next action.
  RetryRecommendation evaluateAttempts(int stepIndex, ValidationResult validation) {
    final current = _stepAttempts[stepIndex] ?? 0;
    
    if (validation.isValid) {
      return const RetryRecommendation(
        shouldRetry: false,
        backoffDuration: Duration.zero,
        rationale: 'Step succeeded.',
      );
    }

    if (current >= maxRetries) {
      return RetryRecommendation(
        shouldRetry: false,
        backoffDuration: Duration.zero,
        rationale: 'Maximum retries reached ($maxRetries attempts failed).',
      );
    }

    _stepAttempts[stepIndex] = current + 1;
    final backoff = Duration(seconds: (current + 1) * 2); // Exponential backoff

    return RetryRecommendation(
      shouldRetry: true,
      backoffDuration: backoff,
      rationale: 'Validation failed: "${validation.description}". Retrying (Attempt ${current + 1}/$maxRetries).',
    );
  }

  /// Reset counter for a step.
  void reset(int stepIndex) {
    _stepAttempts.remove(stepIndex);
  }

  /// Clear all counters.
  void clear() {
    _stepAttempts.clear();
  }
}
