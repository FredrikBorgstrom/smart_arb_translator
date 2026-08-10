import 'dart:convert';
import 'dart:io';

import 'package:arb_merge/arb_merge.dart';
import 'package:console/console.dart';
import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/dart_code_generator.dart';
import 'package:smart_arb_translator/src/file_operations.dart' as translator_file_ops;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:smart_arb_translator/src/translation_statistics.dart';

/// Processor for handling directory-based ARB translation workflows.
///
/// This class provides functionality for processing entire directories containing
/// ARB files, including recursive file discovery, batch translation, change detection,
/// file merging, and Dart code generation. It's designed for projects with multiple
/// ARB files organized in directory structures.
///
/// The processor handles:
/// - Recursive discovery of ARB files in directory trees
/// - Batch translation of multiple files
/// - Smart change detection to avoid unnecessary re-translation
/// - File caching and organization
/// - Integration with arb_merge for l10n directory structure
/// - Dart code generation with multiple localization methods
/// - Translation statistics and progress reporting
///
/// Example usage:
/// ```dart
/// await DirectoryProcessor.processDirectory(
///   'lib/l10n_source',
///   ['es', 'fr', 'de'],
///   'path/to/api_key.txt',
///   'lib/l10n_cache',
///   'intl_',
///   'lib/l10n',
///   generateDart: true,
///   dartClassName: 'AppLocalizations',
/// );
/// ```
class DirectoryProcessor {
  /// Processes a directory containing ARB files for translation.
  ///
  /// This method orchestrates the complete directory-based translation workflow,
  /// including file discovery, translation, merging, and optional Dart code generation.
  /// It supports smart change detection to avoid re-translating unchanged content.
  ///
  /// The process includes:
  /// 1. Copying source directory to cache for change detection
  /// 2. Discovering all ARB files recursively
  /// 3. Translating files with change detection
  /// 4. Merging translated files to l10n directory structure
  /// 5. Generating Dart localization code (optional)
  /// 6. Reporting translation statistics
  ///
  /// Parameters:
  /// - [sourcePath]: Path to the directory containing source ARB files
  /// - [languageCodes]: List of target language codes for translation
  /// - [apiKey]: Google Translate API key for translation service
  /// - [cachePath]: Directory for caching translated files (optional)
  /// - [outputFileName]: Prefix for output ARB file names
  /// - [l10nDirectory]: Directory for merged l10n files (optional)
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
  /// Throws [SystemExit] if the source directory doesn't exist or contains no ARB files.
  ///
  /// Example:
  /// ```dart
  /// await DirectoryProcessor.processDirectory(
  ///   'lib/l10n_source',
  ///   ['es', 'fr', 'de', 'ja'],
  ///   'secrets/api_key.txt',
  ///   'lib/l10n_cache',
  ///   'intl_',
  ///   'lib/l10n',
  ///   generateDart: true,
  ///   dartClassName: 'S',
  ///   dartOutputDir: 'lib/generated',
  ///   dartMainLocale: 'en',
  ///   l10nMethod: 'intl_utils',
  ///   useDeferredLoading: true,
  /// );
  /// ```
  static Future<void> processDirectory(
    String sourcePath,
    List<String> languageCodes,
    String apiKey,
    String? cachePath,
    String outputFileName,
    String? l10nDirectory, {
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
    LocalLlmOptions? localLlmOptions,
    int parallelTranslations = 1,
  }) async {
    dartClassName ??= (l10nMethod == 'gen-l10n') ? 'AppLocalizations' : 'S';
    final effectiveParallelism = parallelTranslations < 1 ? 1 : parallelTranslations;

    Directory sourceDir = Directory(sourcePath);
    if (!sourceDir.existsSync()) {
      _setBrightRed();
      stderr.write('Source directory $sourcePath does not exist');
      exit(2);
    }

    // Set default output directory to parent of source directory if not specified
    final effectiveOutputPath = cachePath ?? path.dirname(path.absolute(sourcePath));

    // Set default l10n directory if not specified
    final effectiveL10nPath = l10nDirectory ?? path.join(path.dirname(path.absolute(sourcePath)), 'l10n');

    // Store previous source files before copying (for change detection)
    Map<String, ArbDocument> previousSourceFiles = {};

    // copy the source directory to the cache directory
    final sourceDirName = path.basename(path.absolute(sourcePath));
    Directory copiedSourceDir = Directory(path.join(effectiveOutputPath, sourceDirName));

    // If we're doing change detection, read the existing copied files first
    if (copiedSourceDir.existsSync()) {
      print('Reading existing copied files for change detection...');
      final existingArbFiles = (await translator_file_ops.FileOperations.findArbFiles(copiedSourceDir))
          .where((file) => !_isGeneratedLocaleMergeFile(file.path));
      for (final arbFile in existingArbFiles) {
        try {
          final content = arbFile.readAsStringSync();
          final document = ArbDocument.decode(content);
          final relativePath = path.relative(arbFile.path, from: copiedSourceDir.path);
          previousSourceFiles[relativePath] = document;
        } catch (e) {
          print('Warning: Could not parse existing file: ${arbFile.path}');
        }
      }
    }

    // Always copy source directory to cache for processing and future comparison
    print('Copying source directory to cache directory...');
    await translator_file_ops.FileOperations.copyDirectory(sourceDir, copiedSourceDir);
    print('Source directory copied to: $copiedSourceDir');

    // Update sourceDir to point to the copied directory
    sourceDir = copiedSourceDir;
    final workingSourcePath = copiedSourceDir.path;

    // Find all ARB files recursively
    final arbFiles = (await translator_file_ops.FileOperations.findArbFiles(sourceDir))
        .where((file) => !_isGeneratedLocaleMergeFile(file.path))
        .toList(growable: false);
    if (arbFiles.isEmpty) {
      _setBrightRed();
      stderr.write('No ARB files found in $sourcePath');
      exit(2);
    }

    print('Found ${arbFiles.length} ARB files to translate');
    print('Output directory: $effectiveOutputPath');
    if (effectiveParallelism > 1) {
      print('Per-language parallelism: $effectiveParallelism concurrent translation requests');
    }

    final statistics = TranslationStatistics();

    final translationLanguageCodes =
        languageCodes.where((languageCode) => !_isSameLocale(languageCode, dartMainLocale)).toList(growable: false);
    if (translationLanguageCodes.length != languageCodes.length) {
      print('Protecting source locale "$dartMainLocale": skipping translation for matching language code(s).');
    }

    for (final arbFile in arbFiles) {
      await _processArbFileForAllLanguages(
        arbFile: arbFile,
        languageCodes: translationLanguageCodes,
        apiKey: apiKey,
        outputFileName: outputFileName,
        effectiveOutputPath: effectiveOutputPath,
        workingSourcePath: workingSourcePath,
        previousSourceFiles: previousSourceFiles,
        statistics: statistics,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        localLlmOptions: localLlmOptions,
        parallelTranslations: effectiveParallelism,
      );
    }

    // Merge all language files to l10n directory
    await mergeToL10nDirectory(
      effectiveOutputPath,
      effectiveL10nPath,
      languageCodes,
      sourceLocaleDirectory: copiedSourceDir.path,
      mainLocale: dartMainLocale,
    );

    // Generate Dart code if requested
    if (generateDart) {
      print('\n🔧 Starting Dart code generation...');

      // For Dart code generation, we need to use the correct l10n directory
      // If l10nDirectory is provided, use it; otherwise use effectiveL10nPath
      final dartL10nPath = l10nDirectory ?? effectiveL10nPath;

      // Validate ARB files exist
      final isValid = await DartCodeGenerator.validateArbFiles(
        arbDirectory: dartL10nPath,
        languageCodes: languageCodes,
        mainLocale: dartMainLocale,
      );

      if (isValid) {
        await DartCodeGenerator.generateDartCode(
          arbDirectory: dartL10nPath,
          outputDirectory: dartOutputDir,
          className: dartClassName,
          mainLocale: dartMainLocale,
          languageCodes: languageCodes,
          autoApprove: autoApprove,
          l10nMethod: l10nMethod,
          useDeferredLoading: useDeferredLoading,
        );
      } else {
        print('⚠️  Skipping Dart code generation due to validation errors');
      }
    }

    // Print translation statistics
    statistics.printSummary();
  }

