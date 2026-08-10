library;

import 'dart:convert';
import 'dart:io';

import 'package:console/console.dart';
import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:smart_arb_translator/src/cache_cleanup.dart';
import 'package:smart_arb_translator/src/console_utils.dart';
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:yaml/yaml.dart';

final encoder = JsonEncoder.withIndent('  ');
final decoder = JsonDecoder();

void main(List<String> args) async {
  final yaml = loadYaml(await File('./pubspec.yaml').readAsString()) as YamlMap;
  final name = yaml['name'] as String;
  final version = yaml['version'] as String;
  Console.init();

  final result = await ArbTranslatorArgumentParser.parseArguments(args);
  final cleanupMode = result[ArbTranslatorArgumentParser.cleanCorruptedCache] as bool? ?? false;

  if (cleanupMode) {
    final cachePath = result[ArbTranslatorArgumentParser.cacheDirectory] as String? ?? path.join('lib', 'l10n_cache');
    final languageCodes = (result[ArbTranslatorArgumentParser.languageCodes] as List<String>?)
        ?.map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final dryRun = result[ArbTranslatorArgumentParser.dryRun] as bool? ?? false;

    print('${'-' * 15}  $name $version  ${'-' * 15}');

    final cleanupResult = CacheCleanupService.cleanCorruptedCache(
      cacheDirectory: cachePath,
      locales: languageCodes == null || languageCodes.isEmpty ? null : languageCodes,
      dryRun: dryRun,
    );

    if (!cleanupResult.hasChanges) {
      ConsoleUtils.setBrightGreen();
      print('✓ No corrupted cached keys found');
      ConsoleUtils.resetTextColor();
      return;
    }

    final sortedLocales = cleanupResult.removedKeysByLocale.keys.toList()..sort();
    for (final locale in sortedLocales) {
      final removedKeys = cleanupResult.removedKeysByLocale[locale]!;
      print('${dryRun ? 'Would remove' : 'Removed'} ${removedKeys.length} corrupted cached keys from $locale');
    }

    ConsoleUtils.setBrightGreen();
    print(
      '✓ ${dryRun ? 'Would remove' : 'Removed'} ${cleanupResult.totalRemoved} corrupted cached keys across ${cleanupResult.affectedLocales} locales',
    );
    ConsoleUtils.resetTextColor();
    if (!dryRun) {
      print('Run smart_arb_translator again to refill the missing translations.');
    }
    return;
  }

  final sourcePath = result[ArbTranslatorArgumentParser.sourceDir] as String?;
  final sourceArb = result[ArbTranslatorArgumentParser.sourceArb] as String?;

  // Validate source directory exists if source_dir is provided
  if (sourcePath != null) {
    final sourceDir = Directory(sourcePath);
    if (!sourceDir.existsSync()) {
      ConsoleUtils.setBrightRed();
      stderr.write('Source directory $sourcePath does not exist');
      exit(2);
    }
  }
  // Validate source ARB file exists if source_arb is provided
  if (sourceArb != null) {
    final sourceArbFile = File(sourceArb);
    if (!sourceArbFile.existsSync()) {
      ConsoleUtils.setBrightRed();
      stderr.write('Source ARB file $sourceArb does not exist');
      exit(2);
    }
  }
  var apiKey = result[ArbTranslatorArgumentParser.apiKey] as String?;
  String outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String;
  /* if (outputFileName == 'intl_') {
    outputFileName = '';
  } */
  final languageCodes =
      (result[ArbTranslatorArgumentParser.languageCodes] as List<String>).map((e) => e.trim()).toList();

  String? cachePath = result[ArbTranslatorArgumentParser.cacheDirectory];
  cachePath ??= path.join('lib', 'l10n_cache');

  String? l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory];
  l10nDirectory ??= path.join('lib', 'l10n');

  // Get Dart code generation parameters
  final generateDart = result[ArbTranslatorArgumentParser.generateDart] as bool;
  final dartClassName = result[ArbTranslatorArgumentParser.dartClassName] as String?;
  final dartOutputDir = result[ArbTranslatorArgumentParser.dartOutputDir] as String;
  final dartMainLocale = result[ArbTranslatorArgumentParser.dartMainLocale] as String;
  final autoApprove = result[ArbTranslatorArgumentParser.autoApprove] as bool;
  final l10nMethod = result[ArbTranslatorArgumentParser.l10nMethod] as String?;
  final useDeferredLoading = result[ArbTranslatorArgumentParser.useDeferredLoading] as bool;
  final translationService = result[ArbTranslatorArgumentParser.translationService] as String;
  final projectId = result[ArbTranslatorArgumentParser.projectId] as String?;
  final authMode = result[ArbTranslatorArgumentParser.authMode] as String? ?? 'api_key';
  final credentialsFile = result[ArbTranslatorArgumentParser.credentialsFile] as String?;
  final quotaProjectId = result[ArbTranslatorArgumentParser.quotaProjectId] as String?;
  final openaiModel = result[ArbTranslatorArgumentParser.openaiModel] as String? ?? 'gpt-4o-mini';
  final localLlmOptions = translationService == 'local_llm'
      ? LocalLlmOptions.fromConfig(
          endpoint: result[ArbTranslatorArgumentParser.localLlmUrl] as String? ?? LocalLlmOptions.defaultEndpoint,
          model: result[ArbTranslatorArgumentParser.localLlmModel] as String,
          jsonMode: result[ArbTranslatorArgumentParser.localLlmJsonMode] as bool? ?? true,
          timeoutSeconds: ArbTranslatorArgumentParser.parseLocalLlmTimeoutSeconds(
            result[ArbTranslatorArgumentParser.localLlmTimeoutSeconds],
          ),
        )
      : null;
  final translationContext = _readTranslationContext(
    result[ArbTranslatorArgumentParser.translationContext] as String?,
    result[ArbTranslatorArgumentParser.translationContextFile] as String?,
  );
  final parallelTranslations = ArbTranslatorArgumentParser.parseParallelTranslations(
    result[ArbTranslatorArgumentParser.parallelTranslations],
  );

  if (apiKey != null && File(apiKey).existsSync()) {
    apiKey = File(apiKey).readAsStringSync().trim();
  }

  if (languageCodes.toSet().length != languageCodes.length) {
    ConsoleUtils.setBrightRed();
    stderr.write('Please remove language code duplicates');
    exit(2);
  }
  print('${'-' * 15}  $name $version  ${'-' * 15}');

  if (sourcePath != null) {
    await DirectoryProcessor.processDirectory(
      sourcePath,
      languageCodes,
      apiKey ?? '',
      cachePath,
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
      parallelTranslations: parallelTranslations,
    );
  } else if (sourceArb != null) {
    await SingleFileProcessor.processSingleFile(
      sourceArb,
      languageCodes,
      apiKey ?? '',
      cachePath,
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
      parallelTranslations: parallelTranslations,
    );

    // Create l10n directory and merge files for single file processing
    await DirectoryProcessor.mergeToL10nDirectory(cachePath, l10nDirectory, languageCodes);
  } else {
    ConsoleUtils.setBrightRed();
    stderr.write('Either --source_arb or --source_dir must be provided.');
    exit(2);
  }

  ConsoleUtils.setBrightGreen();
  print('✓ Translations created');
  ConsoleUtils.resetTextColor();
}

String? _readTranslationContext(String? inlineContext, String? contextFilePath) {
  final normalizedInline = inlineContext?.trim();
  final normalizedPath = contextFilePath?.trim();

  final contexts = <String>[];
  if (normalizedPath != null && normalizedPath.isNotEmpty) {
    final contextFile = File(normalizedPath);
    if (!contextFile.existsSync()) {
      ConsoleUtils.setBrightRed();
      stderr.write('Translation context file does not exist: $normalizedPath');
      exit(2);
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
