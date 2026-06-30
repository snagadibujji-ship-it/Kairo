import 'goal_decomposer.dart';
import 'step_generator.dart';
import 'execution_plan.dart';

/// Central coordinator for GHIAS Kairo planning pipeline.
class TaskPlanner {
  final GoalDecomposer _decomposer = GoalDecomposer();
  final StepGenerator _generator = StepGenerator();

  /// Converts a high-level user goal into a complete execution plan.
  Future<ExecutionPlan> formulatePlan(String goal) async {
    // 1. Decompose the user goal into sub-targets
    final subtargets = _decomposer.decompose(goal);
    
    // 2. Generate detailed programmatic execution steps
    final steps = _generator.generateSteps(goal);

    return ExecutionPlan(
      goal: goal,
      steps: steps,
      status: 'pending',
    );
  }
}
