import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:smart_arb_translator/src/dart_code_generator.dart';
import 'package:smart_arb_translator/src/arb_processor.dart';
import 'package:smart_arb_translator/src/codex_translation_service.dart';
import 'package:smart_arb_translator/src/concurrency.dart';
import 'package:smart_arb_translator/src/file_operations.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';
import 'package:smart_arb_translator/src/models/codex_options.dart';
import 'package:smart_arb_translator/src/models/google_resource_adapter.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/reviewed_overlay.dart';
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
    String translationService = 'google_basic',
    String? projectId,
    String authMode = 'api_key',
    String? credentialsFile,
    String? quotaProjectId,
    String openaiModel = 'gpt-4o-mini',
    String? translationContext,
    CodexOptions? codexOptions,
    LocalLlmOptions? localLlmOptions,
    int parallelTranslations = 1,
    String? reviewedTranslationsDir,
    bool manualOnly = false,
    http.Client? client,
    Set<String>? resourceKeyFilter,
  }) async {
    dartClassName ??= (l10nMethod == 'gen-l10n') ? 'AppLocalizations' : 'S';
    final arbFile = FileOperations.createFileRef(sourceArb);
    final workingOutputDirectory = outputDirectory ?? arbFile.path.substring(0, arbFile.path.lastIndexOf('/') + 1);

    // Check for existing cached source file for change detection
    final sourceFileBaseName = path.basename(arbFile.path);
    final cachedSourcePath = path.join(
      workingOutputDirectory,
      sourceFileBaseName,
    );

    ArbDocument? previousSourceDocument;
    if (File(cachedSourcePath).existsSync()) {
      print('Reading existing cached source file for change detection...');
      try {
        final cachedContent = File(cachedSourcePath).readAsStringSync();
        previousSourceDocument = ArbDocument.decode(cachedContent);
      } catch (e) {
        print(
          'Warning: Could not parse existing cached source file: $cachedSourcePath',
        );
      }
    }

    // Copy source file to cache directory for consistency and future change detection
    print('Copying source file to cache directory...');
    await File(cachedSourcePath).create(recursive: true);
    await arbFile.copy(cachedSourcePath);
    print('Source file copied to: $cachedSourcePath');

    final statistics = TranslationStatistics();

    final sourceFileName = path.basename(arbFile.path);
    final sourceFileNameWithoutExt = path.basenameWithoutExtension(
      sourceFileName,
    );
    final sourceFileExt = path.extension(sourceFileName);

    final effectiveParallelism = parallelTranslations < 1 ? 1 : parallelTranslations;
    if (effectiveParallelism > 1) {
      print(
        'Per-language parallelism: $effectiveParallelism concurrent translation requests',
      );
    }
    SkippedTranslations.clear();

    final translationLanguageCodes =
        languageCodes.where((languageCode) => !_isSameLocale(languageCode, dartMainLocale)).toList(growable: false);
    if (translationLanguageCodes.length != languageCodes.length) {
      print(
        'Protecting source locale "$dartMainLocale": skipping translation for matching language code(s).',
      );
    }

    Future<void> runForLanguage(String languageCode) async {
      final finalOutputFileName = _resolveSingleFileLanguageOutputName(
        outputFileName: outputFileName,
        languageCode: languageCode,
      );
      await processSingleFileWithChanges(
        cachedSourcePath,
        [languageCode],
        apiKey,
        workingOutputDirectory,
        finalOutputFileName,
        previousSourceDocument,
        statistics,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        codexOptions: codexOptions,
        localLlmOptions: localLlmOptions,
        reviewedTranslationsDir: reviewedTranslationsDir,
        manualOnly: manualOnly,
        preserveUnrelatedExistingResources: false,
        client: client,
        resourceKeyFilter: resourceKeyFilter,
      );
    }

    await forEachPooled(translationLanguageCodes, effectiveParallelism, runForLanguage);

    statistics.printSummary();
    SkippedTranslations.printSummary();

    // Generate Dart code if requested
    if (generateDart) {
      print('\n🔧 Starting Dart code generation...');

      // For single file processing, we need to create a temporary directory structure
      // that intl_utils can work with
      final tempL10nDir = path.join(workingOutputDirectory, 'temp_l10n');
      await Directory(tempL10nDir).create(recursive: true);

      // Copy the generated files to the temp directory with intl_ prefix.
      // The source locale is protected: it must come from the source ARB, not
      // from a cached/generated translation file that may be stale or polluted.
      for (final languageCode in languageCodes) {
        if (_isSameLocale(languageCode, dartMainLocale)) {
          continue;
        }
        final sourceFile = path.join(
          workingOutputDirectory,
          '${sourceFileNameWithoutExt}_$languageCode$sourceFileExt',
        );
        final targetFile = path.join(tempL10nDir, 'intl_$languageCode.arb');

        if (File(sourceFile).existsSync()) {
          await File(sourceFile).copy(targetFile);
        }
      }

      // Always copy the source file as the main locale, overwriting any stale
      // temp file that may have been copied from previous generated output.
      final mainLocaleFile = path.join(tempL10nDir, 'intl_$dartMainLocale.arb');
      await arbFile.copy(mainLocaleFile);

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
  /// Resources of [sourceArbPath] that still need a provider translation for
  /// [languageCode], i.e. those an all-locale Codex batch should cover.
  static List<TranslationResource> pendingProviderResources({
    required String sourceArbPath,
    required String languageCode,
    required String outputDirectory,
    required String outputFileName,
    required String translationService,
    String openaiModel = 'gpt-4o-mini',
    String? translationContext,
    CodexOptions? codexOptions,
    LocalLlmOptions? localLlmOptions,
    String? reviewedTranslationsDir,
    Set<String>? resourceKeyFilter,
  }) {
    final sourceDocument = ArbDocument.decode(File(sourceArbPath).readAsStringSync());
    final outputFilePath = path.join(outputDirectory, outputFileName);
    return _planLanguage(
      languageCode: languageCode,
      existingTranslation: _readExistingTranslation(outputFilePath),
      sourceDocument: sourceDocument,
      sourceTopic: path.basename(sourceArbPath),
      provenanceFile: File('$outputFilePath.provenance.json'),
      translationService: translationService,
      openaiModel: openaiModel,
      translationContext: translationContext,
      codexOptions: codexOptions,
      localLlmOptions: localLlmOptions,
      reviewedTranslationsDir: reviewedTranslationsDir,
      manualOnly: false,
      resourceKeyFilter: resourceKeyFilter,
    ).providerResources;
  }

  static ArbDocument? _readExistingTranslation(String outputFilePath) {
    final outputFile = File(outputFilePath);
    if (!outputFile.existsSync()) return null;
    try {
      return ArbDocument.decode(outputFile.readAsStringSync());
    } catch (e) {
      print('Warning: Could not parse existing translation file: $outputFilePath');
      return null;
    }
  }

  static Future<void> processSingleFileWithChanges(
    String sourceArbPath,
    List<String> languageCodes,
    String apiKey,
    String outputDirectory,
    String outputFileName,
    ArbDocument? previousSourceDocument,
    TranslationStatistics? statistics, {
    String translationService = 'google_basic',
    String? projectId,
    String authMode = 'api_key',
    String? credentialsFile,
    String? quotaProjectId,
    String openaiModel = 'gpt-4o-mini',
    String? translationContext,
    CodexOptions? codexOptions,
    LocalLlmOptions? localLlmOptions,
    int parallelTranslations = 1,
    String? reviewedTranslationsDir,
    bool manualOnly = false,
    bool preserveUnrelatedExistingResources = false,
    http.Client? client,
    Set<String>? resourceKeyFilter,
    Map<String, Map<String, String>>? prefetchedByLocale,
  }) async {
    final sourceArbFile = File(sourceArbPath);
    final sourceContent = sourceArbFile.readAsStringSync();
    final sourceDocument = ArbDocument.decode(sourceContent);

    final outputFilePath = path.join(outputDirectory, outputFileName);

    final existingTranslation = _readExistingTranslation(outputFilePath);

    final effectiveParallelism = parallelTranslations < 1 ? 1 : parallelTranslations;

    Future<void> translateLanguage(String languageCode) async {
      print('• Processing changes for $languageCode');
      final translated = await _translateLanguageForFile(
        languageCode: languageCode,
        existingTranslation: existingTranslation,
        sourceDocument: sourceDocument,
        sourceTopic: path.basename(sourceArbPath),
        provenanceFile: File('$outputFilePath.provenance.json'),
        apiKey: apiKey,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        codexOptions: codexOptions,
        localLlmOptions: localLlmOptions,
        reviewedTranslationsDir: reviewedTranslationsDir,
        manualOnly: manualOnly,
        preserveUnrelatedExistingResources: preserveUnrelatedExistingResources,
        client: client,
        resourceKeyFilter: resourceKeyFilter,
        prefetched: prefetchedByLocale?[languageCode],
      );
      final file = await File(outputFilePath).create(recursive: true);
      await file.writeAsString(translated.document.encode());
      await translated.writeProvenance();
    }

    await forEachPooled(languageCodes, effectiveParallelism, translateLanguage);
  }

  /// Works out which resources of [sourceDocument] already have a current
  /// translation for [languageCode] and which still need the provider.
  static _LanguagePlan _planLanguage({
    required String languageCode,
    required ArbDocument? existingTranslation,
    required ArbDocument sourceDocument,
    required String sourceTopic,
    required File provenanceFile,
    required String translationService,
    required String openaiModel,
    required String? translationContext,
    required CodexOptions? codexOptions,
    required LocalLlmOptions? localLlmOptions,
    required String? reviewedTranslationsDir,
    required bool manualOnly,
    required Set<String>? resourceKeyFilter,
  }) {
    final resources = sourceDocument.resources.values
        .map(
          (resource) => TranslationResource.fromArbResource(
            resource,
            sourceTopic: sourceTopic,
          ),
        )
        .toList(growable: false);
    final model = translationService == 'local_llm'
        ? (localLlmOptions?.model ?? '')
        : translationService == 'codex'
            ? (codexOptions?.cacheIdentity ?? '')
            : openaiModel;
    final endpointClass = translationService == 'local_llm'
        ? '${localLlmOptions?.endpoint.scheme}://${localLlmOptions?.endpoint.host}'
        : translationService == 'codex'
            ? 'codex-cli'
            : translationService == 'openai'
                ? 'https://api.openai.com'
                : 'google-translation-api';
    final promptVersion =
        translationService == 'codex' ? CodexTranslationService.promptVersion : TranslationFingerprint.algorithmVersion;
    final reviewed = ReviewedOverlay.load(
      rootDirectory: reviewedTranslationsDir,
      locale: languageCode,
      sourceFile: sourceTopic,
      resources: resources,
      translationContext: translationContext,
    );
    final previousProvenance = _readProvenance(provenanceFile);
    final resolved = <String, String>{};
    final providerResources = <TranslationResource>[];
    final missing = <MissingManualCoverage>[];
    final nextProvenance = <String, dynamic>{...previousProvenance};
    for (final resource in resources) {
      // Validate overlays against the complete source file, then scope work.
      // Otherwise valid unselected overlay keys look like unknown resources.
      if (resourceKeyFilter != null && !resourceKeyFilter.contains(resource.id)) continue;
      final sourceFingerprint = TranslationFingerprint.source(resource);
      final contextFingerprint = TranslationFingerprint.cacheContext(
        resource,
        translationContext: translationContext,
        provider: translationService,
        endpointClass: endpointClass,
        model: model,
        promptVersion: promptVersion,
      );
      final override = sourceDocument.resources[resource.id]!.attributes?.xTranslations?[languageCode];
      // A current reviewed overlay is the authoritative target. Embedded
      // x-translations are useful bootstrap input, but must not overwrite a
      // later independently reviewed correction.
      if (reviewed.translations.containsKey(resource.id)) {
        resolved[resource.id] = reviewed.translations[resource.id]!;
      } else if (override is String && override.trim().isNotEmpty) {
        resolved[resource.id] = override;
      } else {
        final record = previousProvenance[resource.id];
        final cached = existingTranslation?.resources[resource.id]?.text;
        if (cached != null &&
            record is Map<String, dynamic> &&
            record['sourceFingerprint'] == sourceFingerprint &&
            record['contextFingerprint'] == contextFingerprint) {
          resolved[resource.id] = cached;
        } else if (manualOnly) {
          missing.add(
            MissingManualCoverage(languageCode, sourceTopic, resource.id),
          );
        } else {
          providerResources.add(resource);
        }
      }
      nextProvenance[resource.id] = <String, dynamic>{
        'sourceFingerprint': sourceFingerprint,
        'contextFingerprint': contextFingerprint,
        'provider': translationService,
        'endpointClass': endpointClass,
        'model': model,
        'promptVersion': promptVersion,
        'sourceTopic': sourceTopic,
        'placeholderMetadata': resource.placeholders,
        'glossary': resource.glossary,
        'algorithmVersion': TranslationFingerprint.algorithmVersion,
      };
    }
    if (missing.isNotEmpty) throw ManualCoverageException(missing);
    return _LanguagePlan(resolved, providerResources, nextProvenance, previousProvenance);
  }

  static Future<_TranslatedFileResult> _translateLanguageForFile({
    required String languageCode,
    required ArbDocument? existingTranslation,
    required ArbDocument sourceDocument,
    required String sourceTopic,
    required File provenanceFile,
    required String apiKey,
    required String translationService,
    required String? projectId,
    required String authMode,
    required String? credentialsFile,
    required String? quotaProjectId,
    required String openaiModel,
    required String? translationContext,
    required CodexOptions? codexOptions,
    required LocalLlmOptions? localLlmOptions,
    required String? reviewedTranslationsDir,
    required bool manualOnly,
    required bool preserveUnrelatedExistingResources,
    required http.Client? client,
    required Set<String>? resourceKeyFilter,
    Map<String, String>? prefetched,
  }) async {
    final plan = _planLanguage(
      languageCode: languageCode,
      existingTranslation: existingTranslation,
      sourceDocument: sourceDocument,
      sourceTopic: sourceTopic,
      provenanceFile: provenanceFile,
      translationService: translationService,
      openaiModel: openaiModel,
      translationContext: translationContext,
      codexOptions: codexOptions,
      localLlmOptions: localLlmOptions,
      reviewedTranslationsDir: reviewedTranslationsDir,
      manualOnly: manualOnly,
      resourceKeyFilter: resourceKeyFilter,
    );
    final resolved = plan.resolved;
    final nextProvenance = plan.nextProvenance;
    var providerResources = plan.providerResources;
    if (prefetched != null && providerResources.isNotEmpty) {
      // Already translated for this locale by an all-locale Codex batch run.
      for (final resource in providerResources) {
        final translation = prefetched[resource.id];
        if (translation != null) {
          resolved[resource.id] = TranslationService.sanitizeTranslation(translation);
        }
      }
      providerResources =
          providerResources.where((resource) => !resolved.containsKey(resource.id)).toList(growable: false);
    }
    if (providerResources.isNotEmpty) {
      if (translationService == 'openai' || translationService == 'local_llm' || translationService == 'codex') {
        List<TranslationResult> results;
        var localeSkipped = false;
        try {
          results = await TranslationService.translateResources(
            resources: providerResources,
            parameters: <String, dynamic>{
              'target': languageCode,
              'source': sourceDocument.locale,
              'key': apiKey,
              'openai_model': openaiModel,
              'translation_context': translationContext,
            },
            translationService: translationService,
            codexOptions: codexOptions,
            localLlmOptions: localLlmOptions,
            client: client,
          );
        } on CodexLocaleUnavailable catch (error) {
          // Keep the previous (or source) text, and restore the previous
          // provenance so the next run sees these resources as still pending.
          SkippedTranslations.record(languageCode, sourceTopic, providerResources.map((r) => r.id), error);
          for (final resource in providerResources) {
            final previous = plan.previousProvenance[resource.id];
            if (previous == null) {
              nextProvenance.remove(resource.id);
            } else {
              nextProvenance[resource.id] = previous;
            }
          }
          results = const [];
          localeSkipped = true;
        }
        for (final result in results) {
          resolved[result.id] = TranslationService.sanitizeTranslation(
            result.translation,
          );
        }
        // A provider may leave out a resource it could not translate rather
        // than fail the run (a local model that never answers one in shape).
        // Same treatment as a skipped Codex locale: previous or source text,
        // previous provenance, so the next run sends it again.
        final returned = results.map((result) => result.id).toSet();
        final missing = [
          for (final resource in providerResources)
            if (!returned.contains(resource.id)) resource.id,
        ];
        if (!localeSkipped && missing.isNotEmpty) {
          SkippedTranslations.record(languageCode, sourceTopic, missing, 'no usable translation came back');
          for (final id in missing) {
            final previous = plan.previousProvenance[id];
            if (previous == null) {
              nextProvenance.remove(id);
            } else {
              nextProvenance[id] = previous;
            }
          }
        }
      } else {
        // Google LLM supports opaque request labels. Only resources with no
        // ARB interpolation/ICU syntax take that whole-resource path; complex
        // values retain the legacy action projection below.
        var legacyGoogleResources = providerResources;
        if (translationService == 'google_llm') {
          final structuredGoogleResources = providerResources
              .where((resource) => GoogleResourceAdapter(resource).supportsWholeResourceLlm)
              .toList(growable: false);
          if (structuredGoogleResources.isNotEmpty) {
            final results = await TranslationService.translateResources(
              resources: structuredGoogleResources,
              parameters: <String, dynamic>{'target': languageCode, 'key': apiKey},
              translationService: translationService,
              projectId: projectId,
              authMode: authMode,
              credentialsFile: credentialsFile,
              quotaProjectId: quotaProjectId,
              client: client,
            );
            for (final result in results) {
              resolved[result.id] = TranslationService.sanitizeTranslation(result.translation);
            }
            legacyGoogleResources = providerResources
                .where((resource) => !GoogleResourceAdapter(resource).supportsWholeResourceLlm)
                .toList(growable: false);
          }
        }
        if (legacyGoogleResources.isEmpty) {
          final output = <String, ArbResource>{
            if (preserveUnrelatedExistingResources) ...?existingTranslation?.resources,
            for (final entry in sourceDocument.resources.entries)
              entry.key: entry.value.copyWith(
                text: resolved[entry.key] ?? existingTranslation?.resources[entry.key]?.text ?? entry.value.text,
              ),
          };
          return _TranslatedFileResult(
            sourceDocument.copyWith(locale: languageCode, resources: output),
            provenanceFile,
            nextProvenance,
          );
        }
        // Google retains the legacy action projection, preserving prior ICU and
        // placeholder behavior while OpenAI/local use whole resources above.
        final providerDocument = ArbDocument.empty(
          locale: sourceDocument.locale,
          appName: sourceDocument.appName,
          lastModified: sourceDocument.lastModified,
          resources: {
            for (final resource in legacyGoogleResources) resource.id: sourceDocument.resources[resource.id]!,
          },
        );
        final translatedResources = <String, ArbResource>{...providerDocument.resources};
        for (final actions in ArbProcessor.createActionLists(providerDocument)) {
          final values = await TranslationService.translateTexts(
            translateList: actions.map((action) => action.text).toList(growable: false),
            parameters: <String, dynamic>{'target': languageCode, 'key': apiKey},
            translationService: translationService,
            projectId: projectId,
            authMode: authMode,
            credentialsFile: credentialsFile,
            quotaProjectId: quotaProjectId,
            client: client,
          );
          for (var index = values.length - 1; index >= 0; index--) {
            final action = actions[index];
            final current = translatedResources[action.resourceId]!;
            translatedResources[action.resourceId] = action.updateFunction(
              TranslationService.sanitizeTranslation(values[index]),
              current.text,
            );
          }
        }
        for (final entry in translatedResources.entries) {
          resolved[entry.key] = entry.value.text;
        }
      }
    }
    final output = <String, ArbResource>{
      if (preserveUnrelatedExistingResources) ...?existingTranslation?.resources,
      for (final entry in sourceDocument.resources.entries)
        entry.key: entry.value.copyWith(
          text: resolved[entry.key] ?? existingTranslation?.resources[entry.key]?.text ?? entry.value.text,
        ),
    };
    return _TranslatedFileResult(
      sourceDocument.copyWith(locale: languageCode, resources: output),
      provenanceFile,
      nextProvenance,
    );
  }

  /// Constructs the per-language output filename used by [processSingleFile].
  static String _resolveSingleFileLanguageOutputName({
    required String outputFileName,
    required String languageCode,
  }) {
    if (outputFileName.isEmpty) {
      return '$languageCode.arb';
    }
    if (outputFileName.endsWith('.arb')) {
      final stem = outputFileName.substring(0, outputFileName.length - 4);
      return '${stem}_$languageCode.arb';
    }
    return '$outputFileName$languageCode.arb';
  }

  static bool _isSameLocale(String left, String right) {
    return left.trim().replaceAll('-', '_').toLowerCase() == right.trim().replaceAll('-', '_').toLowerCase();
  }
}

Map<String, dynamic> _readProvenance(File file) {
  if (!file.existsSync()) return <String, dynamic>{};
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

class _LanguagePlan {
  final Map<String, String> resolved;
  final List<TranslationResource> providerResources;
  final Map<String, dynamic> nextProvenance;
  final Map<String, dynamic> previousProvenance;

  const _LanguagePlan(this.resolved, this.providerResources, this.nextProvenance, this.previousProvenance);
}

/// Locales Codex could not translate during this run, reported at the end.
class SkippedTranslations {
  static final List<({String locale, String sourceFile, List<String> ids, Object cause})> _entries = [];

  static void record(String locale, String sourceFile, Iterable<String> ids, Object cause) {
    _entries.add((locale: locale, sourceFile: sourceFile, ids: ids.toList(growable: false), cause: cause));
    print('  ⚠ Skipping ${ids.length} resource(s) in $sourceFile for $locale: $cause');
  }

  static bool get isEmpty => _entries.isEmpty;

  static void clear() => _entries.clear();

  static void printSummary() {
    if (_entries.isEmpty) return;
    final locales = _entries.map((entry) => entry.locale).toSet().toList()..sort();
    final count = _entries.fold<int>(0, (sum, entry) => sum + entry.ids.length);
    print('');
    print('⚠ $count translation(s) were skipped for: ${locales.join(', ')}.');
    print('  They keep their previous or source-language text. Run the translator again to fill them in.');
  }
}

class _TranslatedFileResult {
  final ArbDocument document;
  final File provenanceFile;
  final Map<String, dynamic> provenance;

  const _TranslatedFileResult(
    this.document,
    this.provenanceFile,
    this.provenance,
  );

  Future<void> writeProvenance() async {
    await provenanceFile.parent.create(recursive: true);
    await provenanceFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(provenance),
    );
  }
}
