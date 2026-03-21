import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/utils.dart';

/// Service class for handling translation operations using Google or OpenAI APIs.
///
/// This class provides static methods for translating text content and managing
/// translation workflows for ARB (Application Resource Bundle) files.
class TranslationService {
  static const String _cloudPlatformScope = 'https://www.googleapis.com/auth/cloud-platform';
  static const String _llmModelId = 'general/translation-llm';
  static const String _llmLocation = 'us-central1';
  static const String _openAiDefaultModel = 'gpt-4o-mini';
  static const String _openAiChatCompletionsUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _openAiPlaceholderTokenPrefix = '__SMART_ARB_PH_';
  static const String _openAiPlaceholderTokenSuffix = '__';
  static final RegExp _openAiNoTranslateRegex = RegExp(r'<span class="notranslate">(.*?)</span>', dotAll: true);
  static final RegExp _openAiOuterSpanRegex = RegExp(r'^<span>(.*)</span>$', dotAll: true);
  static final RegExp _openAiCanonicalPlaceholderRegex = RegExp(r'__SMART_ARB_PH_(\d+)__');
  static final RegExp _openAiPlaceholderVariantRegex = RegExp(
    r'__(?:[\s_-])*smart(?:[\s_-])*arb(?:[\s_-])*ph(?:[\s_-])*(\d+)(?:[\s_-])*__',
    caseSensitive: false,
  );
  static final RegExp _comparisonWhitespaceRegex = RegExp(r'\s+');
  static final RegExp _comparisonPlaceholderRegex = RegExp(r'\{[^}]+\}');
  static final RegExp _englishWordRegex = RegExp(r'[A-Za-z]{3,}');

  /// Translates a list of texts using Google Translate API.
  ///
  /// Takes a list of strings to translate and API parameters including the target
  /// language and API key. Returns a list of translated strings in the same order.
  ///
  /// Parameters:
  /// - [translateList]: List of strings to be translated
  /// - [parameters]: Map containing API parameters including 'target' language and 'key'
  ///
  /// Returns a [Future<List<String>>] containing the translated texts.
  ///
  /// Throws [http.ClientException] if the API request fails.
  ///
  /// Example:
  /// ```dart
  /// final translations = await TranslationService.translateTexts(
  ///   translateList: ['Hello', 'World'],
  ///   parameters: {'target': 'es', 'key': 'your-api-key'},
  /// );
  /// ```
  static Future<List<String>> translateTexts({
    required List<String> translateList,
    required Map<String, dynamic> parameters,
    String translationService = 'google_basic',
    String? projectId,
    String authMode = 'api_key',
    String? credentialsFile,
    String? quotaProjectId,
    String? accessToken,
    http.Client? client,
  }) async {
    switch (translationService) {
      case 'google_nmt':
        return _translateWithNMT(translateList, parameters, client: client);
      case 'google_llm':
        if (projectId == null) {
          throw ArgumentError('Project ID is required for LLM translation service');
        }
        return _translateWithLLM(
          translateList,
          parameters,
          projectId,
          authMode: authMode,
          credentialsFile: credentialsFile,
          quotaProjectId: quotaProjectId,
          accessToken: accessToken,
          client: client,
        );
      case 'openai':
        return _translateWithOpenAi(
          translateList,
          parameters,
          client: client,
        );
      case 'google_basic':
      default:
        return _translateWithBasic(translateList, parameters, client: client);
    }
  }

  static Future<List<String>> _translateWithBasic(
    List<String> translateList,
    Map<String, dynamic> parameters, {
    http.Client? client,
  }) async {
    final requestParameters = Map<String, dynamic>.from(parameters);
    final translated = <String>[];
    requestParameters['q'] = translateList;

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2')
        .resolveUri(Uri(queryParameters: requestParameters));

    final data = await (client?.get(url) ?? http.get(url));

    if (data.statusCode != 200) {
      throw http.ClientException('Error ${data.statusCode}: ${data.body}', url);
    } else {
      final jsonData = jsonDecode(data.body) as Map<String, dynamic>;
      final translations = List<Map<String, dynamic>>.from(
        jsonData['data']['translations'] as Iterable,
      );

      if (translations.isNotEmpty) {
        for (final singleTranslation in translations) {
          translated.add(singleTranslation['translatedText'] as String);
        }
      }
    }

    return translated;
  }

