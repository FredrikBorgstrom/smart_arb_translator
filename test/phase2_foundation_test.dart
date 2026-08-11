import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:smart_arb_translator/src/localization_validator.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/reviewed_overlay.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

void main() {
  test('review fingerprint ignores provider while cache fingerprint does not', () {
    const resource = TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb');
    expect(
      TranslationFingerprint.reviewContext(resource, translationContext: 'Navigation'),
      TranslationFingerprint.reviewContext(resource, translationContext: 'Navigation'),
    );
    expect(
      TranslationFingerprint.cacheContext(resource, provider: 'openai', model: 'a'),
      isNot(TranslationFingerprint.cacheContext(resource, provider: 'local_llm', model: 'b')),
    );
  });

  test('fingerprint fixed vector is stable for the canonical Back resource', () {
    const resource = TranslationResource(
      id: 'back',
      sourceText: 'Back',
      sourceTopic: 'ui.arb',
      description: 'Return to the previous screen.',
      uiRole: 'navigation_action',
      screenContext: 'game setup',
      neighboringTerms: ['Next'],
      glossary: {'board': 'game board'},
    );
    final source = TranslationFingerprint.source(resource);
    final review = TranslationFingerprint.reviewContext(
      resource,
      translationContext: 'Use concise game UI language.',
    );
    expect(source, '210c28db998d1991');
    expect(review, '412ae037971517f9');
  });

  test('TranslateGemma profile uses one translation-only request per resource and maps fil', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body.containsKey('response_format'), isFalse);
      final prompt = (body['messages'] as List).single['content'] as String;
      expect(prompt, contains('fil-PH'));
      expect(prompt, contains('Return only the translated text'));
      return http.Response('{"choices":[{"message":{"content":"Kumusta __SMART_ARB_PH_0__"}}]}', 200);
    });
    final results = await TranslationService.translateResources(
      resources: const [
        TranslationResource(id: 'one', sourceText: 'Hello {name}', sourceTopic: 'ui.arb'),
        TranslationResource(id: 'two', sourceText: 'Hello {name}', sourceTopic: 'ui.arb'),
      ],
      parameters: {'target': 'fil'},
      translationService: 'local_llm',
      localLlmOptions: LocalLlmOptions.fromConfig(model: 'translategemma:27b', profile: 'translategemma'),
      client: client,
    );
    expect(calls, 2);
    expect(results.map((result) => result.translation), everyElement('Kumusta {name}'));
  });

  test('TranslateGemma rejects modified ICU structure after retry', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final prompt = (body['messages'] as List).single['content'] as String;
      expect(prompt, contains('Preserve every variable name'));
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': '{count, select, one {Un élément} other {Plusieurs éléments}}',
              },
            },
          ],
        }),
        200,
      );
    });

    await expectLater(
      TranslationService.translateResources(
        resources: const [
          TranslationResource(
            id: 'items',
            sourceText: '{count, plural, one {One item} other {Many items}}',
            sourceTopic: 'ui.arb',
            icuVariables: ['count'],
            icuRoles: ['plural'],
            icuBranches: ['one', 'other'],
          ),
        ],
        parameters: {'target': 'fr'},
        translationService: 'local_llm',
        localLlmOptions: LocalLlmOptions.fromConfig(
          model: 'translategemma:27b',
          profile: 'translategemma',
        ),
        client: client,
      ),
      throwsFormatException,
    );
    expect(calls, 2);
  });

  test('Google LLM resource adapter sends source-only content with a safe identity label', () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['contents'], ['Back']);
      expect(body['labels'], containsPair('smart_arb_resource', contains('ui-arb-back')));
      return http.Response('{"translations":[{"translatedText":"Retour"}]}', 200);
    });
    final result = await TranslationService.translateResources(
      resources: const [TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb')],
      parameters: {'target': 'fr', 'key': 'test-key'},
      translationService: 'google_llm',
      projectId: 'project',
      client: client,
    );
    expect(result.single.id, 'back');
    expect(result.single.translation, 'Retour');
  });

  test('validators find placeholder, ICU, x-translation, commentary, and passthrough failures', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","message":"{count, plural, one {One item} other {{count} items}}","@message":{"x-translations":{"bad locale":5}}}
''');
    final target = ArbDocument.decode('''
{"@@locale":"fr","message":"Translation: {total, select, other {One item}}"}
''');
    final codes = LocalizationValidator.validatePair(source: source, target: target, targetLocale: 'fr')
        .map((issue) => issue.code)
        .toSet();
    expect(
        codes, containsAll({'translator_commentary', 'placeholder_parity', 'icu_integrity', 'invalid_x_translation'}));
  });

  test('validators detect extra keys, ICU variables, and non-Latin target script mismatch', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","items":"{count, plural, one {One item} other {{count} items}}","brand":"ABCx3"}
''');
    final target = ArbDocument.decode('''
{"@@locale":"ar","items":"{total, plural, one {عنصر} other {{total} عناصر}}","brand":"ABCx3","obsolete":"قديم"}
''');
    final codes = LocalizationValidator.validatePair(source: source, target: target, targetLocale: 'ar')
        .map((issue) => issue.code)
        .toSet();
    expect(codes, containsAll({'icu_integrity', 'extra_target_key'}));
    expect(codes, isNot(contains('target_script_mismatch'))); // a single brand is allowed

    final englishArabic = ArbDocument.decode('''
{"@@locale":"ar","items":"This remains entirely English text"}
''');
    final englishCodes = LocalizationValidator.validatePair(source: source, target: englishArabic, targetLocale: 'ar')
        .map((issue) => issue.code)
        .toSet();
    expect(englishCodes, contains('target_script_mismatch'));
  });

  test('script validation ignores structural ICU tokens', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","unread":"{unreadCount, plural, =1{1 unread} other{{unreadCount} unread}}","role":"{role, select, host {Host} player {Player} other {Player}}"}
''');
    final japanese = ArbDocument.decode('''
{"@@locale":"ja","unread":"{unreadCount, plural, =1{1 件未読} other{{unreadCount} 件未読}}","role":"{role, select, host {ホスト} player {参加者} other {参加者}}"}
''');
    final korean = ArbDocument.decode('''
{"@@locale":"ko","unread":"{unreadCount, plural, =1{1개 읽지 않음} other{{unreadCount}개 읽지 않음}}","role":"{role, select, host {호스트} player {참가자} other {참가자}}"}
''');

    for (final pair in <(String, ArbDocument)>[
      ('ja', japanese),
      ('ko', korean),
    ]) {
      final codes = LocalizationValidator.validatePair(
        source: source,
        target: pair.$2,
        targetLocale: pair.$1,
      ).map((issue) => issue.code);
      expect(codes.where((code) => code.contains('script')), isEmpty);
    }
  });

  test('validator detects translator commentary embedded after target text', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","status":"Notifying opponents"}
''');
    final target = ArbDocument.decode('''
{"@@locale":"hy","status":"Հակառակորդներին (Have to correct this; it got cut off) ծանուցում"}
''');

    final codes = LocalizationValidator.validatePair(
      source: source,
      target: target,
      targetLocale: 'hy',
    ).map((issue) => issue.code);

    expect(codes, contains('translator_commentary'));
  });

  test('validator does not mistake one-word select branch text for placeholders', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","role":"{role, select, host {Host} player {Player} other {Player}}"}
''');
    final target = ArbDocument.decode('''
{"@@locale":"fr","role":"{role, select, host {Hôte} player {Joueur} other {Joueur}}"}
''');
    final codes = LocalizationValidator.validatePair(
      source: source,
      target: target,
      targetLocale: 'fr',
    ).map((issue) => issue.code);
    expect(codes, isNot(contains('placeholder_parity')));
    expect(codes, isNot(contains('icu_integrity')));
  });

  test('validator extracts only structural ICU labels around nested placeholders', () {
    final source = ArbDocument.decode('''
{"@@locale":"en","score":"{count, plural, one {Scored {score} word} other {Scored {score} words}}","@score":{"placeholders":{"count":{"type":"int"},"score":{"type":"int"}}}}
''');
    final target = ArbDocument.decode('''
{"@@locale":"fr","score":"{count, plural, one {Marqué {score} mot} other {Marqué {score} mots}}","@score":{"placeholders":{"count":{"type":"int"},"score":{"type":"int"}}}}
''');
    final codes = LocalizationValidator.validatePair(
      source: source,
      target: target,
      targetLocale: 'fr',
    ).map((issue) => issue.code);
    expect(codes, isNot(contains('placeholder_parity')));
    expect(codes, isNot(contains('icu_integrity')));
  });

  test('validators flag one-word Arabic passthrough unless it is allowlisted', () {
    final source = ArbDocument.decode('{"@@locale":"en","back":"Back","brand":"ABCx3"}');
    final target = ArbDocument.decode('{"@@locale":"ar","back":"Back","brand":"ABCx3"}');
    final codes = LocalizationValidator.validatePair(source: source, target: target, targetLocale: 'ar')
        .where((issue) => issue.code == 'source_passthrough')
        .map((issue) => issue.key)
        .toSet();
    expect(codes, containsAll({'back', 'brand'}));
    final allowlisted = LocalizationValidator.validatePair(
      source: source,
      target: target,
      targetLocale: 'ar',
      passthroughAllowlist: const ['ABCx3'],
    ).where((issue) => issue.code == 'source_passthrough').map((issue) => issue.key).toSet();
    expect(allowlisted, contains('back'));
    expect(allowlisted, isNot(contains('brand')));
  });

  test('review ledger rejects ARB pairing mismatch and accepts the generic minimum', () async {
    final temp = await Directory.systemTemp.createTemp('smart-arb-ledger');
    addTearDown(() => temp.delete(recursive: true));
    final resource = const TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb');
    final reviewDir = Directory('${temp.path}/fr')..createSync(recursive: true);
    File('${reviewDir.path}/ui.arb').writeAsStringSync('{"@@locale":"fr","back":"Retour"}');
    File('${reviewDir.path}/ui.review.json').writeAsStringSync(jsonEncode({
      'back': {
        'source': 'Wrong source',
        'translation': 'Retour',
        'sourceFingerprint': TranslationFingerprint.source(resource),
        'contextFingerprint': TranslationFingerprint.reviewContext(resource),
      }
    }));
    expect(
      () => ReviewedOverlay.load(
        rootDirectory: temp.path,
        locale: 'fr',
        sourceFile: 'ui.arb',
        resources: [resource],
        translationContext: null,
      ),
      throwsFormatException,
    );
  });

  test('an old ledger source is stale rather than malformed', () async {
    final temp = await Directory.systemTemp.createTemp('smart-arb-stale-ledger');
    addTearDown(() => temp.delete(recursive: true));
    const current = TranslationResource(id: 'back', sourceText: 'Go back', sourceTopic: 'ui.arb');
    const old = TranslationResource(id: 'back', sourceText: 'Back', sourceTopic: 'ui.arb');
    final reviewDir = Directory('${temp.path}/fr')..createSync(recursive: true);
    File('${reviewDir.path}/ui.arb').writeAsStringSync('{"@@locale":"fr","back":"Retour"}');
    File('${reviewDir.path}/ui.review.json').writeAsStringSync(jsonEncode({
      'back': {
        'source': old.sourceText,
        'translation': 'Retour',
        'sourceFingerprint': TranslationFingerprint.source(old),
        'contextFingerprint': TranslationFingerprint.reviewContext(old),
      }
    }));
    expect(
      ReviewedOverlay.staleKeys(
        rootDirectory: temp.path,
        locale: 'fr',
        sourceFile: 'ui.arb',
        resources: [current],
        translationContext: null,
      ),
      ['back'],
    );
  });

  test('inspection and selection controls parse without an API key', () async {
    final previous = Directory.current;
    final temp = await Directory.systemTemp.createTemp('smart-arb-controls');
    addTearDown(() {
      Directory.current = previous;
      temp.deleteSync(recursive: true);
    });
    Directory.current = temp;
    File('${temp.path}/pubspec.yaml').writeAsStringSync('name: controls\nversion: 1.0.0\n');
    final result = await ArbTranslatorArgumentParser.parseArguments([
      '--source_arb',
      'ui.arb',
      '--validate_only',
      '--locale',
      'fr,fil',
      '--source_file',
      'ui.arb',
      '--key',
      'back,clear',
      '--offline',
    ]);
    expect(result[ArbTranslatorArgumentParser.validateOnly], isTrue);
    expect(result[ArbTranslatorArgumentParser.offline], isTrue);
    expect(result[ArbTranslatorArgumentParser.localeFilter], ['fr', 'fil']);
    expect(result[ArbTranslatorArgumentParser.sourceFileFilter], ['ui.arb']);
    expect(result[ArbTranslatorArgumentParser.keyFilter], ['back', 'clear']);
  });
}
