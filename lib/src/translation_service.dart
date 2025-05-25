import 'dart:convert';

import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/utils.dart';

class TranslationService {
  static Future<List<String>> translateTexts({
    required List<String> translateList,
    required Map<String, dynamic> parameters,
  }) async {
    final translated = <String>[];

    parameters['q'] = translateList;

    final url = Uri.parse('https://translation.googleapis.com/language/translate/v2')
        .resolveUri(Uri(queryParameters: parameters));

    final data = await http.get(url);

    if (data.statusCode != 200) {
      throw http.ClientException('Error ${data.statusCode}: ${data.body}', url);
    } else {
      // TO DO: We should use `googleapis` to deserialize this. We might also use translate v3.
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

  static String sanitizeTranslation(String translation) {
    final unescape = HtmlUnescape();
    return unescape.convert(
      translation.contains('<') ? removeHtml(translation) : translation,
    );
  }
}

class Action {
  final ArbResource Function(String translation, String currentText) updateFunction;

  final String text;

  final String resourceId;

  const Action({
    required this.updateFunction,
    required this.resourceId,
    required this.text,
  });
}
