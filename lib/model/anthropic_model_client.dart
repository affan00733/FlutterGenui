import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' hide MessageRole;
import 'package:genui_template/model/model_client.dart';

/// A [ModelClient] backed by Anthropic's Claude models.
///
/// Claude is shown as the "Active Model" in the hackathon's architecture
/// diagram; this client lets us swap to it at runtime to demonstrate the
/// swappable Intelligence layer. Streams the raw A2UI text chunks of each turn.
class AnthropicModelClient extends ModelClient {
  AnthropicModelClient({
    required super.systemPrompt,
    String? apiKey,
    String? model,
  }) : _model = model ?? _defaultModel,
       _client = AnthropicClient(
         config: AnthropicConfig(
           authProvider: ApiKeyProvider(apiKey ?? _defaultApiKey),
         ),
       );

  // Sonnet is the sweet spot of speed and instruction-following for A2UI.
  static const String _defaultModel = String.fromEnvironment(
    'ANTHROPIC_MODEL',
    defaultValue: 'claude-sonnet-4-6',
  );

  // API key supplied at build time via
  // `flutter run --dart-define=ANTHROPIC_API_KEY=...`.
  static const String _defaultApiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
  );

  final String _model;
  final AnthropicClient _client;

  @override
  Stream<String> generateResponse() {
    final stream = _client.messages.createStream(
      MessageCreateRequest(
        model: _model,
        maxTokens: 8192,
        system: SystemPrompt.text(systemPrompt),
        messages: history.map(_toMessage).toList(),
      ),
    );
    // The SDK's extension flattens the event stream to just the text deltas.
    return stream.textDeltas();
  }

  InputMessage _toMessage(ModelMessage message) => switch (message.role) {
    MessageRole.user => InputMessage.user(message.text),
    MessageRole.model => InputMessage.assistant(message.text),
  };

  @override
  void dispose() {
    latestResponse.dispose();
    _client.close();
  }
}
