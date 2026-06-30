/// Decomposes complex user goals into high-level sub-targets.
class GoalDecomposer {
  
  /// Breaks down raw goals into sub-objectives.
  List<String> decompose(String goal) {
    final trimmed = goal.trim();
    if (trimmed.isEmpty) return [];

    // Simple keyword-based goal parsing
    if (trimmed.toLowerCase().contains('compute') || trimmed.toLowerCase().contains('calculator')) {
      return [
        'Open the calculator application',
        'Input formula parameters',
        'Verify final math calculation result'
      ];
    }

    // Default: treat as single sub-target
    return [trimmed];
  }
}
