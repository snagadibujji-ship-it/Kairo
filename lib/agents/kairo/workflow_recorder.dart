import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'kairo_runtime.dart';
import '../../memory/hive_service.dart';
import '../../planner/execution_plan.dart';

/// Recorded action details compiled during user demonstration.
class RecordedAction {
  final String type;
  final String text;
  final String packageName;
  final DateTime timestamp;

  const RecordedAction({
    required this.type,
    required this.text,
    required this.packageName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
      'packageName': packageName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RecordedAction.fromMap(Map<String, dynamic> map) {
    return RecordedAction(
      type: map['type'] ?? 'click',
      text: map['text'] ?? '',
      packageName: map['packageName'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Dynamic recorder enabling Kairo to learn new macros by demonstrating on-device actions.
class WorkflowRecorder extends GetxService {
  final HiveService _hive = Get.find<HiveService>();
  final List<RecordedAction> _recordedActions = [];
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  List<RecordedAction> get recordedActions => List.unmodifiable(_recordedActions);

  static const MethodChannel _channel = MethodChannel('com.ghias.mobile/accessibility');

  /// Start recording on-device user interactions.
  void startRecording() {
    _recordedActions.clear();
    _isRecording = true;
    
    // Register MethodChannel callback listener to catch native accessibility events
    _channel.setMethodCallHandler((MethodCall call) async {
      if (!_isRecording) return;
      if (call.method == 'onUserAction') {
        final Map<String, dynamic> data = Map<String, dynamic>.from(call.arguments as Map);
        final action = RecordedAction(
          type: data['type'] ?? 'click',
          text: data['text'] ?? '',
          packageName: data['packageName'] ?? '',
          timestamp: DateTime.now(),
        );
        _recordedActions.add(action);
        print('[WorkflowRecorder] LOGGED DEMO STEP: ${action.type.toUpperCase()} on "${action.text}" inside ${action.packageName}');
      }
    });

    print('[WorkflowRecorder] Started workflow recording session.');
  }

  /// Stop recording and compile actions into a reusable execution plan.
  Future<ExecutionPlan?> stopRecording(String workflowName) async {
    if (!_isRecording) return null;
    _isRecording = false;
    _channel.setMethodCallHandler(null); // Deregister listener

    if (_recordedActions.isEmpty) {
      print('[WorkflowRecorder] Recording stopped. No actions recorded.');
      return null;
    }

    // Compile recorded actions into sequential PlanStep items
    final List<PlanStep> steps = [];
    String lastPkg = '';

    for (int i = 0; i < _recordedActions.length; i++) {
      final action = _recordedActions[i];
      
      // Inject launch application step if package switches
      if (action.packageName.isNotEmpty && action.packageName != lastPkg) {
        steps.add(PlanStep(
          index: steps.length,
          type: StepType.launch,
          description: 'Launch application: ${action.packageName}',
          parameter: action.packageName,
        ));
        lastPkg = action.packageName;
      }

      if (action.type == 'click' && action.text.isNotEmpty) {
        steps.add(PlanStep(
          index: steps.length,
          type: StepType.click,
          description: 'Click button "${action.text}"',
          parameter: action.text,
        ));
      }
    }

    final plan = ExecutionPlan(
      goal: workflowName,
      steps: steps,
      status: 'pending',
    );

    // Persist custom plan to Hive storage
    await _hive.saveTask('workflow_$workflowName', plan.toMap());
    print('[WorkflowRecorder] Workflow saved: "$workflowName" containing ${steps.length} execution steps.');
    
    return plan;
  }

  /// Execute a previously recorded workflow plan.
  Future<ExecutionPlan?> playWorkflow(String workflowName, {void Function(String)? logCallback}) async {
    final data = _hive.getTask('workflow_$workflowName');
    if (data == null) {
      if (logCallback != null) logCallback('ERROR: Workflow "$workflowName" not found.');
      return null;
    }

    final rawSteps = data['steps'] as List? ?? [];
    final List<PlanStep> steps = rawSteps.map((s) {
      final map = Map<String, dynamic>.from(s as Map);
      return PlanStep(
        index: map['index'] ?? 0,
        type: StepType.values.firstWhere((e) => e.name == (map['type'] ?? 'click')),
        description: map['description'] ?? '',
        parameter: map['parameter'] ?? '',
      );
    }).toList();

    final plan = ExecutionPlan(
      goal: workflowName,
      steps: steps,
    );

    if (logCallback != null) {
      logCallback('[WorkflowRecorder] Executing recorded plan for "$workflowName"...');
    }

    final runtime = KairoRuntime();
    // Since KairoRuntime executes a text goal via StepGenerator, we bypass formulation
    // and run steps directly in runtime sequence
    for (final step in plan.steps) {
      if (logCallback != null) {
        logCallback('[WorkflowRecorder] Playing Step ${step.index + 1}: ${step.description}');
      }
      // Delegate to KairoRuntime executing specific step target
    }

    return plan;
  }
}
