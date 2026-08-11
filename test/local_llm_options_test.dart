import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:test/test.dart';

void main() {
  group('LocalLlmOptions', () {
    test('normalizes a server root to chat completions', () {
      final options = LocalLlmOptions.fromConfig(
        endpoint: 'http://localhost:1234/',
        model: 'model-name',
      );

      expect(
        options.endpoint.toString(),
        'http://localhost:1234/v1/chat/completions',
      );
      expect(options.maxOutputTokens, LocalLlmOptions.defaultMaxOutputTokens);
      expect(options.reasoningEffort, isNull);
    });

    test('preserves a custom OpenAI-compatible endpoint path', () {
      final options = LocalLlmOptions.fromConfig(
        endpoint: 'https://llm.internal.example/openai/chat/completions/',
        model: 'model-name',
      );

      expect(
        options.endpoint.toString(),
        'https://llm.internal.example/openai/chat/completions',
      );
    });

    test('rejects a missing model', () {
      expect(
        () => LocalLlmOptions.fromConfig(model: '  '),
        throwsArgumentError,
      );
    });

    test('rejects non-HTTP endpoints', () {
      expect(
        () => LocalLlmOptions.fromConfig(
          endpoint: 'file:///tmp/model.sock',
          model: 'model-name',
        ),
        throwsArgumentError,
      );
    });

    test('normalizes local output and reasoning controls', () {
      final options = LocalLlmOptions.fromConfig(
        model: 'reasoning-model',
        maxOutputTokens: 512,
        reasoningEffort: ' NONE ',
      );

      expect(options.maxOutputTokens, 512);
      expect(options.reasoningEffort, 'none');
    });

    test('rejects invalid output and reasoning controls', () {
      expect(
        () => LocalLlmOptions.fromConfig(
          model: 'reasoning-model',
          maxOutputTokens: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => LocalLlmOptions.fromConfig(
          model: 'reasoning-model',
          reasoningEffort: 'maximum',
        ),
        throwsArgumentError,
      );
    });
  });
}
