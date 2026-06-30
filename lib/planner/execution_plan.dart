enum StepType {
  launch,
  click,
  swipe,
  verify
}

/// Represents a single action step in Kairo's execution plan.
class PlanStep {
  final int index;
  final StepType type;
  final String description;
  final String parameter; // Package name, button label, coordinates, or target text
  String status; // 'pending', 'running', 'success', 'failed'
  String? outputResult;

  PlanStep({
    required this.index,
    required this.type,
    required this.description,
    required this.parameter,
    this.status = 'pending',
    this.outputResult,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'type': type.name,
      'description': description,
      'parameter': parameter,
      'status': status,
      'outputResult': outputResult,
    };
  }
}

/// Represents the full plan formulated by Kairo to achieve a goal.
class ExecutionPlan {
  final String goal;
  final List<PlanStep> steps;
  String status; // 'pending', 'running', 'success', 'failed'

  ExecutionPlan({
    required this.goal,
    required this.steps,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'goal': goal,
      'steps': steps.map((s) => s.toMap()).toList(),
      'status': status,
    };
  }
}
