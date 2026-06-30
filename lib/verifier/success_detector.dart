import '../vision/vision_models.dart';
import 'state_validator.dart';

/// Detects if overall task goals are achieved.
class SuccessDetector {
  final StateValidator _validator = StateValidator();

  /// Determine if the final screen state indicates success.
  ValidationResult evaluateSuccess(ScreenState finalState, String goal) {
    final lowerGoal = goal.toLowerCase();
    
    // Logic for Calculator smoke test verification
    if (lowerGoal.contains('calculator') && (lowerGoal.contains('1+2') || lowerGoal.contains('compute'))) {
      final validation = _validator.validateState(
        actualState: finalState,
        expectedText: '3',
      );
      if (validation.isValid) {
        return const ValidationResult(
          isValid: true,
          confidenceScore: 0.95,
          description: 'Verified output digit "3" on screen.',
        );
      }
    }

    // Generic fallback validation: check if goal words appear in the OCR or layout
    final keywords = lowerGoal.split(' ').where((w) => w.length > 3).toList();
    int matches = 0;

    for (final word in keywords) {
      final validation = _validator.validateState(actualState: finalState, expectedText: word);
      if (validation.isValid) {
        matches++;
      }
    }

    if (keywords.isNotEmpty && matches / keywords.length >= 0.5) {
      final score = matches / keywords.length;
      return ValidationResult(
        isValid: true,
        confidenceScore: score,
        description: 'Verified screen contents match goal keywords ($matches/${keywords.length} matches).',
      );
    }

    return ValidationResult(
      isValid: false,
      confidenceScore: 0.0,
      description: 'Could not verify final state matches goal: "$goal".',
    );
  }
}
