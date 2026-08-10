import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/reviewed_overlay.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

void main() {
  group('P0 localization foundation', () {
    test('structured local request carries contextual resources', () async {
      final resources = <TranslationResource>[
        const TranslationResource(
          id: 'back',
          sourceText: 'Back',
          description: 'Navigation control returning to the previous screen.',
          sourceTopic: 'ui.arb',
          uiRole: 'navigation_action',
          screenContext: 'game setup',
          neighboringTerms: ['Next'],
        ),
        const TranslationResource(
          id: 'clear',
          sourceText: 'Clear',
          description: 'Imperative action clearing selected tiles.',
          sourceTopic: 'gameplay.arb',
          uiRole: 'button',
        ),
        const TranslationResource(
          id: 'background',
          sourceText: 'Background {color}',
          description: 'Visual style control for board background color.',
          sourceTopic: 'game_board_designer.arb',
          placeholders: {
            'color': {'type': 'String', 'description': 'Selected color name'}
          },
          icuRoles: ['select'],
          icuBranches: ['other'],
          glossary: {'board': 'game board'},
        ),
      ];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final payload = jsonDecode((body['messages'] as List)[1]['content'] as String) as Map<String, dynamic>;
        final structured = List<Map<String, dynamic>>.from(payload['resources'] as List);
        expect(structured[0]['id'], 'back');
        expect(structured[0]['ui_role'], 'navigation_action');
        expect(structured[0]['description'], contains('previous screen'));
        expect(structured[1]['description'], contains('Imperative'));
        expect(structured[2]['source_text'], contains('__SMART_ARB_PH_0__'));
        expect(structured[2]['placeholder_tokens_protected'], isTrue);
        expect(structured[2], isNot(contains('protected_source_text')));
        expect((structured[2]['placeholders'] as Map)['color'], containsPair('description', 'Selected color name'));
        expect(structured[2]['source_topic'], 'game_board_designer.arb');
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[{\\"id\\":\\"back\\",\\"translation\\":\\"Retour\\"},{\\"id\\":\\"clear\\",\\"translation\\":\\"Effacer\\"},{\\"id\\":\\"background\\",\\"translation\\":\\"Arrière-plan __SMART_ARB_PH_0__\\"}]}"}}]}',
          200,
        );
      });
      final values = await TranslationService.translateResources(
        resources: resources,
        parameters: {'target': 'fr'},
        translationService: 'local_llm',
        localLlmOptions: LocalLlmOptions.fromConfig(model: 'test-local'),
        client: client,
      );
      expect(values.map((result) => result.translation), ['Retour', 'Effacer', 'Arrière-plan {color}']);
    });

    test('structured local request preserves nested ICU instead of creating nested HTML spans', () async {
      const resource = TranslationResource(
        id: 'unread',
        sourceText: '{unreadCount, plural, =1{1 unread} other{{unreadCount} unread}}',
        description: 'Unread badge label.',
        sourceTopic: 'community_chat.arb',
        placeholders: {
          'unreadCount': {'type': 'int'}
        },
        icuVariables: ['unreadCount'],
        icuRoles: ['plural'],
        icuBranches: ['=1', 'other'],
      );
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final payload = jsonDecode((body['messages'] as List)[1]['content'] as String) as Map<String, dynamic>;
        final structured = List<Map<String, dynamic>>.from(payload['resources'] as List);
        expect(
          structured.single['source_text'],
          '{unreadCount, plural, =1{1 unread} other{__SMART_ARB_PH_0__ unread}}',
        );
        expect(
          structured.single['source_text'],
          isNot(contains('notranslate')),
        );
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[{\\"id\\":\\"unread\\",\\"translation\\":\\"{unreadCount, plural, =1{1 non lu} other{__SMART_ARB_PH_0__ non lus}}\\"}]}"}}]}',
          200,
        );
      });
      final values = await TranslationService.translateResources(
        resources: const [resource],
        parameters: {'target': 'fr'},
        translationService: 'local_llm',
        localLlmOptions: LocalLlmOptions.fromConfig(model: 'test-local'),
        client: client,
      );
      expect(calls, 1);
      expect(
        values.single.translation,
        '{unreadCount, plural, =1{1 non lu} other{{unreadCount} non lus}}',
      );
    });

    test('full x-translations cover manual_only without HTTP', () async {
      final temp = await Directory.systemTemp.createTemp('smart-arb-x-overlay');
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/ui.arb')
        ..writeAsStringSync('''{"@@locale":"en","back":"Back","@back":{"x-translations":{"fr":"Retour"}}}''');
      var calls = 0;
      await SingleFileProcessor.processSingleFileWithChanges(
        source.path,
        ['fr'],
        '',
        temp.path,
        'intl_fr.arb',
        null,
        null,
        manualOnly: true,
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      expect(calls, 0);
      expect(ArbDocument.decode(File('${temp.path}/intl_fr.arb').readAsStringSync()).resources['back']!.text, 'Retour');
    });

    test('current reviewed overlay covers manual_only without HTTP', () async {
      final temp = await Directory.systemTemp.createTemp('smart-arb-reviewed-overlay');
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/ui.arb')
        ..writeAsStringSync(
            '''{"@@locale":"en","clear":"Clear","@clear":{"description":"Imperative button action."}}''');
      final document = ArbDocument.decode(source.readAsStringSync());
      final resource = TranslationResource.fromArbResource(document.resources['clear']!, sourceTopic: 'ui.arb');
      final reviewDir = Directory('${temp.path}/reviewed/fr')..createSync(recursive: true);
      File('${reviewDir.path}/ui.arb').writeAsStringSync('{"@@locale":"fr","clear":"Effacer"}');
      File('${reviewDir.path}/ui.review.json').writeAsStringSync(jsonEncode({
        'clear': {
          'source': 'Clear',
          'translation': 'Effacer',
          'sourceFingerprint': TranslationFingerprint.source(resource),
          'contextFingerprint': TranslationFingerprint.reviewContext(
            resource,
          ),
        }
      }));
      var calls = 0;
      await SingleFileProcessor.processSingleFileWithChanges(
        source.path,
        ['fr'],
        '',
        temp.path,
        'intl_fr.arb',
        null,
        null,
        reviewedTranslationsDir: '${temp.path}/reviewed',
        manualOnly: true,
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      expect(calls, 0);
      expect(
          ArbDocument.decode(File('${temp.path}/intl_fr.arb').readAsStringSync()).resources['clear']!.text, 'Effacer');
    });

    test('manual_only reports exact uncovered key before HTTP', () async {
      final temp = await Directory.systemTemp.createTemp('smart-arb-manual-gap');
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/ui.arb')..writeAsStringSync('{"@@locale":"en","background":"Background"}');
      var calls = 0;
      try {
        await SingleFileProcessor.processSingleFileWithChanges(
          source.path,
          ['fr'],
          '',
          temp.path,
          'intl_fr.arb',
          null,
          null,
          manualOnly: true,
          client: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        );
        fail('Expected ManualCoverageException');
      } on ManualCoverageException catch (error) {
        expect(error.missing.map((entry) => entry.toString()), ['fr/ui.arb#background']);
      }
      expect(calls, 0);
    });

    test('fingerprints invalidate a reviewed value after contextual change', () {
      const before =
          TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb', uiRole: 'navigation_action');
      const after = TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb', uiRole: 'body_text');
      expect(TranslationFingerprint.source(before), TranslationFingerprint.source(after));
      expect(TranslationFingerprint.context(before, provider: 'local_llm', model: 'a'),
          isNot(TranslationFingerprint.context(after, provider: 'local_llm', model: 'a')));
      expect(TranslationFingerprint.context(before, provider: 'local_llm', model: 'a'),
          isNot(TranslationFingerprint.context(before, provider: 'local_llm', model: 'b')));
    });

    test('changed context invalidates cache provenance before HTTP', () async {
      final temp = await Directory.systemTemp.createTemp('smart-arb-provenance');
      addTearDown(() => temp.delete(recursive: true));
      final source = File('${temp.path}/ui.arb')..writeAsStringSync('{"@@locale":"en","back":"Back"}');
      await SingleFileProcessor.processSingleFileWithChanges(
        source.path,
        ['fr'],
        '',
        temp.path,
        'intl_fr.arb',
        null,
        null,
        translationService: 'local_llm',
        localLlmOptions: LocalLlmOptions.fromConfig(model: 'test-local'),
        translationContext: 'Navigation control.',
        client: MockClient((_) async => http.Response(
              '{"choices":[{"message":{"content":"{\\"translations\\":[{\\"id\\":\\"back\\",\\"translation\\":\\"Retour\\"}]}"}}]}',
              200,
            )),
      );
      expect(File('${temp.path}/intl_fr.arb.provenance.json').existsSync(), isTrue);
      var calls = 0;
      await expectLater(
        () => SingleFileProcessor.processSingleFileWithChanges(
          source.path,
          ['fr'],
          '',
          temp.path,
          'intl_fr.arb',
          null,
          null,
          translationService: 'local_llm',
          translationContext: 'Destructive navigation control.',
          manualOnly: true,
          client: MockClient((_) async {
            calls++;
            return http.Response('', 500);
          }),
        ),
        throwsA(isA<ManualCoverageException>()),
      );
      expect(calls, 0);
    });

    test('local structured execution has at most one in-flight request by default', () async {
      var active = 0;
      var maxActive = 0;
      final client = MockClient((request) async {
        active++;
        maxActive = maxActive < active ? active : maxActive;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        active--;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final payload = jsonDecode((body['messages'] as List)[1]['content'] as String) as Map<String, dynamic>;
        final entries = List<Map<String, dynamic>>.from(payload['resources'] as List);
        return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'translations': [
                        for (final entry in entries) {'id': entry['id'], 'translation': 'x-${entry['id']}'}
                      ]
                    })
                  }
                }
              ]
            }),
            200);
      });
      final resources = List<TranslationResource>.generate(
        40,
        (index) => TranslationResource(id: 'key$index', sourceText: 'Text $index', sourceTopic: 'ui.arb'),
      );
      await TranslationService.translateResources(
        resources: resources,
        parameters: {'target': 'fr'},
        translationService: 'local_llm',
        localLlmOptions: LocalLlmOptions.fromConfig(model: 'test-local'),
        client: client,
      );
      expect(maxActive, 1);
    });
  });
}
