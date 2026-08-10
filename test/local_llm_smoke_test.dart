@Tags(['local-smoke'])
library;

import 'dart:io';

import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

/// Explicit only: `dart test -t local-smoke --run-skipped`.
/// It never runs in the normal test suite or CI.
void main() {
  test('configured local LLM smoke test', () async {
    final model = Platform.environment['SMART_ARB_LOCAL_SMOKE_MODEL'];
    if (model == null || model.trim().isEmpty) {
      throw StateError('Set SMART_ARB_LOCAL_SMOKE_MODEL before explicitly running this local smoke test.');
    }
    final result = await TranslationService.translateResources(
      resources: const [TranslationResource(id: 'smoke', sourceText: 'Back', sourceTopic: 'smoke.arb')],
      parameters: {'target': 'fr'},
      translationService: 'local_llm',
      localLlmOptions: LocalLlmOptions.fromConfig(
        endpoint: Platform.environment['SMART_ARB_LOCAL_SMOKE_URL'] ?? LocalLlmOptions.defaultEndpoint,
        model: model,
        profile: Platform.environment['SMART_ARB_LOCAL_SMOKE_PROFILE'] ?? 'openai_chat_json',
      ),
    );
    expect(result.single.translation, isNotEmpty);
  });
}