  static Future<List<String>> _translateWithNMT(
    List<String> translateList,
    Map<String, dynamic> parameters, {
    http.Client? client,
  }) async {
    // NMT uses the same v2 API but with model=nmt
    final nmtParameters = Map<String, dynamic>.from(parameters);
    nmtParameters['model'] = 'nmt';
    return _translateWithBasic(translateList, nmtParameters, client: client);
  }

  static Future<List<String>> _translateWithLLM(
    List<String> translateList,
    Map<String, dynamic> parameters,
    String projectId, {
    String authMode = 'api_key',
    String? credentialsFile,
    String? quotaProjectId,
    String? accessToken,
    http.Client? client,
  }) async {
    switch (authMode) {
      case 'api_key':
        return _translateWithLLMUsingApiKey(
          translateList,
          parameters,
          projectId,
          client: client,
        );
      case 'adc':
      case 'service_account':
        final resolvedAccessToken = await _resolveOAuthAccessToken(
          authMode: authMode,
          credentialsFile: credentialsFile,
          accessToken: accessToken,
        );
        return _translateWithLLMUsingOAuth(
          translateList,
          parameters,
          projectId,
          accessToken: resolvedAccessToken,
          quotaProjectId: quotaProjectId,
          client: client,
        );
      default:
        throw ArgumentError('Unsupported auth mode for google_llm: $authMode');
    }
  }

  static Future<List<String>> _translateWithLLMUsingApiKey(
    List<String> translateList,
    Map<String, dynamic> parameters,
    String projectId, {
    http.Client? client,
  }) async {
    final apiKey = (parameters['key'] as String?)?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('API key is required when auth_mode is "api_key"');
    }

    final url = Uri.parse(
      'https://translation.googleapis.com/v3/projects/$projectId/locations/$_llmLocation:translateText?key=$apiKey',
    );
    final body = _buildLlmRequestBody(translateList, parameters, projectId);

