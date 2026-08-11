import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:test/test.dart';

void main() {
  group('TranslationService', () {
    test('translateTexts uses google_basic service (v2) by default', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'translation.googleapis.com');
        expect(request.url.path, '/language/translate/v2');
        expect(request.url.queryParameters['key'], 'test-key');
        expect(request.url.queryParameters['target'], 'es');
        expect(request.url.queryParameters['q'], 'Hello');
        expect(request.url.queryParameters['model'], isNull);

        return http.Response('{"data": {"translations": [{"translatedText": "Hola"}]}}', 200);
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {'key': 'test-key', 'target': 'es'},
        client: mockClient,
      );

      expect(result, ['Hola']);
    });

    test('translateTexts uses google_nmt service (v2 with model=nmt)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'translation.googleapis.com');
        expect(request.url.path, '/language/translate/v2');
        expect(request.url.queryParameters['model'], 'nmt');

        return http.Response('{"data": {"translations": [{"translatedText": "Hola NMT"}]}}', 200);
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {'key': 'test-key', 'target': 'es'},
        translationService: 'google_nmt',
        client: mockClient,
      );

      expect(result, ['Hola NMT']);
    });

    test('translateTexts uses google_llm service (v3)', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'translation.googleapis.com');
        expect(request.url.path, '/v3/projects/my-project/locations/us-central1:translateText');
        expect(request.url.queryParameters['key'], 'test-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['contents'], ['Hello']);
        expect(body['targetLanguageCode'], 'es');
        expect(body['mimeType'], 'text/html');
        expect(body['model'], 'projects/my-project/locations/us-central1/models/general/translation-llm');

        return http.Response('{"translations": [{"translatedText": "Hola LLM"}]}', 200);
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {'key': 'test-key', 'target': 'es'},
        translationService: 'google_llm',
        projectId: 'my-project',
        client: mockClient,
      );

      expect(result, ['Hola LLM']);
    });

    test('translateTexts uses OAuth headers for google_llm with adc auth mode', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'translation.googleapis.com');
        expect(request.url.path, '/v3/projects/my-project/locations/us-central1:translateText');
        expect(request.url.queryParameters['key'], isNull);
        expect(request.headers['authorization'], 'Bearer test-access-token');
        expect(request.headers['x-goog-user-project'], 'billing-project-id');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['contents'], ['Hello']);
        expect(body['targetLanguageCode'], 'es');
        expect(body['mimeType'], 'text/html');
        expect(body['model'], 'projects/my-project/locations/us-central1/models/general/translation-llm');

        return http.Response('{"translations": [{"translatedText": "Hola OAuth"}]}', 200);
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {'target': 'es'},
        translationService: 'google_llm',
        authMode: 'adc',
        accessToken: 'test-access-token',
        quotaProjectId: 'billing-project-id',
        projectId: 'my-project',
        client: mockClient,
      );

      expect(result, ['Hola OAuth']);
    });

    test('translateTexts throws if project ID is missing for google_llm service', () async {
      expect(
        () => TranslationService.translateTexts(
          translateList: ['Hello'],
          parameters: {'key': 'test-key', 'target': 'es'},
          translationService: 'google_llm',
        ),
        throwsArgumentError,
      );
    });

    test('translateTexts throws if API key is missing for google_llm with api_key auth mode', () async {
      expect(
        () => TranslationService.translateTexts(
          translateList: ['Hello'],
          parameters: {'target': 'es'},
          translationService: 'google_llm',
          authMode: 'api_key',
          projectId: 'my-project',
        ),
        throwsArgumentError,
      );
    });

    test('translateTexts uses openai service with context and model', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'api.openai.com');
        expect(request.url.path, '/v1/chat/completions');
        expect(request.headers['authorization'], 'Bearer openai-key');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'gpt-4.1-mini');
        expect(body.containsKey('max_tokens'), isFalse);
        expect(body.containsKey('reasoning_effort'), isFalse);
        expect((body['response_format'] as Map<String, dynamic>)['type'], 'json_object');

        final messages = List<Map<String, dynamic>>.from(body['messages'] as List<dynamic>);
        expect(messages, hasLength(2));
        expect(messages[0]['role'], 'system');
        expect(messages[0]['content'] as String, contains('product names should stay in English'));
        expect(messages[1]['role'], 'user');

        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Hola contexto\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {
          'key': 'openai-key',
          'target': 'es',
          'openai_model': 'gpt-4.1-mini',
          'translation_context': 'product names should stay in English',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['Hola contexto']);
    });

    test('translateTexts throws if API key is missing for openai', () async {
      expect(
        () => TranslationService.translateTexts(
          translateList: ['Hello'],
          parameters: {'target': 'es'},
          translationService: 'openai',
        ),
        throwsArgumentError,
      );
    });

    test('translateTexts uses a local OpenAI-compatible LLM without an API key', () async {
      final options = LocalLlmOptions.fromConfig(
        endpoint: 'http://127.0.0.1:11434/v1',
        model: 'qwen2.5:32b',
        maxOutputTokens: 640,
        reasoningEffort: 'none',
      );
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), 'http://127.0.0.1:11434/v1/chat/completions');
        expect(request.headers['authorization'], isNull);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], 'qwen2.5:32b');
        expect(body['temperature'], 0);
        expect(body['max_tokens'], 640);
        expect(body['reasoning_effort'], 'none');
        expect(body['response_format'], {'type': 'json_object'});

        final messages = List<Map<String, dynamic>>.from(body['messages'] as List<dynamic>);
        expect(messages[0]['content'] as String, contains('mobile UI actions'));
        final userPayload = jsonDecode(messages[1]['content'] as String) as Map<String, dynamic>;
        expect(userPayload['target_language'], 'fr');
        expect(userPayload['texts'], ['Clear']);

        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Effacer\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Clear'],
        parameters: {
          'target': 'fr',
          'translation_context': 'Use imperative verbs for mobile UI actions.',
        },
        translationService: 'local_llm',
        localLlmOptions: options,
        client: mockClient,
      );

      expect(result, ['Effacer']);
    });

    test('local LLM can omit response_format for limited compatibility servers', () async {
      final options = LocalLlmOptions.fromConfig(
        endpoint: 'http://localhost:1234/v1/chat/completions',
        model: 'local-model',
        jsonMode: false,
      );
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.containsKey('response_format'), isFalse);
        return http.Response(
          '{"choices":[{"message":{"content":"```json\\n{\\"translations\\":[\\"Retour\\"]}\\n```"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Back'],
        parameters: {'target': 'fr'},
        translationService: 'local_llm',
        localLlmOptions: options,
        client: mockClient,
      );

      expect(result, ['Retour']);
    });

    test('translateTexts requires local LLM options for local_llm', () async {
      expect(
        () => TranslationService.translateTexts(
          translateList: ['Hello'],
          parameters: {'target': 'fr'},
          translationService: 'local_llm',
        ),
        throwsArgumentError,
      );
    });

    test('translateTexts preserves ARB placeholders for openai', () async {
      final sourceText =
          '<span>Developed by <span class="notranslate">company</span> in <span class="notranslate">country</span></span>';

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = List<Map<String, dynamic>>.from(body['messages'] as List<dynamic>);
        final userPayload = jsonDecode(messages[1]['content'] as String) as Map<String, dynamic>;
        final payloadText = (userPayload['texts'] as List<dynamic>).first as String;

        expect(payloadText, contains('__SMART_ARB_PH_0__'));
        expect(payloadText, contains('__SMART_ARB_PH_1__'));
        expect(payloadText, isNot(contains('company')));
        expect(payloadText, isNot(contains('country')));

        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Sviluppato da __SMART_ARB_PH_0__ in __SMART_ARB_PH_1__\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: [sourceText],
        parameters: {
          'key': 'openai-key',
          'target': 'it',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['Sviluppato da {company} in {country}']);
    });

    test('translateTexts normalizes openai placeholder token variants', () async {
      final sourceText =
          '<span>Developed by <span class="notranslate">company</span> in <span class="notranslate">country</span></span>';

      final mockClient = MockClient((request) async {
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Sviluppato da __smart arb ph 0__ in __smart-arb-ph-1__\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: [sourceText],
        parameters: {
          'key': 'openai-key',
          'target': 'it',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['Sviluppato da {company} in {country}']);
    });

    test('translateTexts throws when openai changes placeholder tokens', () async {
      final sourceText = '<span>Developed by <span class="notranslate">company</span></span>';

      final mockClient = MockClient((request) async {
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Sviluppato da azienda\\"]}"}}]}',
          200,
        );
      });

      expect(
        () => TranslationService.translateTexts(
          translateList: [sourceText],
          parameters: {
            'key': 'openai-key',
            'target': 'it',
          },
          translationService: 'openai',
          client: mockClient,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('translateTexts removes extra empty openai list entries', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Salom\\",\\"\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {
          'key': 'openai-key',
          'target': 'uz',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['Salom']);
    });

    test('translateTexts retries once when openai returns wrong count', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '{"choices":[{"message":{"content":"{\\"translations\\":[\\"A\\",\\"B\\"]}"}}]}',
            200,
          );
        }
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"A\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['Hello'],
        parameters: {
          'key': 'openai-key',
          'target': 'uz',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['A']);
      expect(calls, 2);
    });

    test('translateTexts falls back to per-item translation on persistent count mismatch', () async {
      var batchCalls = 0;
      var singleCalls = 0;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = List<Map<String, dynamic>>.from(body['messages'] as List<dynamic>);
        final userPayload = jsonDecode(messages[1]['content'] as String) as Map<String, dynamic>;
        final texts = List<String>.from((userPayload['texts'] as List<dynamic>).map((e) => e.toString()));

        if (texts.length == 2) {
          batchCalls++;
          return http.Response(
            '{"choices":[{"message":{"content":"{\\"translations\\":[\\"only-one\\"]}"}}]}',
            200,
          );
        }

        singleCalls++;
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"${texts.first}-ok\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['first', 'second'],
        parameters: {
          'key': 'openai-key',
          'target': 'uz',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['first-ok', 'second-ok']);
      expect(batchCalls, 2);
      expect(singleCalls, 2);
    });

    test('translateTexts retries when openai drops placeholder tokens', () async {
      var calls = 0;
      final sourceText = '<span>Developed by <span class="notranslate">company</span></span>';

      final mockClient = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Sviluppato da azienda\\"]}"}}]}',
            200,
          );
        }
        return http.Response(
          '{"choices":[{"message":{"content":"{\\"translations\\":[\\"Sviluppato da __SMART_ARB_PH_0__\\"]}"}}]}',
          200,
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: [sourceText],
        parameters: {
          'key': 'openai-key',
          'target': 'it',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['Sviluppato da {company}']);
      expect(calls, 2);
    });

    test('translateTexts retries when openai leaves multi-word source text untranslated', () async {
      var calls = 0;

      final mockClient = MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '{"choices":[{"message":{"content":"{\\"translations\\":[\\"You swapped one game tile\\"]}"}}]}',
            200,
          );
        }

        return http.Response.bytes(
          utf8.encode(
            '{"choices":[{"message":{"content":"{\\"translations\\":[\\"لقد بدلت قطعة لعبة واحدة\\"]}"}}]}',
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final result = await TranslationService.translateTexts(
        translateList: ['You swapped one game tile'],
        parameters: {
          'key': 'openai-key',
          'target': 'ar',
        },
        translationService: 'openai',
        client: mockClient,
      );

      expect(result, ['لقد بدلت قطعة لعبة واحدة']);
      expect(calls, 2);
    });

    test('applyManualTranslationsToDocument applies plural manual overrides per resource', () {
      final sourceDocument = ArbDocument.decode(
        '''
{
  "@@locale": "en",
  "playTurnSuccess": "{wordsCount, plural, one{You played the word {words} and scored {points} points.} other{You played the words {words} and scored {points} points.}}",
  "@playTurnSuccess": {
    "description": "Shown after a successful turn",
    "placeholders": {
      "wordsCount": {
        "type": "int"
      },
      "words": {
        "type": "String"
      },
      "points": {
        "type": "int"
      }
    },
    "x-translations": {
      "ar": "{wordsCount, plural, one{لقد لعبت الكلمة {words} وحصلت على {points} نقطة.} other{لقد لعبت الكلمات {words} وحصلت على {points} نقطة.}}"
    }
  }
}
''',
      );

      final translatedDocument = ArbDocument.decode(
        '''
{
  "@@locale": "ar",
  "playTurnSuccess": "{wordsCount, plural, one{لقد لعبت الكلمة {words} وحصلت على {points} نقطة.} other{You played the words {words} and scored {points} points.}}"
}
''',
      );

      final updatedDocument = TranslationService.applyManualTranslationsToDocument(
        translatedDocument: translatedDocument,
        languageCode: 'ar',
        sourceDocument: sourceDocument,
      );

      expect(
        updatedDocument.resources['playTurnSuccess']?.text,
        sourceDocument.resources['playTurnSuccess']?.attributes?.xTranslations?['ar'],
      );
    });
  });
}
