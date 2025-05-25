import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/models/arb_attributes.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:smart_arb_translator/src/utils.dart';

class ArbProcessor {
  static List<List<Action>> createActionLists(ArbDocument arbDocument) {
    const maxWords = 128;
    final actionLists = <List<Action>>[];
    final actionList = <Action>[];

    for (final resource in arbDocument.resources.values) {
      final tokens = resource.tokens;

      for (final token in tokens) {
        final text = token.value as String;
        final htmlSafe = text.contains('{') ? toHtml(text) : text;

        actionList.add(
          Action(
            text: htmlSafe,
            resourceId: resource.id,
            updateFunction: (String translation, String currentText) {
              return resource.copyWith(
                text: currentText.replaceRange(
                  token.start,
                  token.stop,
                  translation,
                ),
              );
            },
          ),
        );

        if (actionList.length >= maxWords) {
          actionLists.add([...actionList]);
          actionList.clear();
        }
      }
    }

    if (actionList.isNotEmpty) {
      actionLists.add([...actionList]);
      actionList.clear();
    }
    return actionLists;
  }

  static Future<void> createArbFile({
    required String languageCode,
    required ArbDocument arbDocument,
    required List<List<Action>> actionLists,
    required String outputDirectory,
    required String outputFileName,
    required String apiKey,
  }) async {
    var newArbDocument = arbDocument.copyWith(locale: languageCode);

    final futuresList = actionLists.map((list) {
      return TranslationService.translateTexts(
        translateList: list.map((action) => action.text).toList(),
        parameters: <String, dynamic>{'target': languageCode, 'key': apiKey},
      );
    }).toList();

    var translateResults = await Future.wait(futuresList);

    translateResults =
        TranslationService.insertManualTranslations(translateResults, actionLists, languageCode, arbDocument);

    // This is reversed so that end operations replace contents in string
    // before the beginning ones.
    for (var i = translateResults.length - 1; i >= 0; i--) {
      final translateList = translateResults[i];
      final actionList = actionLists[i];

      for (var j = translateList.length - 1; j >= 0; j--) {
        final action = actionList[j];
        final translation = translateList[j];
        final sanitizedTranslation = TranslationService.sanitizeTranslation(translation);

        newArbDocument = newArbDocument.copyWith(
          resources: newArbDocument.resources
            ..update(
              action.resourceId,
              (resource) {
                final arbResource = action.updateFunction(
                  sanitizedTranslation,
                  resource.text,
                );

                return arbResource;
              },
            ),
        );
      }
    }

    final file = await File(
      path.join(outputDirectory, outputFileName),
    ).create(recursive: true);

    await file.writeAsString(newArbDocument.encode());
  }

  static bool areAttributesEqual(ArbAttributes? attr1, ArbAttributes? attr2) {
    if (attr1 == null && attr2 == null) {
      return true;
    }
    if (attr1 == null || attr2 == null) {
      return false;
    }

    // Compare description
    if (attr1.description != attr2.description) {
      return false;
    }

    // Compare placeholders
    if (!_arePlaceholdersEqual(attr1.placeholders, attr2.placeholders)) {
      return false;
    }

    // Compare x-translations
    if (!_areXTranslationsEqual(attr1.xTranslations, attr2.xTranslations)) {
      return false;
    }

    // Compare resource type
    if (attr1.resourceType != attr2.resourceType) {
      return false;
    }

    return true;
  }

  static bool _arePlaceholdersEqual(
      Map<String, Map<String, dynamic>>? placeholders1, Map<String, Map<String, dynamic>>? placeholders2) {
    if (placeholders1 == null && placeholders2 == null) {
      return true;
    }
    if (placeholders1 == null || placeholders2 == null) {
      return false;
    }
    if (placeholders1.length != placeholders2.length) {
      return false;
    }

    for (final entry in placeholders1.entries) {
      if (!placeholders2.containsKey(entry.key)) {
        return false;
      }
      final map1 = entry.value;
      final map2 = placeholders2[entry.key]!;

      if (map1.length != map2.length) {
        return false;
      }

      for (final innerEntry in map1.entries) {
        if (map2[innerEntry.key] != innerEntry.value) {
          return false;
        }
      }
    }

    return true;
  }

  static bool _areXTranslationsEqual(Map<String, dynamic>? xTranslations1, Map<String, dynamic>? xTranslations2) {
    if (xTranslations1 == null && xTranslations2 == null) {
      return true;
    }
    if (xTranslations1 == null || xTranslations2 == null) {
      return false;
    }
    if (xTranslations1.length != xTranslations2.length) {
      return false;
    }

    for (final entry in xTranslations1.entries) {
      if (xTranslations2[entry.key] != entry.value) {
        return false;
      }
    }

    return true;
  }
}
