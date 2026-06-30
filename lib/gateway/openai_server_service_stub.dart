import 'dart:async';

class OpenAiServerService {
  bool get isRunning => false;
  String? get localUrl => null;

  Future<void> start({
    int port = 8080,
    String? apiKey,
    void Function(String)? onLog,
    String Function(String)? systemPromptProvider,
  }) async {
    throw UnsupportedError('Local API server is not available on this platform.');
  }

  Future<void> stop() async {}
}