  /// Merges translated ARB files into a unified l10n directory structure.
  ///
  /// This method uses the arb_merge package to combine ARB files from multiple
  /// language-specific directories into a single l10n directory with the
  /// standard Flutter localization file naming convention (intl_{lang}.arb).
  ///
  /// The merging process:
  /// 1. Discovers all language-specific output directories
  /// 2. Uses arb_merge to combine files by language
  /// 3. Creates unified intl_{lang}.arb files in the l10n directory
  /// 4. Sorts keys for consistent output
  /// 5. Reports merge results
  ///
  /// Parameters:
  /// - [outputPath]: Base directory containing language-specific subdirectories
  /// - [l10nPath]: Target directory for merged l10n files
  /// - [languageCodes]: List of language codes to merge
  ///
  /// Returns a [Future<void>] that completes when merging is finished.
  ///
  /// Example:
  /// ```dart
  /// await DirectoryProcessor.mergeToL10nDirectory(
  ///   'lib/l10n_cache',
  ///   'lib/l10n',
  ///   ['es', 'fr', 'de'],
  /// );
  /// // Creates: lib/l10n/intl_es.arb, lib/l10n/intl_fr.arb, lib/l10n/intl_de.arb
  /// ```
  static Future<void> mergeToL10nDirectory(
    String outputPath,
    String l10nPath,
    List<String> languageCodes, {
    String? sourceLocaleDirectory,
    String mainLocale = 'en',
  }) async {
    print('Merging translation files to l10n directory...');
    print('L10n directory: $l10nPath');

    // Create source folders list for each language
    final sourceFolders = <String>[];
    final sourceFolderSet = <String>{};

    void addSourceFolder(String folderPath) {
      final normalized = path.normalize(folderPath);
      if (Directory(normalized).existsSync() && sourceFolderSet.add(normalized)) {
        sourceFolders.add(normalized);
      }
    }

    // In directory mode, the source locale is rebuilt explicitly from source
    // chunks after the merge. Do not feed the source-locale cache directory to
    // arb_merge because it can contain stale generated intl_<locale>.arb files.
    if (sourceLocaleDirectory == null) {
      // Backwards-compatible fallback for older single-file workflows.
      addSourceFolder(outputPath);
    }

    // Add language-specific directories
    for (final languageCode in languageCodes) {
      if (sourceLocaleDirectory != null && _isSameLocale(languageCode, mainLocale)) {
        continue;
      }
      final langDir = path.join(outputPath, languageCode);
      addSourceFolder(langDir);
    }

    if (sourceFolders.isEmpty && sourceLocaleDirectory == null) {
      print('No directories found to merge');
      return;
    }

    try {
      if (sourceFolders.isNotEmpty) {
        print('Merging from directories: ${sourceFolders.join(', ')}');

        // Create ArbMerge instance
        final arbMerge = ArbMerge.create(
          sourceFolders: sourceFolders,
          destinationFolder: l10nPath,
          filePattern: 'intl_{lang}.arb',
          sortKeys: true,
          verbose: true,
        );

        final result = await arbMerge.run();
        print('✓ Successfully merged ${result.locales.length} language files:');
        for (final locale in result.locales) {
          print('  - intl_$locale.arb');
        }
      } else {
        print('No translated locale directories found to merge');
      }
      if (sourceLocaleDirectory != null) {
        await _writeMainLocaleFromSourceDirectory(
          sourceLocaleDirectory: sourceLocaleDirectory,
          l10nPath: l10nPath,
          mainLocale: mainLocale,
        );
      }
    } catch (e) {
      _setBrightRed();
      stderr.write('Error merging files: $e');
      Console.resetTextColor();
    }
  }

