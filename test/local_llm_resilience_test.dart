// Each test here is a failure a real local model (Qwen3.5 27B under Ollama)
// produced while drafting a 1,650-key catalog, reduced to the reply that
// caused it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_arb_translator/src/localization_validator.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

http.Response _reply(Object content) => http.Response(
      jsonEncode({
        'choices': [
          {
            'message': {'content': content is String ? content : jsonEncode(content)},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _payload(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  final user = (body['messages'] as List).last['content'] as String;
  return jsonDecode(user) as Map<String, dynamic>;
}

List<String> _ids(http.Request request) => [
      for (final resource in _payload(request)['resources'] as List) (resource as Map)['id'] as String,
    ];

Future<List<TranslationResult>> _translate(
  List<TranslationResource> resources,
  http.Client client, {
  bool jsonSchema = false,
  int batchSize = 0,
  int timeoutSeconds = 600,
}) =>
    TranslationService.translateResources(
      resources: resources,
      parameters: {'target': 'it'},
      translationService: 'local_llm',
      localLlmOptions: LocalLlmOptions.fromConfig(
        model: 'qwen3.5:27b',
        jsonSchema: jsonSchema,
        batchSize: batchSize,
        timeoutSeconds: timeoutSeconds,
      ),
      client: client,
    );

void main() {
  test('two placeholders a space apart both come back', () async {
    final client = MockClient((request) async => _reply({
          'translations': [
            {'id': 'join', 'translation': '__SMART_ARB_PH_0__ __SMART_ARB_PH_1__'},
          ],
        }));
    final results = await _translate(
      const [TranslationResource(id: 'join', sourceText: '{list} {item}', sourceTopic: 'ui.arb')],
      client,
    );
    expect(results.single.translation, '{list} {item}');
  });

  test('a lone resource is taken whatever id the reply echoes', () async {
    final client = MockClient((request) async => _reply({
          'translations': [
            {'id': 'traceCopia', 'translation': 'Copia la traccia'},
          ],
        }));
    final results = await _translate(
      const [TranslationResource(id: 'traceCopy', sourceText: 'Copy the trace', sourceTopic: 'ui.arb')],
      client,
    );
    expect(results.single.id, 'traceCopy');
    expect(results.single.translation, 'Copia la traccia');
  });

  test('a reply that runs on past its message is refused, and the run goes on', () async {
    final client = MockClient((request) async {
      final id = _ids(request).single;
      return _reply({
        'translations': [
          id == 'sent'
              ? {'id': id, 'translation': '{reason, select, other{Non inviato.}}}]}]'}
              : {'id': id, 'translation': 'Salva'},
        ],
      });
    });
    final results = await _translate(
      const [
        TranslationResource(id: 'sent', sourceText: '{reason, select, other{Not sent.}}', sourceTopic: 'ui.arb'),
        TranslationResource(id: 'save', sourceText: 'Save', sourceTopic: 'ui.arb'),
      ],
      client,
      batchSize: 1,
    );
    expect(results.map((r) => r.id), ['save'], reason: 'the debris is refused; the other resource is kept');
  });

  test('a reply cut off mid-string is retried rather than ending the run', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      if (calls == 1) return _reply('{"translations":[{"id":"save","translation":"Sal');
      return _reply({
        'translations': [
          {'id': 'save', 'translation': 'Salva'},
        ],
      });
    });
    final results = await _translate(
      const [TranslationResource(id: 'save', sourceText: 'Save', sourceTopic: 'ui.arb')],
      client,
    );
    expect(calls, 2);
    expect(results.single.translation, 'Salva');
  });

  test('a resource the model never gets right is left out, not fatal', () async {
    final client = MockClient((request) async {
      final ids = _ids(request);
      return _reply({
        'translations': [
          for (final id in ids) {'id': id, 'translation': id == 'stuck' ? '__SMART_ARB_PH_9__' : 'Fatto'},
        ],
      });
    });
    final results = await _translate(
      const [
        TranslationResource(id: 'done', sourceText: 'Done', sourceTopic: 'ui.arb'),
        TranslationResource(id: 'stuck', sourceText: 'Stuck {n}', sourceTopic: 'ui.arb'),
      ],
      client,
    );
    expect(results.map((r) => r.id), ['done']);
  });

  test('batch size splits the requests and a slow batch costs only itself', () async {
    final seen = <List<String>>[];
    final client = MockClient((request) async {
      final ids = _ids(request);
      seen.add(ids);
      if (ids.contains('c')) throw TimeoutException('slow');
      return _reply({
        'translations': [
          for (final id in ids) {'id': id, 'translation': id.toUpperCase()},
        ],
      });
    });
    final results = await _translate(
      [
        for (final id in ['a', 'b', 'c', 'd', 'e'])
          TranslationResource(id: id, sourceText: 'word $id', sourceTopic: 'ui.arb'),
      ],
      client,
      batchSize: 2,
    );
    expect(seen.first, ['a', 'b']);
    expect(results.map((r) => r.id), ['a', 'b', 'e']);
  });

  test('json_schema names the exact ids and count, and keyed requests state one format', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return _reply({
        'translations': [
          {'id': 'a', 'translation': 'A'},
          {'id': 'b', 'translation': 'B'},
        ],
      });
    });
    await _translate(
      const [
        TranslationResource(id: 'a', sourceText: 'Apple', sourceTopic: 'ui.arb'),
        TranslationResource(id: 'b', sourceText: 'Bread', sourceTopic: 'ui.arb'),
      ],
      client,
      jsonSchema: true,
    );
    final format = body['response_format'] as Map<String, dynamic>;
    expect(format['type'], 'json_schema');
    final array = ((format['json_schema'] as Map)['schema'] as Map)['properties']['translations'] as Map;
    expect(array['minItems'], 2);
    expect(array['maxItems'], 2);
    expect(((array['items'] as Map)['properties'] as Map)['id']['enum'], ['a', 'b']);
    final system = ((body['messages'] as List).first as Map)['content'] as String;
    expect(system, isNot(contains('{"translations":["..."]}')));
  });

  test('the validator flags a translation whose braces do not match', () {
    ArbDocument doc(String value) => ArbDocument.decode(jsonEncode({'@@locale': 'en', 'k': value}));
    final issues = LocalizationValidator.validatePair(
      source: doc('{n, plural, other{{n} items}}'),
      target: doc('{n, plural, other{{n} elementi}}}]'),
      targetLocale: 'it',
    );
    expect(issues.map((issue) => issue.code), contains('brace_parity'));
  });

  test('a skipped resource is written with no provenance, so the next run sends it again', () async {
    final temp = await Directory.systemTemp.createTemp('smart-arb-skip');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/ui.arb')
      ..writeAsStringSync('{"@@locale":"en","done":"Done","stuck":"Stuck {n}","@stuck":{"placeholders":{"n":{}}}}');
    final sent = <String>[];
    Future<void> run() => SingleFileProcessor.processSingleFileWithChanges(
          source.path,
          ['it'],
          '',
          temp.path,
          'app_it.arb',
          null,
          null,
          translationService: 'local_llm',
          localLlmOptions: LocalLlmOptions.fromConfig(model: 'qwen3.5:27b', batchSize: 1),
          client: MockClient((request) async {
            final id = _ids(request).single;
            sent.add(id);
            return _reply({
              'translations': [
                {'id': id, 'translation': id == 'stuck' ? 'Bloccato' : 'Fatto'},
              ],
            });
          }),
        );
    await run();
    final provenance =
        jsonDecode(File('${temp.path}/app_it.arb.provenance.json').readAsStringSync()) as Map<String, dynamic>;
    expect(provenance.keys, ['done']);
    expect(ArbDocument.decode(File('${temp.path}/app_it.arb').readAsStringSync()).resources['done']!.text, 'Fatto');

    sent.clear();
    await run();
    expect(sent.toSet(), {'stuck'}, reason: 'only the skipped resource is asked for again');
  });
}
