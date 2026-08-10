#!/usr/bin/env dart

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:smart_arb_translator/src/cache_cleanup.dart';
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/localization_validator.dart';
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/translation_resource.dart';
import 'package:smart_arb_translator/src/reviewed_overlay.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';

Future<void> main(List<String> args) async {
  try {
    // Parse arguments (now async to handle auto-configuration)
    final result = await ArbTranslatorArgumentParser.parseArguments(args);
    final cleanupMode = result[ArbTranslatorArgumentParser.cleanCorruptedCache] as bool? ?? false;

    if (cleanupMode) {
      final cacheDirectory = result[ArbTranslatorArgumentParser.cacheDirectory] as String? ?? 'lib/l10n_cache';
      final languageCodes = (result[ArbTranslatorArgumentParser.languageCodes] as List<String>?)
          ?.map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toSet();
      final dryRun = result[ArbTranslatorArgumentParser.dryRun] as bool? ?? false;

      final cleanupResult = CacheCleanupService.cleanCorruptedCache(
        cacheDirectory: cacheDirectory,
        locales: languageCodes == null || languageCodes.isEmpty ? null : languageCodes,
        dryRun: dryRun,
      );

      if (!cleanupResult.hasChanges) {
        print('\n✅ No corrupted cached keys found.');
        return;
      }

      final sortedLocales = cleanupResult.removedKeysByLocale.keys.toList()..sort();
      for (final locale in sortedLocales) {
        final removedKeys = cleanupResult.removedKeysByLocale[locale]!;
        print('${dryRun ? 'Would remove' : 'Removed'} ${removedKeys.length} corrupted cached keys from $locale');
      }
      print(
        '\n✅ ${dryRun ? 'Would remove' : 'Removed'} ${cleanupResult.totalRemoved} corrupted cached keys across ${cleanupResult.affectedLocales} locales.',
      );
      if (!dryRun) {
        print('Run smart_arb_translator again to refill the missing translations from cache.');
      }
      return;
    }

    // Extract common parameters
    var languageCodes = result[ArbTranslatorArgumentParser.languageCodes] as List<String>;
    final localeFilter = result[ArbTranslatorArgumentParser.localeFilter] as List<String>? ?? const [];
    final sourceFileFilter = result[ArbTranslatorArgumentParser.sourceFileFilter] as List<String>? ?? const [];
    final keyFilter = result[ArbTranslatorArgumentParser.keyFilter] as List<String>? ?? const [];
    if (localeFilter.isNotEmpty) {
      languageCodes = languageCodes.where(localeFilter.contains).toList(growable: false);
    }
    var apiKey = result[ArbTranslatorArgumentParser.apiKey] as String?;

    // Check if apiKey is a file path and read it if so
    if (apiKey != null && File(apiKey).existsSync()) {
      try {
        apiKey = File(apiKey).readAsStringSync().trim();
      } catch (e) {
        print('Warning: Could not read API key file: $e');
        // Continue with original value, it might be the key itself
      }
    }
    final generateDart = result[ArbTranslatorArgumentParser.generateDart] as bool? ?? false;
    final dartClassName = result[ArbTranslatorArgumentParser.dartClassName] as String?;
    final dartOutputDir = result[ArbTranslatorArgumentParser.dartOutputDir] as String? ?? 'lib/generated';
    final dartMainLocale = result[ArbTranslatorArgumentParser.dartMainLocale] as String? ?? 'en';
    final autoApprove = result[ArbTranslatorArgumentParser.autoApprove] as bool? ?? false;
    final l10nMethod = result[ArbTranslatorArgumentParser.l10nMethod] as String?;
    final useDeferredLoading = result[ArbTranslatorArgumentParser.useDeferredLoading] as bool? ?? false;
    final translationService = result[ArbTranslatorArgumentParser.translationService] as String? ?? 'google_basic';
    final projectId = result[ArbTranslatorArgumentParser.projectId] as String?;
    final authMode = result[ArbTranslatorArgumentParser.authMode] as String? ?? 'api_key';
    final credentialsFile = result[ArbTranslatorArgumentParser.credentialsFile] as String?;
    final quotaProjectId = result[ArbTranslatorArgumentParser.quotaProjectId] as String?;
    final openaiModel = result[ArbTranslatorArgumentParser.openaiModel] as String? ?? 'gpt-4o-mini';
    final manualOnly = (result[ArbTranslatorArgumentParser.manualOnly] as bool? ?? false) ||
        (result[ArbTranslatorArgumentParser.offline] as bool? ?? false) ||
        (result[ArbTranslatorArgumentParser.mergeReviewedOnly] as bool? ?? false);
    final localLlmOptions = translationService == 'local_llm' && !manualOnly
        ? LocalLlmOptions.fromConfig(
            endpoint: result[ArbTranslatorArgumentParser.localLlmUrl] as String? ?? LocalLlmOptions.defaultEndpoint,
            model: result[ArbTranslatorArgumentParser.localLlmModel] as String,
            jsonMode: result[ArbTranslatorArgumentParser.localLlmJsonMode] as bool? ?? true,
            timeoutSeconds: ArbTranslatorArgumentParser.parseLocalLlmTimeoutSeconds(
              result[ArbTranslatorArgumentParser.localLlmTimeoutSeconds],
            ),
            profile: result[ArbTranslatorArgumentParser.localLlmProfile] as String? ?? 'openai_chat_json',
          )
        : null;
    final translationContext = _readTranslationContext(
      result[ArbTranslatorArgumentParser.translationContext] as String?,
      result[ArbTranslatorArgumentParser.translationContextFile] as String?,
    );
    final reviewedTranslationsDir = result[ArbTranslatorArgumentParser.reviewedTranslationsDir] as String?;

    // Determine processing mode
    final sourceArb = result[ArbTranslatorArgumentParser.sourceArb] as String?;
    final sourceDir = result[ArbTranslatorArgumentParser.sourceDir] as String?;
    final sourceFiles = sourceArb == null
        ? (sourceDir == null
            ? const <File>[]
            : Directory(sourceDir)
                .listSync(recursive: true)
                .whereType<File>()
                .where((file) => file.path.endsWith('.arb')))
        : [File(sourceArb)];

    if (result[ArbTranslatorArgumentParser.validateOnly] as bool? ?? false) {
      final issues = sourceFiles.expand((file) => LocalizationValidator.validateArbFile(file));
      for (final issue in issues) print(issue);
      if (issues.isNotEmpty) exitCode = 2;
      return;
    }
    if (result[ArbTranslatorArgumentParser.dryRunNetworkPlan] as bool? ?? false) {
      print(manualOnly
          ? 'Dry-run network plan: zero provider requests (manual/offline mode).'
          : 'Dry-run network plan: only x-translations, current reviewed overlays, and current provenance cache avoid provider requests.');
      return;
    }
    if (result[ArbTranslatorArgumentParser.listStaleReviewed] as bool? ?? false) {
      for (final file in sourceFiles) {
        final document = ArbDocument.decode(file.readAsStringSync());
        final resources = document.resources.values
            .map((resource) => TranslationResource.fromArbResource(resource, sourceTopic: path.basename(file.path)));
        for (final locale in languageCodes) {
          for (final key in ReviewedOverlay.staleKeys(
            rootDirectory: reviewedTranslationsDir,
            locale: locale,
            sourceFile: file.path,
            resources: resources,
            translationContext: translationContext,
          )) {
            print('$locale/${path.basename(file.path)}#$key');
          }
        }
      }
      return;
    }

    if (sourceArb != null) {
      // Single file processing
      final outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String? ?? 'intl_';
      final l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory] as String?;

      await SingleFileProcessor.processSingleFile(
        sourceArb,
        languageCodes,
        apiKey ?? '',
        l10nDirectory,
        outputFileName,
        generateDart: generateDart,
        dartClassName: dartClassName,
        dartOutputDir: dartOutputDir,
        dartMainLocale: dartMainLocale,
        autoApprove: autoApprove,
        l10nMethod: l10nMethod,
        useDeferredLoading: useDeferredLoading,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        localLlmOptions: localLlmOptions,
        reviewedTranslationsDir: reviewedTranslationsDir,
        manualOnly: manualOnly,
        resourceKeyFilter: keyFilter.isEmpty ? null : keyFilter.toSet(),
      );
    } else if (sourceDir != null) {
      // Directory processing
      final cacheDirectory = result[ArbTranslatorArgumentParser.cacheDirectory] as String?;
      final outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String? ?? 'intl_';
      final l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory] as String?;

      await DirectoryProcessor.processDirectory(
        sourceDir,
        languageCodes,
        apiKey ?? '',
        cacheDirectory,
        outputFileName,
        l10nDirectory,
        generateDart: generateDart,
        dartClassName: dartClassName,
        dartOutputDir: dartOutputDir,
        dartMainLocale: dartMainLocale,
        autoApprove: autoApprove,
        l10nMethod: l10nMethod,
        useDeferredLoading: useDeferredLoading,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        localLlmOptions: localLlmOptions,
        reviewedTranslationsDir: reviewedTranslationsDir,
        manualOnly: manualOnly,
        sourceFileFilters: sourceFileFilter.isEmpty ? null : sourceFileFilter.toSet(),
        resourceKeyFilter: keyFilter.isEmpty ? null : keyFilter.toSet(),
      );
    }

    print('\n✅ Translation process completed successfully!');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}

String? _readTranslationContext(String? inlineContext, String? contextFilePath) {
  final normalizedInline = inlineContext?.trim();
  final normalizedPath = contextFilePath?.trim();

  final contexts = <String>[];
  if (normalizedPath != null && normalizedPath.isNotEmpty) {
    final contextFile = File(normalizedPath);
    if (!contextFile.existsSync()) {
      throw ArgumentError('Translation context file does not exist: $normalizedPath');
    }
    final fileContent = contextFile.readAsStringSync().trim();
    if (fileContent.isNotEmpty) {
      contexts.add(fileContent);
    }
  }

  if (normalizedInline != null && normalizedInline.isNotEmpty) {
    contexts.add(normalizedInline);
  }

  if (contexts.isEmpty) {
    return null;
  }
  return contexts.join('\n\n');
}
