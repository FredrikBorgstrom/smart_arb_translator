import 'dart:io';
import 'package:args/args.dart';
import 'package:console/console.dart';

class ArbTranslatorArgumentParser {
  static const _sourceArb = 'source_arb';
  static const _sourceDir = 'source_dir';
  static const _apiKey = 'api_key';
  static const _help = 'help';
  static const _cacheDirectory = 'cache_directory';
  static const _languageCodes = 'language_codes';
  static const _outputFileName = 'output_file_name';

  static const _l10nDirectory = 'l10n_directory';

  static ArgParser _initiateParse() {
    final parser = ArgParser();

    parser
      ..addFlag('help', hide: true, abbr: 'h')
      ..addOption(
        _sourceArb,
        help: 'source_arb file acts as main file to be translated to other '
            '[language_codes] provided.',
      )
      ..addOption(
        _sourceDir,
        help: 'source directory containing ARB files to be translated recursively',
      )
      ..addOption(
        _cacheDirectory,
        help: 'directory where the translations will be cached',
      )
      ..addMultiOption(_languageCodes, defaultsTo: ['es'])
      ..addOption(_apiKey, help: 'path to api_key must be provided')
      ..addOption(
        _outputFileName,
        defaultsTo: 'intl_',
        help: 'output_file_name is the file name used to concate before language '
            'codes',
      )
      ..addOption(
        _l10nDirectory,
        help: 'directory where merged intl_x.arb files will be created. Defaults to parent of source directory + /l10n',
      );

    return parser;
  }

  static ArgResults parseArguments(List<String> args) {
    final parser = _initiateParse();
    final result = parser.parse(args);

    if (result[_help] as bool? ?? false) {
      print(parser.usage);
      exit(0);
    }

    if (!result.wasParsed(_sourceArb) && !result.wasParsed(_sourceDir)) {
      _setBrightRed();
      stderr.write('Either --source_arb or --source_dir is required.');
      exit(2);
    }

    if (!result.wasParsed(_apiKey)) {
      _setBrightRed();
      stderr.write('--api_key is required');
      exit(2);
    }
    return result;
  }

  static void _setBrightRed() {
    Console.setTextColor(1, bright: true);
  }

  // Getters for argument names
  static String get sourceArb => _sourceArb;
  static String get sourceDir => _sourceDir;
  static String get apiKey => _apiKey;
  static String get help => _help;
  static String get cacheDirectory => _cacheDirectory;
  static String get languageCodes => _languageCodes;
  static String get outputFileName => _outputFileName;

  static String get l10nDirectory => _l10nDirectory;
}
