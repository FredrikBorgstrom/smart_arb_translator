import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/arb_processor.dart';
import 'package:smart_arb_translator/src/file_operations.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/translation_service.dart';

class SingleFileProcessor {
  static Future<void> processSingleFile(
    String sourceArb,
    List<String> languageCodes,
    String apiKey,
    String? outputDirectory,
    String outputFileName,
    bool appendLangCode,
  ) async {
    final arbFile = FileOperations.createFileRef(sourceArb);
    final src = arbFile.readAsStringSync();
    final arbDocument = ArbDocument.decode(src);

    outputDirectory ??= arbFile.path.substring(0, arbFile.path.lastIndexOf('/') + 1);

    final actionLists = ArbProcessor.createActionLists(arbDocument);

    for (final languageCode in languageCodes) {
      print('• Processing for $languageCode');

      await ArbProcessor.createArbFile(
        languageCode: languageCode,
        arbDocument: arbDocument,
        actionLists: actionLists,
        outputDirectory: outputDirectory,
        outputFileName: outputFileName,
        apiKey: apiKey,
      );
    }
  }

  static Future<void> processSingleFileWithChanges(
    String sourceArbPath,
    List<String> languageCodes,
    String apiKey,
    String outputDirectory,
    String outputFileName,
    bool appendLangCode,
    ArbDocument? previousSourceDocument,
  ) async {
    final sourceArbFile = File(sourceArbPath);
    final sourceContent = sourceArbFile.readAsStringSync();
    final sourceDocument = ArbDocument.decode(sourceContent);

    // Check if output file already exists
    final outputFilePath = path.join(outputDirectory, outputFileName);
    final outputFile = File(outputFilePath);

    ArbDocument? existingTranslation;
    if (outputFile.existsSync()) {
      try {
        final existingContent = outputFile.readAsStringSync();
        existingTranslation = ArbDocument.decode(existingContent);
      } catch (e) {
        print('Warning: Could not parse existing translation file: $outputFilePath');
      }
    }

    // Determine which keys need translation
    final keysToTranslate = <String, ArbResource>{};

    for (final entry in sourceDocument.resources.entries) {
      final key = entry.key;
      final resource = entry.value;

      // Check if this key needs translation
      bool needsTranslation = false;

      if (existingTranslation == null || !existingTranslation.resources.containsKey(key)) {
        // New key - needs translation
        needsTranslation = true;
        print('New key found: $key');
      } else if (previousSourceDocument != null && previousSourceDocument.resources.containsKey(key)) {
        // Check if the source text has changed compared to the previous version
        final previousResource = previousSourceDocument.resources[key]!;
        if (resource.text != previousResource.text) {
          needsTranslation = true;
          print('Changed key found: $key (text was: "${previousResource.text}", now: "${resource.text}")');
        } else if (!ArbProcessor.areAttributesEqual(resource.attributes, previousResource.attributes)) {
          // Check if attributes have changed
          needsTranslation = true;
          print('Changed key found: $key (attributes changed)');
        }
      } else if (previousSourceDocument != null && !previousSourceDocument.resources.containsKey(key)) {
        // Key exists in current source but not in previous source - it's new
        needsTranslation = true;
        print('New key found: $key');
      } else if (previousSourceDocument == null) {
        // No previous source file to compare with - translate everything
        needsTranslation = true;
        print('No previous source file - translating key: $key');
      }

      if (needsTranslation) {
        keysToTranslate[key] = resource;
      }
    }

    if (keysToTranslate.isEmpty) {
      print('No changes detected for ${path.basename(sourceArbPath)} - skipping translation');
      return;
    }

    print('Translating ${keysToTranslate.length} changed/new keys for ${path.basename(sourceArbPath)}');

    // Create a temporary document with only the keys that need translation
    final tempDocument = ArbDocument.empty(
      locale: sourceDocument.locale,
      appName: sourceDocument.appName,
      lastModified: sourceDocument.lastModified,
      resources: keysToTranslate,
    );

    final actionLists = ArbProcessor.createActionLists(tempDocument);

    for (final languageCode in languageCodes) {
      print('• Processing changes for $languageCode');

      // Start with existing translation or create new one
      var newArbDocument = existingTranslation?.copyWith(locale: languageCode) ??
          sourceDocument.copyWith(locale: languageCode, resources: {});

      if (actionLists.isNotEmpty) {
        final futuresList = actionLists.map((list) {
          return TranslationService.translateTexts(
            translateList: list.map((action) => action.text).toList(),
            parameters: <String, dynamic>{'target': languageCode, 'key': apiKey},
          );
        }).toList();

        var translateResults = await Future.wait(futuresList);

        translateResults =
            TranslationService.insertManualTranslations(translateResults, actionLists, languageCode, tempDocument);

        // Apply translations to the document
        for (var i = translateResults.length - 1; i >= 0; i--) {
          final translateList = translateResults[i];
          final actionList = actionLists[i];

          for (var j = translateList.length - 1; j >= 0; j--) {
            final action = actionList[j];
            final translation = translateList[j];
            final sanitizedTranslation = TranslationService.sanitizeTranslation(translation);

            // Update or add the resource
            final originalResource = keysToTranslate[action.resourceId]!;
            final translatedResource = action.updateFunction(
              sanitizedTranslation,
              originalResource.text,
            );

            newArbDocument = newArbDocument.copyWith(
              resources: newArbDocument.resources..[action.resourceId] = translatedResource,
            );
          }
        }
      }

      // Ensure all source keys are present (even if not translated)
      for (final entry in sourceDocument.resources.entries) {
        if (!newArbDocument.resources.containsKey(entry.key)) {
          newArbDocument = newArbDocument.copyWith(
            resources: newArbDocument.resources..[entry.key] = entry.value.copyWith(),
          );
        }
      }

      final file = await File(outputFilePath).create(recursive: true);
      await file.writeAsString(newArbDocument.encode());
    }
  }
}
