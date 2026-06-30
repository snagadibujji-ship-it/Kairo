import 'dart:convert';
import 'package:get/get.dart';
import '../../memory/hive_service.dart';

/// Represents a single recorded action log entry.
class ActionLog {
  final String action;
  final DateTime timestamp;
  final String screenStatePackage;
  final String result;
  final double confidence;

  const ActionLog({
    required this.action,
    required this.timestamp,
    required this.screenStatePackage,
    required this.result,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'screenStatePackage': screenStatePackage,
      'result': result,
      'confidence': confidence,
    };
  }
}

/// System for recording Kairo's action trajectory to enable post-execution audits.
class ActionRecorder extends GetxService {
  final HiveService _hive = Get.find<HiveService>();
  final List<ActionLog> _currentTrajectory = [];

  List<ActionLog> get currentTrajectory => List.unmodifiable(_currentTrajectory);

  /// Record a new action step execution.
  void record({
    required String action,
    required String screenStatePackage,
    required String result,
    required double confidence,
  }) {
    final logEntry = ActionLog(
      action: action,
      timestamp: DateTime.now(),
      screenStatePackage: screenStatePackage,
      result: result,
      confidence: confidence,
    );
    _currentTrajectory.add(logEntry);
    
    // Append to local console logs
    print('[ActionRecorder] TRAJECTORY RECORD: ${logEntry.action} | Status: ${logEntry.result} | Confidence: ${(logEntry.confidence * 100).toStringAsFixed(0)}%');
  }

  /// Persist the current trajectory session to Hive storage.
  Future<void> saveSession(String goal) async {
    if (_currentTrajectory.isEmpty) return;
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final data = {
      'goal': goal,
      'trajectory': _currentTrajectory.map((l) => l.toMap()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _hive.saveTask('trajectory_$sessionId', data);
    _currentTrajectory.clear();
  }
}
