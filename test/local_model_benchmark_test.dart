import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_arb_translator/src/local_model_benchmark.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:test/test.dart';

import '../tool/local_model_benchmark.dart' as tool;

void main() {
  const corpusJson = '''
{"schema_version":1,"locales":["fr","ar"],"resources":[
 {"id":"back","source":"Back","source_topic":"ui.arb","description":"Navigation control"},
 {"id":"clear","source_text":"Clear {count}","source_topic":"game.arb","locales":["fr"]}
]}
''';

  const abcx3CorpusJson = '''
{"schemaVersion":1,"targetLocales":["fr","ar"],"cases":[
 {"id":"ambiguous_back","key":"activeGameShowcaseBackTitle","feature":"gameplay","source":"Back","description":"","placeholders":{},"targetLocales":["fr"]},
 {"id":"icu_plural","key":"communityChatPreviewUnread","feature":"community_chat","source":"{unreadCount, plural, =1{1 unread} other{{unreadCount} unread}}","description":"Unread badge","placeholders":{"unreadCount":{"type":"int"}},"targetLocales":["ar"]}
]}
''';

  test('benchmark accepts the exact ABCx3 schema aliases', () {
    final corpus = LocalModelBenchmarkCorpus.decode(abcx3CorpusJson);
    expect(corpus.schemaVersion, 1);
    expect(corpus.locales, ['fr', 'ar']);
    expect(corpus.resources.first.resource.id, 'activeGameShowcaseBackTitle');
    expect(corpus.resources.first.resource.sourceTopic, 'gameplay');
    expect(corpus.resources.first.locales, ['fr']);
    expect(corpus.resources.first.caseId, 'ambiguous_back');
    expect(corpus.resources.last.resource.icuRoles, ['plural']);
    expect(corpus.resources.last.resource.icuVariables, ['unreadCount']);
  });

  test('benchmark batches resources per locale and runs locales sequentially', () async {
    final corpus = LocalModelBenchmarkCorpus.decode(corpusJson);
    var active = 0;
    var maxActive = 0;
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      active++;
      maxActive = maxActive < active ? active : maxActive;
      await Future<void>.delayed(const Duration(milliseconds: 2));
      active--;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final resources = List<Map<String, dynamic>>.from(
        (jsonDecode((body['messages'] as List)[1]['content'] as String) as Map<String, dynamic>)['resources'] as List,
      );
      expect(resources, hasLength(2));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'translations': [
                    for (final resource in resources)
                      {
                        'id': resource['id'],
                        'translation': resource['id'] == 'back' ? 'Back' : 'Effacer __SMART_ARB_PH_0__'
                      }
                  ]
                })
              }
            }
          ]
        }),
        200,
      );
    });
    final result = await LocalModelBenchmarkRunner.run(
      corpus: corpus,
      options: LocalLlmOptions.fromConfig(model: 'qwen2.5:32b'),
      selectedLocales: ['fr'],
      client: client,
    );
    expect(calls, 1);
    expect(maxActive, 1);
    expect(result['provenance'], containsPair('parallel_translations', 1));
    expect((result['provenance'] as Map)['fallback'], 'none');
    final rows = result['results'] as List;
    expect(rows, hasLength(2));
    expect((rows.first as Map)['english'], 'Back');
    expect((result['batches'] as List).single, containsPair('resource_count', 2));
    expect((rows.first as Map), contains('batch_elapsed_ms'));
    expect(((rows.first as Map)['validation'] as List).map((item) => (item as Map)['code']),
        contains('source_passthrough'));
    expect(((rows.last as Map)['validation'] as List), isEmpty);
  });

  test('TranslateGemma benchmark keeps its one-resource internal requests', () async {
    final corpus = LocalModelBenchmarkCorpus.decode(corpusJson);
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final prompt =
          ((jsonDecode(request.body) as Map<String, dynamic>)['messages'] as List).single['content'] as String;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': prompt.contains('Clear') ? 'Effacer __SMART_ARB_PH_0__' : 'Retour'}
            }
          ]
        }),
        200,
      );
    });
    final result = await LocalModelBenchmarkRunner.run(
      corpus: corpus,
      options: LocalLlmOptions.fromConfig(model: 'translategemma:27b', profile: 'translategemma'),
      selectedLocales: ['fr'],
      client: client,
    );
    expect(calls, 2);
    expect((result['batches'] as List).single, containsPair('request_mode', 'translation_only_one_resource_internal'));
  });

  test('benchmark CLI accepts the corpus schema and writes injected results without a local request', () async {
    final temp = await Directory.systemTemp.createTemp('smart-arb-benchmark-cli');
    addTearDown(() => temp.delete(recursive: true));
    final input = File('${temp.path}/benchmark_corpus.json')..writeAsStringSync(corpusJson);
    final output = File('${temp.path}/result.json');
    final logs = <String>[];
    final code = await tool.runLocalModelBenchmarkCli(
      [
        '--input',
        input.path,
        '--output',
        output.path,
        '--model',
        'qwen2.5:32b',
        '--profile',
        'openai_chat_json',
        '--locale',
        'fr',
      ],
      write: logs.add,
      writeError: logs.add,
      benchmarkRunner: ({required corpus, required options, selectedLocales}) async {
        expect(options.model, 'qwen2.5:32b');
        expect(selectedLocales, ['fr']);
        return {
          'schema_version': 1,
          'provenance': {'parallel_translations': 1, 'fallback': 'none'},
          'results': [],
        };
      },
    );
    expect(code, 0);
    expect(logs.single, contains('Wrote local-model benchmark'));
    expect(jsonDecode(output.readAsStringSync()), containsPair('schema_version', 1));
  });

  test('benchmark CLI help requires no model or endpoint', () async {
    final output = <String>[];
    final code = await tool.runLocalModelBenchmarkCli(['--help'], write: output.add, writeError: output.add);
    expect(code, 0);
    expect(output.single, contains('--input'));
  });
}
