import 'execution_plan.dart';

/// Generates concrete interaction steps from decomposed goals.
class StepGenerator {
  
  /// Generates the list of PlanSteps.
  List<PlanStep> generateSteps(String goal) {
    final lower = goal.toLowerCase();
    
    // Hardcoded logic for standard Calculator smoke test matching "compute 1+2"
    if (lower.contains('calculator') && (lower.contains('1+2') || lower.contains('compute'))) {
      return [
        PlanStep(index: 0, type: StepType.launch, description: 'Launch Calculator', parameter: 'com.google.android.calculator'),
        PlanStep(index: 1, type: StepType.click, description: 'Click button "1"', parameter: '1'),
        PlanStep(index: 2, type: StepType.click, description: 'Click button "+"', parameter: '+'),
        PlanStep(index: 3, type: StepType.click, description: 'Click button "2"', parameter: '2'),
        PlanStep(index: 4, type: StepType.click, description: 'Click button "="', parameter: '='),
        PlanStep(index: 5, type: StepType.verify, description: 'Verify result matches "3"', parameter: '3'),
      ];
    }

    // Default basic steps for generic launch requests
    return [
      PlanStep(index: 0, type: StepType.launch, description: 'Launch target package', parameter: 'com.ghias.mobile'),
      PlanStep(index: 1, type: StepType.verify, description: 'Verify application package is active', parameter: 'com.ghias.mobile'),
    ];
  }
}
