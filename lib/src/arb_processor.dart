import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/models/arb_attributes.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:smart_arb_translator/src/utils.dart';

/// Core processor for handling ARB (Application Resource Bundle) file operations.
///
/// This class provides static methods for processing ARB documents, creating
/// translation actions, generating translated ARB files, and comparing ARB attributes.
/// It serves as the main engine for the translation workflow.
///
/// The processor handles:
/// - Breaking down ARB resources into translatable segments
/// - Coordinating with translation services
/// - Applying translations back to ARB structure
/// - Managing translation batching for API efficiency
/// - Preserving ARB metadata and structure
class ArbProcessor {
  /// Creates lists of translation actions from an ARB document.
  ///
  /// This method analyzes all resources in the ARB document and creates
  /// [Action] objects for each translatable text segment. The actions are
  /// grouped into lists with a maximum number of words per list to optimize
  /// translation API calls.
  ///
  /// The method processes ICU message format tokens to identify translatable
  /// text while preserving placeholders and formatting. Text containing
  /// placeholders is HTML-encoded to protect special characters during translation.
  ///
  /// Parameters:
  /// - [arbDocument]: The source ARB document to process
  ///
  /// Returns a list of action lists, where each inner list contains up to 128 words
  /// worth of translation actions.
  ///
  /// Example:
  /// ```dart
  /// final actionLists = ArbProcessor.createActionLists(arbDocument);
  /// print('Created ${actionLists.length} batches for translation');
  /// ```
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

  /// Creates a translated ARB file for a specific language.
  ///
  /// This method orchestrates the complete translation process for a single
  /// target language. It translates all action lists using the translation
  /// service, applies manual translation overrides, and generates a new
  /// ARB file with the translated content.
  ///
  /// The process includes:
  /// 1. Translating text segments using Google Translate API
  /// 2. Applying manual translation overrides from x-translations
  /// 3. Sanitizing translated text to remove HTML artifacts
  /// 4. Updating ARB resources with translated content
  /// 5. Writing the final ARB file to disk
  ///
  /// Parameters:
  /// - [languageCode]: Target language code (e.g., 'es', 'fr', 'de')
  /// - [arbDocument]: Source ARB document to translate
  /// - [actionLists]: Pre-computed translation actions from [createActionLists]
  /// - [outputDirectory]: Directory where the translated ARB file will be saved
  /// - [outputFileName]: Name of the output ARB file
  /// - [apiKey]: Google Translate API key for translation service
  ///
  /// Returns a [Future] that completes when the ARB file has been created.
  ///
  /// Example:
  /// ```dart
  /// await ArbProcessor.createArbFile(
  ///   languageCode: 'es',
  ///   arbDocument: sourceDocument,
  ///   actionLists: actionLists,
  ///   outputDirectory: 'lib/l10n',
  ///   outputFileName: 'intl_es.arb',
  ///   apiKey: 'your-api-key',
  /// );
  /// ```
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

  /// Compares two ARB attributes for equality.
  ///
  /// This method performs a deep comparison of two [ArbAttributes] objects,
  /// checking all fields including descriptions, placeholders, x-translations,
  /// and resource types.
  ///
  /// The comparison handles null values correctly and performs deep equality
  /// checks on nested maps like placeholders and x-translations.
  ///
  /// Parameters:
  /// - [attr1]: First attributes object to compare
  /// - [attr2]: Second attributes object to compare
  ///
  /// Returns true if the attributes are equivalent, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// final areEqual = ArbProcessor.areAttributesEqual(
  ///   resource1.attributes,
  ///   resource2.attributes,
  /// );
  /// if (!areEqual) {
  ///   print('Attributes have changed');
  /// }
  /// ```
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

  /// Compares two placeholder maps for equality.
  ///
  /// This private helper method performs deep comparison of placeholder
  /// definitions, checking both the structure and content of nested maps.
  ///
  /// Parameters:
  /// - [placeholders1]: First placeholders map
  /// - [placeholders2]: Second placeholders map
  ///
  /// Returns true if the placeholder maps are equivalent.
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

  /// Compares two x-translations maps for equality.
  ///
  /// This private helper method compares manual translation override maps
  /// to determine if they contain the same translation data.
  ///
  /// Parameters:
  /// - [xTranslations1]: First x-translations map
  /// - [xTranslations2]: Second x-translations map
  ///
  /// Returns true if the x-translations maps are equivalent.
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
