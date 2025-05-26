import 'dart:io';

import 'package:arb_merge/arb_merge.dart';
import 'package:console/console.dart';
import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/dart_code_generator.dart';
import 'package:smart_arb_translator/src/file_operations.dart' as translator_file_ops;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:smart_arb_translator/src/translation_statistics.dart';

class DirectoryProcessor {
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
  }) async {
    dartClassName ??= (l10nMethod == 'gen-l10n') ? 'AppLocalizations' : 'S';

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
      final existingArbFiles = await translator_file_ops.FileOperations.findArbFiles(copiedSourceDir);
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
    final arbFiles = await translator_file_ops.FileOperations.findArbFiles(sourceDir);
    if (arbFiles.isEmpty) {
      _setBrightRed();
      stderr.write('No ARB files found in $sourcePath');
      exit(2);
    }

    print('Found ${arbFiles.length} ARB files to translate');
    print('Output directory: $effectiveOutputPath');

    // Initialize statistics tracking
    final statistics = TranslationStatistics();

    for (final arbFile in arbFiles) {
      final fileName = path.basename(arbFile.path);
      final fileNameWithoutExt = path.basenameWithoutExtension(fileName);
      final fileExt = path.extension(fileName);

      for (final languageCode in languageCodes) {
        final langOutputDir = path.join(effectiveOutputPath, languageCode);
        final langOutputFileName = outputFileName.isEmpty
            ? '${fileNameWithoutExt}_$languageCode$fileExt'
            : '${outputFileName}_$languageCode$fileExt';

        final relativePath = path.relative(arbFile.path, from: workingSourcePath);
        final previousDocument = previousSourceFiles[relativePath];

        await SingleFileProcessor.processSingleFileWithChanges(
          arbFile.path,
          [languageCode],
          apiKey,
          langOutputDir,
          langOutputFileName,
          previousDocument,
          statistics,
        );
      }
    }

    // Merge all language files to l10n directory
    await mergeToL10nDirectory(effectiveOutputPath, effectiveL10nPath, languageCodes);

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
        );
      } else {
        print('⚠️  Skipping Dart code generation due to validation errors');
      }
    }

    // Print translation statistics
    statistics.printSummary();
  }

  static Future<void> mergeToL10nDirectory(
    String outputPath,
    String l10nPath,
    List<String> languageCodes,
  ) async {
    print('Merging translation files to l10n directory...');
    print('L10n directory: $l10nPath');

    // Create source folders list for each language
    final sourceFolders = <String>[];

    // Add the main output directory (contains source files and copied files)
    if (Directory(outputPath).existsSync()) {
      sourceFolders.add(outputPath);
    }

    // Add language-specific directories
    for (final languageCode in languageCodes) {
      final langDir = path.join(outputPath, languageCode);
      if (Directory(langDir).existsSync()) {
        sourceFolders.add(langDir);
      }
    }

    if (sourceFolders.isEmpty) {
      print('No directories found to merge');
      return;
    }

    print('Merging from directories: ${sourceFolders.join(', ')}');

    // Create ArbMerge instance
    final arbMerge = ArbMerge.create(
      sourceFolders: sourceFolders,
      destinationFolder: l10nPath,
      filePattern: 'intl_{lang}.arb',
      sortKeys: true,
      verbose: true,
    );

    try {
      final result = await arbMerge.run();
      print('✓ Successfully merged ${result.locales.length} language files:');
      for (final locale in result.locales) {
        print('  - intl_$locale.arb');
      }
    } catch (e) {
      _setBrightRed();
      stderr.write('Error merging files: $e');
      Console.resetTextColor();
    }
  }

  static void _setBrightRed() {
    Console.setTextColor(1, bright: true);
  }
}
