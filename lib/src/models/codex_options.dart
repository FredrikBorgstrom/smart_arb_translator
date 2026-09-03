/// Configuration for the Codex CLI translation provider.
class CodexOptions {
  static const String defaultExecutable = 'codex';
  static const int defaultTimeoutSeconds = 900;
  static const int defaultMaxAgents = 3;
  static const Set<String> allowedReasoningEfforts = {
    'none',
    'minimal',
    'low',
    'medium',
    'high',
    'xhigh',
    'max',
    'ultra',
  };

  final String executable;
  final String? model;
  final String? reasoningEffort;
  final Duration timeout;
  final int maxAgents;

  const CodexOptions({
    this.executable = defaultExecutable,
    this.model,
    this.reasoningEffort,
    this.timeout = const Duration(seconds: defaultTimeoutSeconds),
    this.maxAgents = defaultMaxAgents,
  });

  factory CodexOptions.fromConfig({
    String? executable,
    String? model,
    String? reasoningEffort,
    int timeoutSeconds = defaultTimeoutSeconds,
    int maxAgents = defaultMaxAgents,
  }) {
    final normalizedExecutable = executable?.trim();
    final normalizedModel = model?.trim();
    final normalizedReasoningEffort = reasoningEffort?.trim();

    final options = CodexOptions(
      executable:
          normalizedExecutable == null || normalizedExecutable.isEmpty ? defaultExecutable : normalizedExecutable,
      model: normalizedModel == null || normalizedModel.isEmpty ? null : normalizedModel,
      reasoningEffort:
          normalizedReasoningEffort == null || normalizedReasoningEffort.isEmpty ? null : normalizedReasoningEffort,
      timeout: Duration(seconds: timeoutSeconds),
      maxAgents: maxAgents,
    );
    options.validate();
    return options;
  }

  /// Validates both parsed configuration and direct programmatic instances.
  void validate() {
    if (timeout.inSeconds < 1) {
      throw ArgumentError.value(
        timeout.inSeconds,
        'timeout',
        'must be at least 1',
      );
    }
    if (maxAgents < 2) {
      throw ArgumentError.value(
        maxAgents,
        'maxAgents',
        'must be at least 2 so translation and verification are independent',
      );
    }
    if (maxAgents > 16) {
      throw ArgumentError.value(
        maxAgents,
        'maxAgents',
        'must not exceed 16',
      );
    }
    if (reasoningEffort != null && reasoningEffort!.isNotEmpty && !allowedReasoningEfforts.contains(reasoningEffort)) {
      throw ArgumentError.value(
        reasoningEffort,
        'reasoningEffort',
        'must be one of ${allowedReasoningEfforts.join(', ')}',
      );
    }
  }

  /// All settings that can change a generated translation.
  String get cacheIdentity => <String>[
        model ?? 'configured-default',
        'reasoning=${reasoningEffort ?? 'configured-default'}',
        'agents=$maxAgents',
      ].join(';');
}
