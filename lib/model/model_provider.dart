import 'package:genui_template/model/anthropic_model_client.dart';
import 'package:genui_template/model/featherless_model_client.dart';
import 'package:genui_template/model/gemini_model_client.dart';
import 'package:genui_template/model/model_client.dart';

/// The selectable LLM providers — the "swappable Intelligence" layer from the
/// architecture diagram. Each maps to a [ModelClient] builder; the rest of the
/// app (catalog, prompt, rendering) is identical regardless of which is active.
///
/// Keys are supplied at launch, e.g.
/// `--dart-define=FEATHERLESS_API_KEY=... --dart-define=GEMINI_API_KEY=...`.
enum ModelProvider {
  featherless('Featherless', FeatherlessModelClient.new),
  gemini('Gemini', GeminiModelClient.new),
  claude('Claude', AnthropicModelClient.new);

  const ModelProvider(this.label, this.builder);

  /// Display name shown in the model switcher.
  final String label;

  /// Constructs the matching [ModelClient] for a given system prompt.
  final ModelClient Function({required String systemPrompt}) builder;

  /// The dart-define name for this provider's API key.
  String get apiKeyEnv => switch (this) {
    ModelProvider.featherless => 'FEATHERLESS_API_KEY',
    ModelProvider.gemini => 'GEMINI_API_KEY',
    ModelProvider.claude => 'ANTHROPIC_API_KEY',
  };

  /// Whether this provider's API key was supplied at launch.
  bool get hasApiKey => switch (this) {
    ModelProvider.featherless =>
      const String.fromEnvironment('FEATHERLESS_API_KEY').isNotEmpty,
    ModelProvider.gemini =>
      const String.fromEnvironment('GEMINI_API_KEY').isNotEmpty,
    ModelProvider.claude =>
      const String.fromEnvironment('ANTHROPIC_API_KEY').isNotEmpty,
  };

  /// The provider to start on: the first one whose key was supplied, so the app
  /// works out-of-the-box with whatever key(s) you launched with.
  static ModelProvider get initial =>
      values.firstWhere((p) => p.hasApiKey, orElse: () => featherless);
}
