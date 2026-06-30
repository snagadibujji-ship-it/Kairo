import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Manages writing before/after action screenshots to local disk storage for post-mortem visual auditing.
class ScreenshotTimeline {
  
  /// Write image frame to disk, tagged by step index and timeline point.
  Future<String?> saveStepFrame(Uint8List imageBytes, int stepIndex, {required bool isBefore}) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timelineDir = Directory('${docDir.path}/timeline');
      if (!await timelineDir.exists()) {
        await timelineDir.create(recursive: true);
      }

      final phase = isBefore ? 'before' : 'after';
      final stepStr = stepIndex.toString().padLeft(2, '0');
      final file = File('${timelineDir.path}/Step_${stepStr}_$phase.jpg');
      
      await file.writeAsBytes(imageBytes);
      print('[ScreenshotTimeline] Saved frame to: ${file.path}');
      return file.path;
    } catch (e) {
      print('[ScreenshotTimeline] Failed to save frame: $e');
      return null;
    }
  }

  /// Clean up all old screenshot timeline frames.
  Future<void> clearTimeline() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timelineDir = Directory('${docDir.path}/timeline');
      if (await timelineDir.exists()) {
        await timelineDir.delete(recursive: true);
      }
    } catch (e) {
      print('[ScreenshotTimeline] Clear error: $e');
    }
  }
}