  static Future<void> _writeMainLocaleFromSourceDirectory({
    required String sourceLocaleDirectory,
    required String l10nPath,
    required String mainLocale,
  }) async {
    final sourceDir = Directory(sourceLocaleDirectory);
    if (!sourceDir.existsSync()) {
      return;
    }

    final merged = <String, dynamic>{};
    final sourceFiles = await translator_file_ops.FileOperations.findArbFiles(sourceDir);
    sourceFiles.sort((a, b) => a.path.compareTo(b.path));

    for (final sourceFile in sourceFiles) {
      final fileName = path.basename(sourceFile.path);
      if (_isGeneratedLocaleMergeFile(fileName)) {
        continue;
      }
      final raw = jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in raw.entries) {
        merged[entry.key] = entry.value;
      }
    }

    if (merged.isEmpty) {
      return;
    }

    final sorted = Map<String, dynamic>.fromEntries(
      merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final destination = File(path.join(l10nPath, 'intl_$mainLocale.arb'));
    await destination.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await destination.writeAsString('${encoder.convert(sorted)}\n');
    print('✓ Rebuilt protected source locale file: ${destination.path}');
  }

  /// Processes a single ARB file for every target language, batching the
  /// per-language translation calls into chunks of [parallelTranslations].
  ///
  /// Languages within a chunk run concurrently via [Future.wait]. Chunks run
  /// sequentially so we cap the maximum number of in-flight translation
  /// requests against the upstream provider. Setting [parallelTranslations] to
  /// 1 reproduces the original strictly sequential behavior.
  static Future<void> _processArbFileForAllLanguages({
    required File arbFile,
    required List<String> languageCodes,
    required String apiKey,
    required String outputFileName,
    required String effectiveOutputPath,
    required String workingSourcePath,
    required Map<String, ArbDocument> previousSourceFiles,
    required TranslationStatistics statistics,
    required String translationService,
    required String? projectId,
    required String authMode,
    required String? credentialsFile,
    required String? quotaProjectId,
    required String openaiModel,
    required String? translationContext,
    required LocalLlmOptions? localLlmOptions,
    required int parallelTranslations,
  }) async {
    final fileExt = path.extension(path.basename(arbFile.path));
    final relativePath = path.relative(arbFile.path, from: workingSourcePath);
    final previousDocument = previousSourceFiles[relativePath];

    Future<void> runForLanguage(String languageCode) async {
      final langOutputDir = path.join(effectiveOutputPath, languageCode);
      final langOutputFileName = _resolveLanguageOutputFileName(
        outputFileName: outputFileName,
        languageCode: languageCode,
        fileExt: fileExt,
      );

      await SingleFileProcessor.processSingleFileWithChanges(
        arbFile.path,
        [languageCode],
        apiKey,
        langOutputDir,
        langOutputFileName,
        previousDocument,
        statistics,
        translationService: translationService,
        projectId: projectId,
        authMode: authMode,
        credentialsFile: credentialsFile,
        quotaProjectId: quotaProjectId,
        openaiModel: openaiModel,
        translationContext: translationContext,
        localLlmOptions: localLlmOptions,
      );
    }

    for (final chunk in _chunked(languageCodes, parallelTranslations)) {
      await Future.wait(chunk.map(runForLanguage));
    }
  }