    final response = await (client?.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ) ??
        http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ));

    if (response.statusCode != 200) {
      throw http.ClientException('Error ${response.statusCode}: ${response.body}', url);
    }

    return _extractV3Translations(response.body);
  }

  static Future<List<String>> _translateWithLLMUsingOAuth(
    List<String> translateList,
    Map<String, dynamic> parameters,
    String projectId, {
    required String accessToken,
    String? quotaProjectId,
    http.Client? client,
  }) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/v3/projects/$projectId/locations/$_llmLocation:translateText',
    );
    final body = _buildLlmRequestBody(translateList, parameters, projectId);
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final quotaProject = quotaProjectId?.trim();
    if (quotaProject != null && quotaProject.isNotEmpty) {
      headers['x-goog-user-project'] = quotaProject;
    }

    final response = await (client?.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        ) ??
        http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        ));

    if (response.statusCode != 200) {
      throw http.ClientException('Error ${response.statusCode}: ${response.body}', url);
    }

    return _extractV3Translations(response.body);
  }

  static Future<List<String>> _translateWithOpenAi(
    List<String> translateList,
    Map<String, dynamic> parameters, {
    http.Client? client,
    bool allowPerItemFallback = true,
  }) async {
    final apiKey = (parameters['key'] as String?)?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('API key is required when translation_service is "openai"');
    }

    final targetLanguage = (parameters['target'] as String?)?.trim();
    if (targetLanguage == null || targetLanguage.isEmpty) {
      throw ArgumentError('Target language is required when translation_service is "openai"');
    }

    final sourceLanguage = (parameters['source'] as String?)?.trim();
    final translationContext = (parameters['translation_context'] as String?)?.trim();
    final openAiModel = (parameters['openai_model'] as String?)?.trim();
    final preparedTexts = _prepareOpenAiTexts(translateList);
    final url = Uri.parse(_openAiChatCompletionsUrl);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await _callOpenAiChatCompletions(
            url: url,
            apiKey: apiKey,
            body: _buildOpenAiRequestBody(
              translateList: preparedTexts.promptTexts,
              targetLanguage: targetLanguage,
              sourceLanguage: sourceLanguage,
              translationContext: translationContext,
              model: openAiModel,
              expectedCount: translateList.length,
            strictRetryMode: attempt > 0,
            ),
            client: client,
          );

          final extracted = _extractOpenAiTranslations(
            response.body,
            expectedCount: translateList.length,
          );
          final restoredTranslations = _restoreOpenAiPlaceholders(
            extracted,
            preparedTexts.placeholderTokensByText,
          );
          _assertTranslationsLikelyLocalized(
            translations: restoredTranslations,
            promptTexts: preparedTexts.promptTexts,
            placeholderTokensByText: preparedTexts.placeholderTokensByText,
            targetLanguage: targetLanguage,
          );
          return restoredTranslations;
        } on FormatException catch (error) {
          final isFinalAttempt = attempt == 1;
          final isRecoverableError = _isOpenAiRecoverableFormatError(error);
          if (isFinalAttempt || !isRecoverableError) {
            rethrow;
          }
        }
      }
    } on FormatException catch (error) {
      final canFallback = allowPerItemFallback && translateList.length > 1;
      if (canFallback && _isOpenAiRecoverableFormatError(error)) {
        return _translateWithOpenAiPerItem(
          translateList: translateList,
          parameters: parameters,
          client: client,
        );
      }
      rethrow;
    }

    throw FormatException('OpenAI returned an invalid translation count after retry.');
  }

  static Future<String> _resolveOAuthAccessToken({
    required String authMode,
    String? credentialsFile,
    String? accessToken,
  }) async {
    final inlineAccessToken = accessToken?.trim();
    if (inlineAccessToken != null && inlineAccessToken.isNotEmpty) {
      return inlineAccessToken;
    }

    auth.AutoRefreshingAuthClient authClient;
    if (authMode == 'service_account') {
      final serviceAccountPath = (credentialsFile?.trim().isNotEmpty ?? false)
          ? credentialsFile!.trim()
          : (Platform.environment['GOOGLE_APPLICATION_CREDENTIALS']?.trim());

      if (serviceAccountPath == null || serviceAccountPath.isEmpty) {
        throw ArgumentError(
          'Service account credentials were not provided. '
          'Set --credentials_file or GOOGLE_APPLICATION_CREDENTIALS.',
        );
      }

      final credentialsFileRef = File(serviceAccountPath);
      if (!credentialsFileRef.existsSync()) {
        throw ArgumentError('Service account credentials file not found: $serviceAccountPath');
      }

      final credentialsJson = jsonDecode(credentialsFileRef.readAsStringSync());
      final serviceAccountCredentials = auth.ServiceAccountCredentials.fromJson(credentialsJson);
      authClient = await auth.clientViaServiceAccount(
        serviceAccountCredentials,
        [_cloudPlatformScope],
      );
    } else {
      authClient = await auth.clientViaApplicationDefaultCredentials(
        scopes: [_cloudPlatformScope],
      );
    }

    final token = authClient.credentials.accessToken.data;
    authClient.close();
    return token;
  }

  static Map<String, dynamic> _buildLlmRequestBody(
    List<String> translateList,
    Map<String, dynamic> parameters,
    String projectId,
  ) {
    final targetLanguage = parameters['target'] as String;
    final body = <String, dynamic>{
      'contents': translateList,
      'targetLanguageCode': targetLanguage,
      'mimeType': 'text/html',
      'model': 'projects/$projectId/locations/$_llmLocation/models/$_llmModelId',
    };

    if (parameters.containsKey('source')) {
      body['sourceLanguageCode'] = parameters['source'] as String;
    }
    return body;
  }

  static Map<String, dynamic> _buildOpenAiRequestBody({
    required List<String> translateList,
    required String targetLanguage,
    required String? sourceLanguage,
    required String? translationContext,
    required String? model,
    required int expectedCount,
    required bool strictRetryMode,
  }) {
    final systemPrompt = StringBuffer()
      ..writeln('You are a professional localization translator for ARB resources.')
      ..writeln('Translate each input string to the requested target language.')
      ..writeln(
          'Preserve line breaks, punctuation, spacing, and any HTML tags exactly when they should not change meaning.')
      ..writeln(
          'Placeholder tokens follow the pattern "__SMART_ARB_PH_<number>__". Never translate, alter, remove, or reorder these tokens.')
      ..writeln('Do not add or remove items, and keep the same order as the input list.')
      ..writeln('The "translations" array length must be exactly $expectedCount.')
      ..writeln('Return strict JSON only in the format {"translations":["..."]}.');

    if (strictRetryMode) {
      systemPrompt
        ..writeln()
        ..writeln('Critical: Your previous output violated constraints.')
        ..writeln('Return exactly $expectedCount translations and nothing else.')
        ..writeln('Preserve every placeholder token exactly (no edits or omissions).');
    }

    if (translationContext != null && translationContext.isNotEmpty) {
      systemPrompt
        ..writeln()
        ..writeln('Translation context and style guide:')
        ..writeln(translationContext);
    }

    final userPayload = <String, dynamic>{
      'target_language': targetLanguage,
      'texts': translateList,
    };

    if (sourceLanguage != null && sourceLanguage.isNotEmpty) {
      userPayload['source_language'] = sourceLanguage;
    }

    return <String, dynamic>{
      'model': (model != null && model.isNotEmpty) ? model : _openAiDefaultModel,
      'temperature': 0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': systemPrompt.toString().trim()},
        {'role': 'user', 'content': jsonEncode(userPayload)},
      ],
    };
  }

  static List<String> _extractV3Translations(String responseBody) {
    final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
    final translations = List<Map<String, dynamic>>.from(
      jsonData['translations'] as Iterable,
    );
    return translations.map((t) => t['translatedText'] as String).toList();
  }

  static List<String> _extractOpenAiTranslations(
    String responseBody, {
    required int expectedCount,
  }) {
    final responseJson = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = List<Map<String, dynamic>>.from(responseJson['choices'] as List<dynamic>? ?? const []);
    if (choices.isEmpty) {
      throw const FormatException('OpenAI response did not contain any choices.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final rawContent = message?['content'];
    if (rawContent == null) {
      throw const FormatException('OpenAI response did not contain message content.');
    }

    String content;
    if (rawContent is String) {
      content = rawContent;
    } else if (rawContent is List) {
      final textParts =
          rawContent.map((part) => part is Map<String, dynamic> ? part['text'] : null).whereType<String>().join();
      content = textParts;
    } else {
      throw const FormatException('OpenAI response content had an unexpected type.');
    }

    final normalizedContent = _stripJsonCodeFence(content.trim());
    final parsedContent = jsonDecode(normalizedContent) as Map<String, dynamic>;
    var translations = List<String>.from(
      (parsedContent['translations'] as List<dynamic>? ?? const []).map((item) => item.toString()),
    );
    translations = _normalizeOpenAiTranslationCount(translations, expectedCount);

    if (translations.length != expectedCount) {
      throw FormatException(
        'OpenAI returned ${translations.length} translations, expected $expectedCount.',
      );
    }

    return translations;
  }

  static String _stripJsonCodeFence(String content) {
    if (!content.startsWith('```')) {
      return content;
    }

    final withoutOpening = content.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    return withoutOpening.replaceFirst(RegExp(r'\s*```$'), '');
  }

  static List<String> _normalizeOpenAiTranslationCount(
    List<String> translations,
    int expectedCount,
  ) {
    if (translations.length == expectedCount) {
      return translations;
    }
    if (translations.length <= expectedCount) {
      return translations;
    }

    final withoutEmptyEntries = translations.where((item) => item.trim().isNotEmpty).toList();
    if (withoutEmptyEntries.length == expectedCount) {
      return withoutEmptyEntries;
    }
    return translations;
  }

  static bool _isOpenAiCountMismatchError(FormatException error) {
    return error.message.startsWith('OpenAI returned ');
  }

  static bool _isOpenAiPlaceholderError(FormatException error) {
    return error.message.startsWith('OpenAI response modified placeholder token');
  }

  static bool _isOpenAiUntranslatedError(FormatException error) {
    return error.message.startsWith('OpenAI left source text untranslated in translation item');
  }

  static bool _isOpenAiRecoverableFormatError(FormatException error) {
    return _isOpenAiCountMismatchError(error) ||
        _isOpenAiPlaceholderError(error) ||
        _isOpenAiUntranslatedError(error);
  }

  static Future<List<String>> _translateWithOpenAiPerItem({
    required List<String> translateList,
    required Map<String, dynamic> parameters,
    required http.Client? client,
  }) async {
    final translated = <String>[];
    for (final text in translateList) {
      final singleResult = await _translateWithOpenAi(
        [text],
        parameters,
        client: client,
        allowPerItemFallback: false,
      );
      translated.add(singleResult.first);
    }
    return translated;
  }

  static Future<http.Response> _callOpenAiChatCompletions({
    required Uri url,
    required String apiKey,
    required Map<String, dynamic> body,
    required http.Client? client,
  }) async {
    final response = await (client?.post(
          url,
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ) ??
        http.post(
          url,
          headers: <String, String>{
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ));

    if (response.statusCode != 200) {
      throw http.ClientException('Error ${response.statusCode}: ${response.body}', url);
    }
    return response;
  }

  static _OpenAiPreparedTexts _prepareOpenAiTexts(List<String> translateList) {
    final promptTexts = <String>[];
    final placeholderTokensByText = <Map<String, String>>[];

    for (final text in translateList) {
      var workingText = text;
      final outerSpanMatch = _openAiOuterSpanRegex.firstMatch(workingText);
      if (outerSpanMatch != null) {
        workingText = outerSpanMatch.group(1)!;
      }

      var tokenIndex = 0;
      final tokenMap = <String, String>{};
      workingText = workingText.replaceAllMapped(_openAiNoTranslateRegex, (match) {
        final placeholderName = match.group(1) ?? '';
        final token = '$_openAiPlaceholderTokenPrefix$tokenIndex$_openAiPlaceholderTokenSuffix';
        tokenMap[token] = placeholderName;
        tokenIndex++;
        return token;
      });

      promptTexts.add(workingText);
      placeholderTokensByText.add(tokenMap);
    }

    return _OpenAiPreparedTexts(
      promptTexts: promptTexts,
      placeholderTokensByText: placeholderTokensByText,
    );
  }

  static List<String> _restoreOpenAiPlaceholders(
    List<String> translations,
    List<Map<String, String>> placeholderTokensByText,
  ) {
    if (translations.length != placeholderTokensByText.length) {
      throw FormatException(
        'OpenAI returned ${translations.length} translations for ${placeholderTokensByText.length} inputs.',
      );
    }

    final restoredTranslations = <String>[];
    for (var i = 0; i < translations.length; i++) {
      var translation = _normalizeOpenAiPlaceholderTokens(translations[i]);
      final placeholderTokenMap = placeholderTokensByText[i];
      _assertKnownOpenAiPlaceholders(
        translation: translation,
        expectedTokens: placeholderTokenMap.keys,
        itemIndex: i,
      );

      for (final token in placeholderTokenMap.keys) {
        if (!translation.contains(token)) {
          throw FormatException(
            'OpenAI response modified placeholder token "$token" in translation item ${i + 1}.',
          );
        }
      }

      placeholderTokenMap.forEach((token, placeholderName) {
        translation = translation.replaceAll(token, '{$placeholderName}');
      });

      restoredTranslations.add(translation);
    }

    return restoredTranslations;
  }

  static void _assertTranslationsLikelyLocalized({
    required List<String> translations,
    required List<String> promptTexts,
    required List<Map<String, String>> placeholderTokensByText,
    required String targetLanguage,
  }) {
    final normalizedTargetLanguage = targetLanguage.trim().toLowerCase();
    if (normalizedTargetLanguage == 'en' ||
        normalizedTargetLanguage.startsWith('en-') ||
        normalizedTargetLanguage.startsWith('en_')) {
      return;
    }

    for (var i = 0; i < translations.length; i++) {
      final restoredSource = _restorePromptPlaceholders(
        promptTexts[i],
        placeholderTokensByText[i],
      );
      if (_looksLikelyUntranslated(
        sourceText: restoredSource,
        translatedText: translations[i],
      )) {
        throw FormatException(
          'OpenAI left source text untranslated in translation item ${i + 1}.',
        );
      }
    }
  }

  static String _restorePromptPlaceholders(
    String promptText,
    Map<String, String> placeholderTokenMap,
  ) {
    var restored = promptText;
    placeholderTokenMap.forEach((token, placeholderName) {
      restored = restored.replaceAll(token, '{$placeholderName}');
    });
    return restored;
  }

  static bool _looksLikelyUntranslated({
    required String sourceText,
    required String translatedText,
  }) {
    final normalizedSource = _normalizeComparisonText(sourceText);
    final normalizedTranslation = _normalizeComparisonText(translatedText);
    if (normalizedSource.isEmpty || normalizedSource != normalizedTranslation) {
      return false;
    }

    final sourceWithoutPlaceholders = sourceText.replaceAll(_comparisonPlaceholderRegex, ' ');
    final englishWords = _englishWordRegex
        .allMatches(sourceWithoutPlaceholders)
        .map((match) => match.group(0)!)
        .toList();

    return englishWords.length >= 3;
  }

  static String _normalizeComparisonText(String text) {
    return text.replaceAll(_comparisonWhitespaceRegex, ' ').trim();
  }

  static String _normalizeOpenAiPlaceholderTokens(String translation) {
    return translation.replaceAllMapped(_openAiPlaceholderVariantRegex, (match) {
      final tokenIndex = match.group(1);
      return '$_openAiPlaceholderTokenPrefix$tokenIndex$_openAiPlaceholderTokenSuffix';
    });
  }

  static void _assertKnownOpenAiPlaceholders({
    required String translation,
    required Iterable<String> expectedTokens,
    required int itemIndex,
  }) {
    final expectedTokenSet = expectedTokens.toSet();
    if (expectedTokenSet.isEmpty) {
      return;
    }

    final actualTokenSet = _openAiCanonicalPlaceholderRegex
        .allMatches(translation)
        .map((match) => match.group(0))
        .whereType<String>()
        .toSet();
    final unexpectedTokens = actualTokenSet.difference(expectedTokenSet);

    if (unexpectedTokens.isNotEmpty) {
      throw FormatException(
        'OpenAI response returned unexpected placeholder token(s) '
        '${unexpectedTokens.join(', ')} in translation item ${itemIndex + 1}.',
      );
    }
  }

  /// Inserts manual translations from ARB document attributes into translation results.
  ///
  /// This method checks for manual translations stored in the `x-translations` attribute
  /// of ARB resources and replaces automatic translations with manual ones when available.
  ///
  /// Parameters:
  /// - [translationsLists]: List of translation result lists from the API
  /// - [actionLists]: List of action lists corresponding to the translations
  /// - [languageCode]: Target language code to look for in manual translations
  /// - [arbDocument]: Source ARB document containing manual translation overrides
  ///
  /// Returns updated translation lists with manual translations inserted where available.
  static List<List<String>> insertManualTranslations(List<List<String>> translationsLists,
      List<List<Action>> actionLists, String languageCode, ArbDocument arbDocument) {
    List<List<String>> updatedTranslationsLists = [];

    for (var i = 0; i < translationsLists.length; i++) {
      final updatedTranslations = <String>[];
      updatedTranslationsLists.add(updatedTranslations);
      final translations = translationsLists[i];

      for (var j = 0; j < translations.length; j++) {
        final translation = translations[j];
        final resourceId = actionLists[i][j].resourceId;
        final arbResource = arbDocument.resources[resourceId];
        final xTranslations = arbResource?.attributes?.xTranslations;
        if (xTranslations != null && xTranslations[languageCode] != null) {
          updatedTranslations.add(xTranslations[languageCode] as String);
        } else {
          updatedTranslations.add(translation);
        }
      }
    }
    return updatedTranslationsLists;
  }

  /// Applies whole-resource manual translations from `x-translations`.
  ///
  /// ARB manual translations are defined on the resource metadata, not on
  /// individual ICU/plural tokens. Applying them token-by-token can corrupt
  /// plural/select messages by inserting the full translated resource into each
  /// branch. This helper applies those overrides once per resource after any
  /// token-level translation work has completed.
  static ArbDocument applyManualTranslationsToDocument({
    required ArbDocument translatedDocument,
    required String languageCode,
    required ArbDocument sourceDocument,
  }) {
    final updatedResources = <String, ArbResource>{...translatedDocument.resources};

    for (final entry in sourceDocument.resources.entries) {
      final manualTranslation = entry.value.attributes?.xTranslations?[languageCode];
      if (manualTranslation is! String || manualTranslation.isEmpty) {
        continue;
      }

      final existingResource = updatedResources[entry.key] ?? entry.value;
      updatedResources[entry.key] = existingResource.copyWith(text: manualTranslation);
    }

    return translatedDocument.copyWith(resources: updatedResources);
  }

  /// Sanitizes a translated string by removing HTML entities and tags.
  ///
  /// This method handles HTML unescaping and removes HTML tags that may be
  /// introduced during the translation process.
  ///
  /// Parameters:
  /// - [translation]: The translated string to sanitize
  ///
  /// Returns a cleaned string with HTML entities decoded and tags removed.
  static String sanitizeTranslation(String translation) {
    final unescape = HtmlUnescape();
    return unescape.convert(
      translation.contains('<') ? removeHtml(translation) : translation,
    );
  }
}

/// Represents a translation action for a specific text segment within an ARB resource.
///
/// An Action encapsulates the information needed to translate a specific piece of text
/// and update the corresponding ARB resource with the translation result.
///
/// This class is used internally by the translation system to track which parts of
/// ARB resources need translation and how to apply the translated results back to
/// the original resource structure.
class Action {
  /// Function that updates an ARB resource with a translated text.
  ///
  /// This function takes the translated text and the current text of the resource,
  /// and returns a new [ArbResource] with the translation applied at the correct position.
  final ArbResource Function(String translation, String currentText) updateFunction;

  /// The original text content to be translated.
  ///
  /// This text may be HTML-encoded if it contains ICU message format placeholders
  /// or other special characters that need to be preserved during translation.
  final String text;

  /// The unique identifier of the ARB resource this action belongs to.
  ///
  /// This ID corresponds to the key in the ARB file and is used to locate
  /// the correct resource when applying translation updates.
  final String resourceId;

  /// Creates a new translation action.
  ///
  /// Parameters:
  /// - [updateFunction]: Function to apply the translation to the ARB resource
  /// - [resourceId]: Unique identifier of the target ARB resource
  /// - [text]: Original text content to be translated
  const Action({
    required this.updateFunction,
    required this.resourceId,
    required this.text,
  });
}

class _OpenAiPreparedTexts {
  final List<String> promptTexts;
  final List<Map<String, String>> placeholderTokensByText;

  const _OpenAiPreparedTexts({
    required this.promptTexts,
    required this.placeholderTokensByText,
  });
}
