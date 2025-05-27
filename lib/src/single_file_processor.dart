import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/arb_processor.dart';
import 'package:smart_arb_translator/src/dart_code_generator.dart';
import 'package:smart_arb_translator/src/file_operations.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/translation_service.dart';
import 'package:smart_arb_translator/src/translation_statistics.dart';

/// Processor for handling single ARB file translation workflows.
///
/// This class provides functionality for processing individual ARB files,
/// including smart change detection, translation, and optional Dart code generation.
/// It's designed for projects with single ARB files or when processing files individually.
///
/// The processor handles:
/// - Single file translation with change detection
/// - Intelligent caching to avoid unnecessary re-translation
/// - Comparison with previous file versions
/// - Integration with translation statistics
/// - Dart code generation for single-file workflows
/// - Proper file naming and organization
///
/// Example usage:
/// ```dart
/// await SingleFileProcessor.processSingleFile(
///   'lib/l10n/app_en.arb',
///   ['es', 'fr', 'de'],
///   'path/to/api_key.txt',
///   'lib/l10n',
///   'app_',
///   generateDart: true,
///   dartClassName: 'AppLocalizations',
/// );
/// ```
class SingleFileProcessor {
  /// Processes a single ARB file for translation.
  ///
  /// This method handles the complete single-file translation workflow,
  /// including change detection, translation, and optional Dart code generation.
  /// It creates a cache copy of the source file for future change detection.
  ///
  /// The process includes:
  /// 1. Reading and caching the source file
  /// 2. Comparing with previous versions for change detection
  /// 3. Translating only changed or new content
  /// 4. Generating output files for each target language
  /// 5. Creating temporary l10n structure for Dart generation
  /// 6. Generating Dart localization code (optional)
  /// 7. Reporting translation statistics
  ///
  /// Parameters:
  /// - [sourceArb]: Path to the source ARB file to translate
  /// - [languageCodes]: List of target language codes for translation
  /// - [apiKey]: Google Translate API key for translation service
  /// - [outputDirectory]: Directory for output files (optional, defaults to source directory)
  /// - [outputFileName]: Prefix for output file names
  /// - [generateDart]: Whether to generate Dart localization code
  /// - [dartClassName]: Name for the generated Dart class
  /// - [dartOutputDir]: Directory for generated Dart files
  /// - [dartMainLocale]: Main locale for Dart code generation
  /// - [autoApprove]: Whether to automatically approve setup changes
  /// - [l10nMethod]: Localization method ('gen-l10n', 'intl_utils', or 'none')
  /// - [useDeferredLoading]: Whether to enable deferred loading for locales
  ///
  /// Returns a [Future<void>] that completes when processing is finished.
  ///
  /// Example:
  /// ```dart
  /// await SingleFileProcessor.processSingleFile(
  ///   'lib/l10n/messages_en.arb',
  ///   ['es', 'fr', 'de', 'ja'],
  ///   'secrets/api_key.txt',
  ///   'lib/l10n',
  ///   'messages_',
  ///   generateDart: true,
  ///   dartClassName: 'Messages',
  ///   dartOutputDir: 'lib/generated',
  ///   dartMainLocale: 'en',
  ///   l10nMethod: 'gen-l10n',
  ///   useDeferredLoading: false,
  /// );
  /// ```
  static Future<void> processSingleFile(
    String sourceArb,
    List<String> languageCodes,
    String apiKey,
    String? outputDirectory,
    String outputFileName, {
    bool generateDart = false,
    String? dartClassName,
    String dartOutputDir = 'lib/generated',
    String dartMainLocale = 'en',
    bool autoApprove = false,
    String? l10nMethod,
    bool useDeferredLoading = false,
  }) async {
    dartClassName ??= (l10nMethod == 'gen-l10n') ? 'AppLocalizations' : 'S';
    final arbFile = FileOperations.createFileRef(sourceArb);
    final workingOutputDirectory = outputDirectory ?? arbFile.path.substring(0, arbFile.path.lastIndexOf('/') + 1);

    // Check for existing cached source file for change detection
    final sourceFileBaseName = path.basename(arbFile.path);
    final cachedSourcePath = path.join(workingOutputDirectory, sourceFileBaseName);

    ArbDocument? previousSourceDocument;
    if (File(cachedSourcePath).existsSync()) {
      print('Reading existing cached source file for change detection...');
      try {
        final cachedContent = File(cachedSourcePath).readAsStringSync();
        previousSourceDocument = ArbDocument.decode(cachedContent);
      } catch (e) {
        print('Warning: Could not parse existing cached source file: $cachedSourcePath');
      }
    }

    // Copy source file to cache directory for consistency and future change detection
    print('Copying source file to cache directory...');
    await File(cachedSourcePath).create(recursive: true);
    await arbFile.copy(cachedSourcePath);
    print('Source file copied to: $cachedSourcePath');

    // Initialize statistics tracking
    final statistics = TranslationStatistics();

    // Get source file info for filename construction
    final sourceFileName = path.basename(arbFile.path);
    final sourceFileNameWithoutExt = path.basenameWithoutExtension(sourceFileName);
    final sourceFileExt = path.extension(sourceFileName);

    for (final languageCode in languageCodes) {
      // Construct proper output filename with language code and extension
      final finalOutputFileName = outputFileName.isEmpty
          ? '${sourceFileNameWithoutExt}_$languageCode$sourceFileExt'
          : outputFileName.endsWith('.arb')
              ? '${outputFileName.substring(0, outputFileName.length - 4)}_$languageCode.arb'
              : '$outputFileName$languageCode.arb';

      // Use the smart change detection processing
      await processSingleFileWithChanges(
        cachedSourcePath,
        [languageCode],
        apiKey,
        workingOutputDirectory,
        finalOutputFileName,
        previousSourceDocument,
        statistics,
      );
    }

    // Print translation statistics
    statistics.printSummary();

    // Generate Dart code if requested
    if (generateDart) {
      print('\n🔧 Starting Dart code generation...');

      // For single file processing, we need to create a temporary directory structure
      // that intl_utils can work with
      final tempL10nDir = path.join(workingOutputDirectory, 'temp_l10n');
      await Directory(tempL10nDir).create(recursive: true);

      // Copy the generated files to the temp directory with intl_ prefix
      for (final languageCode in languageCodes) {
        final sourceFile = path.join(workingOutputDirectory, '${sourceFileNameWithoutExt}_$languageCode$sourceFileExt');
        final targetFile = path.join(tempL10nDir, 'intl_$languageCode.arb');

        if (File(sourceFile).existsSync()) {
          await File(sourceFile).copy(targetFile);
        }
      }

      // Also copy the source file as the main locale
      final mainLocaleFile = path.join(tempL10nDir, 'intl_$dartMainLocale.arb');
      if (!File(mainLocaleFile).existsSync()) {
        await arbFile.copy(mainLocaleFile);
      }

      // Validate ARB files exist
      final isValid = await DartCodeGenerator.validateArbFiles(
        arbDirectory: tempL10nDir,
        languageCodes: languageCodes,
        mainLocale: dartMainLocale,
      );

      if (isValid) {
        await DartCodeGenerator.generateDartCode(
          arbDirectory: tempL10nDir,
          outputDirectory: dartOutputDir,
          className: dartClassName,
          mainLocale: dartMainLocale,
          languageCodes: languageCodes,
          autoApprove: autoApprove,
          l10nMethod: l10nMethod,
          useDeferredLoading: useDeferredLoading,
        );

        // Clean up temporary directory
        await Directory(tempL10nDir).delete(recursive: true);
      } else {
        print('⚠️  Skipping Dart code generation due to validation errors');
      }
    }
  }

