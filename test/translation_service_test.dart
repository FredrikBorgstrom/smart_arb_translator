import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
  });
}
