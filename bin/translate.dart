library translate;

import 'dart:convert';
import 'dart:io';

import 'package:console/console.dart';
import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:smart_arb_translator/src/console_utils.dart';
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:smart_arb_translator/src/file_operations.dart';
import 'package:smart_arb_translator/src/single_file_processor.dart';
import 'package:yaml/yaml.dart';

final encoder = JsonEncoder.withIndent('  ');
final decoder = JsonDecoder();

void main(List<String> args) async {
  final yaml = loadYaml(await File('./pubspec.yaml').readAsString()) as YamlMap;
  final name = yaml['name'] as String;
  final version = yaml['version'] as String;
  Console.init();

  final result = ArbTranslatorArgumentParser.parseArguments(args);

  final sourcePath = result[ArbTranslatorArgumentParser.sourceDir] as String?;
  final sourceDir = Directory(sourcePath ?? '');
  if (!sourceDir.existsSync()) {
    ConsoleUtils.setBrightRed();
    stderr.write('Source directory $sourcePath does not exist');
    exit(2);
  }

  final sourceArb = result[ArbTranslatorArgumentParser.sourceArb] as String?;
  final apiKeyFile = FileOperations.createFileRef(result[ArbTranslatorArgumentParser.apiKey] as String);
  String outputFileName = result[ArbTranslatorArgumentParser.outputFileName] as String;
  if (outputFileName == 'smart_arb_translator_') {
    outputFileName = '';
  }
  final languageCodes =
      (result[ArbTranslatorArgumentParser.languageCodes] as List<String>).map((e) => e.trim()).toList();

  String? cachePath = result[ArbTranslatorArgumentParser.cacheDirectory];
  cachePath ??= path.join('lib', 'l10n_cache');
  final appendLangCode = result[ArbTranslatorArgumentParser.appendLangCode] as bool? ?? true;
  String? l10nDirectory = result[ArbTranslatorArgumentParser.l10nDirectory];
  l10nDirectory ??= path.join('lib', 'l10n');

  final apiKey = apiKeyFile.readAsStringSync();

  if (languageCodes.toSet().length != languageCodes.length) {
    ConsoleUtils.setBrightRed();
    stderr.write('Please remove language code duplicates');
    exit(2);
  }
  print('${'-' * 15}  $name $version  ${'-' * 15}');

  if (sourcePath != null) {
    await DirectoryProcessor.processDirectory(
        sourcePath, languageCodes, apiKey, cachePath, outputFileName, appendLangCode, l10nDirectory);
  } else if (sourceArb != null) {
    await SingleFileProcessor.processSingleFile(
        sourceArb, languageCodes, apiKey, cachePath, outputFileName, appendLangCode);
  } else {
    ConsoleUtils.setBrightRed();
    stderr.write('Either --source_arb or --source_dir must be provided.');
    exit(2);
  }

  ConsoleUtils.setBrightGreen();
  print('✓ Translations created');
  ConsoleUtils.resetTextColor();
}
