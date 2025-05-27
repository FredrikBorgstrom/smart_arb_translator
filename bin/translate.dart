#!/usr/bin/env dart

import 'dart:io';

import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';

Future<void> main(List<String> args) async {
  try {
    // Parse arguments (now async to handle auto-configuration)
    final result = await ArbTranslatorArgumentParser.parseArguments(args);

    // Extract common parameters
    final languageCodes = result[ArbTranslatorArgumentParser.languageCodes] as List<String>;
    final apiKey = result[ArbTranslatorArgumentParser.apiKey] as String;
    final generateDart = result[ArbTranslatorArgumentParser.generateDart] as bool? ?? false;
    final dartClassName = result[ArbTranslatorArgumentParser.dartClassName] as String?;
    final dartOutputDir = result[ArbTranslatorArgumentParser.dartOutputDir] as String? ?? 'lib/generated';
    final dartMainLocale = result[ArbTranslatorArgumentParser.dartMainLocale] as String? ?? 'en';
    final autoApprove = result[ArbTranslatorArgumentParser.autoApprove] as bool? ?? false;
    final l10nMethod = result[ArbTranslatorArgumentParser.l10nMethod] as String?;
    final useDeferredLoading = result[ArbTranslatorArgumentParser.useDeferredLoading] as bool? ?? false;

    // Determine processing mode
    final sourceArb = result[ArbTranslatorArgumentParser.sourceArb] as String?;
    final sourceDir = result[ArbTranslatorArgumentParser.sourceDir] as String?;

    if (sourceArb != null) {
      // Single file processing
      final outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String? ?? 'intl_';
      final l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory] as String?;

      await SingleFileProcessor.processSingleFile(
        sourceArb,
        languageCodes,
        apiKey,
        l10nDirectory,
        outputFileName,
        generateDart: generateDart,
        dartClassName: dartClassName,
        dartOutputDir: dartOutputDir,
        dartMainLocale: dartMainLocale,
        autoApprove: autoApprove,
        l10nMethod: l10nMethod,
        useDeferredLoading: useDeferredLoading,
      );
    } else if (sourceDir != null) {
      // Directory processing
      final cacheDirectory = result[ArbTranslatorArgumentParser.cacheDirectory] as String?;
      final outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String? ?? 'intl_';
      final l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory] as String?;

      await DirectoryProcessor.processDirectory(
        sourceDir,
        languageCodes,
        apiKey,
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
      );
    }

    print('\n✅ Translation process completed successfully!');
  } catch (e) {
    print('\n❌ Error: $e');
    exit(1);
  }
}
