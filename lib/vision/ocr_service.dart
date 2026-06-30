import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'vision_models.dart';

/// Integrates local/cloud OCR pipeline for Kairo's screen text detection.
class OcrService {
  static const MethodChannel _channel = MethodChannel('com.ghias.mobile/ocr');

  /// Perform text recognition on the provided raw image bytes.
  Future<List<DetectedText>> detectText(Uint8List imageBytes) async {
    try {
      final List<dynamic>? results = await _channel.invokeMethod<List<dynamic>>(
        'detectText',
        {'imageBytes': imageBytes},
      );
      if (results == null) return [];
      
      return results.map((item) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(item as Map);
        return DetectedText.fromMap(data);
      }).toList();
    } on PlatformException catch (e) {
      print('[OcrService] detectText error: $e');
      return [];
    }
  }
}
