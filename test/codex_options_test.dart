import 'package:smart_arb_translator/src/models/codex_options.dart';
import 'package:test/test.dart';

void main() {
  group('CodexOptions', () {
    test('uses safe orchestration defaults', () {
      final options = CodexOptions.fromConfig();

      expect(options.executable, CodexOptions.defaultExecutable);
      expect(options.model, isNull);
      expect(options.timeout.inSeconds, CodexOptions.defaultTimeoutSeconds);
      expect(options.maxAgents, CodexOptions.defaultMaxAgents);
      expect(options.cacheIdentity, contains('agents=3'));
    });

    test('requires independent translation and verification agents', () {
      expect(
        () => CodexOptions.fromConfig(maxAgents: 1),
        throwsArgumentError,
      );
      expect(
        () => const CodexOptions(maxAgents: 1).validate(),
        throwsArgumentError,
      );
    });

    test('rejects unsupported reasoning effort values from pubspec', () {
      expect(
        () => CodexOptions.fromConfig(reasoningEffort: 'extreme'),
        throwsArgumentError,
      );
    });
  });
}
