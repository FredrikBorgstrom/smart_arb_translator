/// Configuration for a locally hosted, OpenAI-compatible chat-completions
/// server.
///
/// This works with local runtimes such as Ollama, LM Studio, llama.cpp, and
/// vLLM when they expose an OpenAI-compatible `/v1/chat/completions` endpoint.
enum LocalLlmProfile {
  openaiChatJson,
  translategemma;

  static LocalLlmProfile parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'openai_chat_json':
        return LocalLlmProfile.openaiChatJson;
      case 'translategemma':
        return LocalLlmProfile.translategemma;
      default:
        throw ArgumentError.value(value, 'profile', 'Supported profiles: openai_chat_json, translategemma.');
    }
  }
}

class LocalLlmOptions {
  /// Default Ollama OpenAI-compatible chat-completions endpoint.
  static const String defaultEndpoint = 'http://127.0.0.1:11434/v1/chat/completions';

  /// Default time allowed for a local model to complete one translation batch.
  static const int defaultTimeoutSeconds = 600;

  /// Default response ceiling. Local reasoning models can otherwise continue
  /// producing hidden reasoning until the HTTP timeout instead of returning
  /// the requested translation payload.
  static const int defaultMaxOutputTokens = 2048;

  /// Exact endpoint used for chat-completions requests.
  final Uri endpoint;

  /// Model identifier understood by the local server.
  final String model;

  /// Whether to request JSON mode with OpenAI's `response_format` field.
  final bool jsonMode;

  /// Maximum duration of a single local inference request.
  final Duration timeout;

  /// Maximum completion tokens accepted from the local runtime.
  final int maxOutputTokens;

  /// Optional OpenAI-compatible reasoning control. Keep this nullable because
  /// not every compatible runtime accepts the extension.
  final String? reasoningEffort;

  /// Prompt/response protocol for the local model family.
  final LocalLlmProfile profile;

  const LocalLlmOptions({
    required this.endpoint,
    required this.model,
    this.jsonMode = true,
    this.timeout = const Duration(seconds: defaultTimeoutSeconds),
    this.maxOutputTokens = defaultMaxOutputTokens,
    this.reasoningEffort,
    this.profile = LocalLlmProfile.openaiChatJson,
  });

  /// Builds and validates local LLM configuration from CLI or YAML values.
  factory LocalLlmOptions.fromConfig({
    String endpoint = defaultEndpoint,
    required String model,
    bool jsonMode = true,
    int timeoutSeconds = defaultTimeoutSeconds,
    int maxOutputTokens = defaultMaxOutputTokens,
    String? reasoningEffort,
    String profile = 'openai_chat_json',
  }) {
    final normalizedModel = model.trim();
    if (normalizedModel.isEmpty) {
      throw ArgumentError.value(
        model,
        'model',
        'A local LLM model is required.',
      );
    }

    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    if (normalizedEndpoint.scheme != 'http' && normalizedEndpoint.scheme != 'https') {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'The local LLM URL must use http or https.',
      );
    }
    if (normalizedEndpoint.host.isEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'The local LLM URL must include a host.',
      );
    }
    if (timeoutSeconds < 1) {
      throw ArgumentError.value(
        timeoutSeconds,
        'timeoutSeconds',
        'The local LLM timeout must be at least one second.',
      );
    }
    if (maxOutputTokens < 1) {
      throw ArgumentError.value(
        maxOutputTokens,
        'maxOutputTokens',
        'The local LLM output-token limit must be at least one.',
      );
    }
    final normalizedReasoningEffort = reasoningEffort?.trim().toLowerCase();
    if (normalizedReasoningEffort != null &&
        normalizedReasoningEffort.isNotEmpty &&
        !const {'none', 'low', 'medium', 'high'}.contains(normalizedReasoningEffort)) {
      throw ArgumentError.value(
        reasoningEffort,
        'reasoningEffort',
        'Supported values: none, low, medium, high.',
      );
    }

    return LocalLlmOptions(
      endpoint: normalizedEndpoint,
      model: normalizedModel,
      jsonMode: jsonMode,
      timeout: Duration(seconds: timeoutSeconds),
      maxOutputTokens: maxOutputTokens,
      reasoningEffort:
          normalizedReasoningEffort == null || normalizedReasoningEffort.isEmpty ? null : normalizedReasoningEffort,
      profile: LocalLlmProfile.parse(profile),
    );
  }

  static Uri _normalizeEndpoint(String value) {
    final normalized = value.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      throw ArgumentError.value(
        value,
        'endpoint',
        'The local LLM URL is not valid.',
      );
    }

    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty) {
      return uri.replace(path: '/v1/chat/completions');
    }
    if (path == '/v1') {
      return uri.replace(path: '/v1/chat/completions');
    }
    return uri.replace(path: path);
  }
}