  /// Builds the per-language output file name following the legacy convention.
  static String _resolveLanguageOutputFileName({
    required String outputFileName,
    required String languageCode,
    required String fileExt,
  }) {
    if (outputFileName.isEmpty) {
      return '$languageCode$fileExt';
    }
    if (outputFileName.endsWith('_')) {
      return '$outputFileName$languageCode$fileExt';
    }
    return '${outputFileName}_$languageCode$fileExt';
  }

  /// Splits [items] into successive chunks of size [size].
  ///
  /// Returns lazily so callers can `await` each chunk before the next is built.
  static Iterable<List<T>> _chunked<T>(List<T> items, int size) sync* {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'chunk size must be >= 1');
    }
    for (var start = 0; start < items.length; start += size) {
      final end = (start + size < items.length) ? start + size : items.length;
      yield items.sublist(start, end);
    }
  }

  static void _setBrightRed() {
    Console.setTextColor(1, bright: true);
  }

  static bool _isSameLocale(String left, String right) {
    return left.trim().replaceAll('-', '_').toLowerCase() == right.trim().replaceAll('-', '_').toLowerCase();
  }

  static bool _isGeneratedLocaleMergeFile(String filePath) {
    final fileName = path.basename(filePath);
    return RegExp(r'^intl_[A-Za-z0-9_-]+\.arb$').hasMatch(fileName);
  }
}
