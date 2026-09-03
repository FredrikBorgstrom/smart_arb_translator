import 'dart:convert';

import 'package:smart_arb_translator/src/codex_translation_service.dart';
import 'package:smart_arb_translator/src/models/codex_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

class _FakeCodexRunner implements CodexRunner {
  CodexInvocation? invocation;

  @override
  Future<String> run(CodexInvocation invocation) async {
    this.invocation = invocation;
    return jsonEncode({
      'translations': [
        {
          'id': 'welcome',
          'translation': 'Välkommen __SMART_ARB_PH_0__',
        },
      ],
    });
  }
}

class _RetryCodexRunner implements CodexRunner {
  final prompts = <String>[];

  @override
  Future<String> run(CodexInvocation invocation) async {
    prompts.add(invocation.prompt);
    return jsonEncode({
      'translations': [
        {
          'id': 'welcome',
          'translation': prompts.length == 1 ? 'Välkommen __SMART_ARB_PH_1__' : 'Välkommen __SMART_ARB_PH_0__',
        },
      ],
    });
  }
}

void main() {
  const resource = TranslationResource(
    id: 'welcome',
    sourceText: 'Welcome {name}',
    description: 'Greeting shown above the signed-in player name',
    sourceTopic: 'home.arb',
    placeholders: {
      'name': {'type': 'String'},
    },
  );

  test('Codex provider sends full context and restores placeholders', () async {
    final runner = _FakeCodexRunner();
    final results = await TranslationService.translateResources(
      resources: const [resource],
      parameters: const {
        'source': 'en',
        'target': 'sv',
        'translation_context': 'Use concise mobile game language.',
      },
      translationService: 'codex',
      codexOptions: const CodexOptions(),
      codexRunner: runner,
    );

    expect(results.single.translation, 'Välkommen {name}');
    final prompt = runner.invocation!.prompt;
    expect(prompt, contains('Spawn two independent language workers'));
    expect(prompt, contains(resource.description!));
    expect(prompt, contains('Use concise mobile game language.'));
    expect(prompt, contains('__SMART_ARB_PH_0__'));
    expect(runner.invocation!.options.maxAgents, 3);
  });

  test('Codex response must preserve exact resource order and ids', () {
    expect(
      () => CodexTranslationService.parseResponse(
        '{"translations":[{"id":"different","translation":"Hej"}]}',
        resources: const [resource],
      ),
      throwsFormatException,
    );
  });

  test('Codex retries deterministic format failures without provider fallback', () async {
    final runner = _RetryCodexRunner();
    final results = await TranslationService.translateResources(
      resources: const [resource],
      parameters: const {'source': 'en', 'target': 'sv'},
      translationService: 'codex',
      codexOptions: const CodexOptions(),
      codexRunner: runner,
    );

    expect(results.single.translation, 'Välkommen {name}');
    expect(runner.prompts, hasLength(2));
    expect(
      runner.prompts.last,
      contains('unexpected placeholder token(s) __SMART_ARB_PH_1__'),
    );
  });

  test('Codex CLI enforces the configured subagent limit and model settings', () {
    const invocation = CodexInvocation(
      prompt: 'Translate.',
      outputSchema: {},
      options: CodexOptions(
        model: 'gpt-5.6-sol',
        reasoningEffort: 'medium',
        maxAgents: 4,
      ),
    );

    final arguments = CodexCliRunner.argumentsFor(
      invocation,
      workingDirectory: '/tmp/work',
      schemaPath: '/tmp/schema.json',
    );

    expect(arguments, contains('agents.enabled=true'));
    expect(
      arguments,
      contains('agents.max_concurrent_threads_per_session=4'),
    );
    expect(
      arguments,
      contains('agents.default_subagent_model="gpt-5.6-sol"'),
    );
    expect(
      arguments,
      contains('agents.default_subagent_reasoning_effort="medium"'),
    );
  });

  test('unknown providers fail closed instead of falling back to Google', () {
    expect(
      () => TranslationService.translateTexts(
        translateList: const ['Compete'],
        parameters: const {'source': 'en', 'target': 'sv'},
        translationService: 'codx',
      ),
      throwsArgumentError,
    );
  });
}
