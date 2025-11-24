import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/utils.dart';

/// Service class for handling translation operations using Google Translate API.
///
/// This class provides static methods for translating text content and managing
/// translation workflows for ARB (Application Resource Bundle) files.
class TranslationService {
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
    http.Client? client,
  }) async {
    switch (translationService) {
      case 'google_nmt':
        return _translateWithNMT(translateList, parameters, client: client);
      case 'google_llm':
        if (projectId == null) {
          throw ArgumentError('Project ID is required for LLM translation service');
        }
        return _translateWithLLM(translateList, parameters, projectId, client: client);
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
    final translated = <String>[];
    parameters['q'] = translateList;

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2')
        .resolveUri(Uri(queryParameters: parameters));

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
    http.Client? client,
  }) async {
    // LLM uses the v3 API
    // Endpoint: https://translation.googleapis.com/v3/projects/{project-id}/locations/global:translateText

    final apiKey = parameters['key'] as String;
    final targetLanguage = parameters['target'] as String;
    // v3 uses 'sourceLanguageCode' and 'targetLanguageCode' instead of 'source' and 'target'
    // But 'source' is optional in v2 and often inferred. If we have it, we should pass it.
    // The current implementation doesn't seem to pass 'source' explicitly in parameters usually,
    // but if it's there, we use it.

    final url = Uri.parse(
        'https://translation.googleapis.com/v3/projects/$projectId/locations/global:translateText?key=$apiKey');

    final body = {
      'contents': translateList,
      'targetLanguageCode': targetLanguage,
      'mimeType': 'text/html', // We use HTML for safety in ArbProcessor
    };

    if (parameters.containsKey('source')) {
      body['sourceLanguageCode'] = parameters['source'] as String;
    }

    // For "LLM" quality, we might want to specify a model if available,
    // but standard v3 is already NMT/Advanced.
    // If there's a specific model for LLM, we'd add it here.
    // For now, v3 is the "advanced" option.

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

    final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
    final translations = List<Map<String, dynamic>>.from(
      jsonData['translations'] as Iterable,
    );

    return translations.map((t) => t['translatedText'] as String).toList();
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