  /// Processes a single ARB file with intelligent change detection.
  ///
  /// This method performs the core translation logic with smart change detection,
  /// comparing the current source file with a previous version to determine
  /// which keys need translation. It only translates new or changed content,
  /// significantly reducing API calls and processing time.
  ///
  /// The change detection logic:
  /// 1. Compares current source with previous cached version
  /// 2. Identifies new keys that don't exist in previous version
  /// 3. Detects changed text content in existing keys
  /// 4. Checks for modified attributes (descriptions, placeholders)
  /// 5. Preserves existing translations for unchanged content
  /// 6. Updates translation statistics
  ///
  /// Parameters:
  /// - [sourceArbPath]: Path to the source ARB file
  /// - [languageCodes]: List of target language codes
  /// - [apiKey]: Google Translate API key
  /// - [outputDirectory]: Directory for output files
  /// - [outputFileName]: Name of the output file
  /// - [previousSourceDocument]: Previous version of source for comparison (optional)
  /// - [statistics]: Translation statistics tracker (optional)
  ///
  /// Returns a [Future<void>] that completes when processing is finished.
  ///
  /// Example:
  /// ```dart
  /// await SingleFileProcessor.processSingleFileWithChanges(
  ///   'lib/l10n/app_en.arb',
  ///   ['es'],
  ///   'api_key.txt',
  ///   'lib/l10n',
  ///   'app_es.arb',
  ///   previousSourceDocument,
  ///   statistics,
  /// );
  /// ```
  static Future<void> processSingleFileWithChanges(
    String sourceArbPath,
    List<String> languageCodes,
    String apiKey,
    String outputDirectory,
    String outputFileName,
    ArbDocument? previousSourceDocument,
    TranslationStatistics? statistics,
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
        // Track translated content
        statistics?.addTranslated(resource.text);
      } else {
        // Track cached content (keys that were skipped)
        statistics?.addCached(resource.text);
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
