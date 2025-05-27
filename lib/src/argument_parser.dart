import 'dart:io';
import 'package:args/args.dart';
import 'package:console/console.dart';
import 'pubspec_config.dart';

class ArbTranslatorArgumentParser {
  static const _sourceArb = 'source_arb';
  static const _sourceDir = 'source_dir';
  static const _apiKey = 'api_key';
  static const _help = 'help';
  static const _cacheDirectory = 'cache_directory';
  static const _languageCodes = 'language_codes';
  static const _outputFileName = 'output_file_name';

  static const _l10nDirectory = 'l10n_directory';
  static const _generateDart = 'generate_dart';
  static const _dartClassName = 'dart_class_name';
  static const _dartOutputDir = 'dart_output_dir';
  static const _dartMainLocale = 'dart_main_locale';
  static const _autoApprove = 'auto_approve';
  static const _l10nMethod = 'l10n_method';

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
      )
      ..addFlag(
        _generateDart,
        help: 'generate Dart localization code from ARB files using intl_utils',
        defaultsTo: true,
      )
      ..addOption(
        _dartClassName,
        help: 'name for the generated localization class',
        // defaultsTo: 'S',
      )
      ..addOption(
        _dartOutputDir,
        help: 'directory for generated Dart localization files',
        defaultsTo: 'lib/generated',
      )
      ..addOption(
        _dartMainLocale,
        help: 'main locale for Dart code generation',
        defaultsTo: 'en',
      )
      ..addFlag(
        _autoApprove,
        help: 'automatically approve pubspec.yaml modifications without prompting',
        defaultsTo: false,
      )
      ..addOption(
        _l10nMethod,
        help: 'localization method to use: "gen-l10n" (Flutter built-in) or "intl_utils" (intl_utils package)',
        allowed: ['gen-l10n', 'intl_utils'],
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

    // Load configuration from pubspec.yaml
    final pubspecConfig = PubspecConfig.loadFromPubspec();

    // Create merged configuration with CLI args taking precedence
    final mergedResult = _mergeWithPubspecConfig(result, pubspecConfig);

    // Validate required fields after merging
    final hasSourceArb = mergedResult[_sourceArb] != null;
    final hasSourceDir = mergedResult[_sourceDir] != null;

    if (!hasSourceArb && !hasSourceDir) {
      _setBrightRed();
      stderr.write(
          'Either --source_arb or --source_dir is required (can be set in pubspec.yaml under smart_arb_translator section).');
      exit(2);
    }

    if (mergedResult[_apiKey] == null) {
      _setBrightRed();
      stderr.write('--api_key is required (can be set in pubspec.yaml under smart_arb_translator section)');
      exit(2);
    }

    return mergedResult;
  }

  /// Merge command-line arguments with pubspec.yaml configuration
  /// CLI arguments take precedence over pubspec.yaml settings
  static ArgResults _mergeWithPubspecConfig(ArgResults cliResult, PubspecConfig? pubspecConfig) {
    if (pubspecConfig == null || !pubspecConfig.hasAnyConfig) {
      return cliResult;
    }

    // Create a new map with merged values
    final Map<String, dynamic> mergedOptions = {};

    // Start with pubspec config values
    if (pubspecConfig.sourceArb != null) mergedOptions[_sourceArb] = pubspecConfig.sourceArb;
    if (pubspecConfig.sourceDir != null) mergedOptions[_sourceDir] = pubspecConfig.sourceDir;
    if (pubspecConfig.apiKey != null) mergedOptions[_apiKey] = pubspecConfig.apiKey;
    if (pubspecConfig.cacheDirectory != null) mergedOptions[_cacheDirectory] = pubspecConfig.cacheDirectory;
    if (pubspecConfig.languageCodes != null) mergedOptions[_languageCodes] = pubspecConfig.languageCodes;
    if (pubspecConfig.outputFileName != null) mergedOptions[_outputFileName] = pubspecConfig.outputFileName;
    if (pubspecConfig.l10nDirectory != null) mergedOptions[_l10nDirectory] = pubspecConfig.l10nDirectory;
    if (pubspecConfig.generateDart != null) mergedOptions[_generateDart] = pubspecConfig.generateDart;
    if (pubspecConfig.dartClassName != null) mergedOptions[_dartClassName] = pubspecConfig.dartClassName;
    if (pubspecConfig.dartOutputDir != null) mergedOptions[_dartOutputDir] = pubspecConfig.dartOutputDir;
    if (pubspecConfig.dartMainLocale != null) mergedOptions[_dartMainLocale] = pubspecConfig.dartMainLocale;
    if (pubspecConfig.autoApprove != null) mergedOptions[_autoApprove] = pubspecConfig.autoApprove;
    if (pubspecConfig.l10nMethod != null) mergedOptions[_l10nMethod] = pubspecConfig.l10nMethod;

    // Override with CLI arguments (CLI takes precedence)
    for (final option in cliResult.options) {
      if (cliResult.wasParsed(option)) {
        mergedOptions[option] = cliResult[option];
      }
    }

    // Apply defaults for missing values
    mergedOptions[_languageCodes] ??= ['es'];
    mergedOptions[_outputFileName] ??= 'intl_';
    mergedOptions[_generateDart] ??= true;
    mergedOptions[_dartOutputDir] ??= 'lib/generated';
    mergedOptions[_dartMainLocale] ??= 'en';
    mergedOptions[_autoApprove] ??= false;

    return _MergedArgResults(mergedOptions, cliResult);
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
  static String get generateDart => _generateDart;
  static String get dartClassName => _dartClassName;
  static String get dartOutputDir => _dartOutputDir;
  static String get dartMainLocale => _dartMainLocale;
  static String get autoApprove => _autoApprove;
  static String get l10nMethod => _l10nMethod;
}

/// Custom ArgResults implementation that merges CLI args with pubspec.yaml config
class _MergedArgResults implements ArgResults {
  final Map<String, dynamic> _mergedOptions;
  final ArgResults _originalResult;

  _MergedArgResults(this._mergedOptions, this._originalResult);

  @override
  dynamic operator [](String name) => _mergedOptions[name];

  @override
  List<String> get arguments => _originalResult.arguments;

  @override
  ArgResults? get command => _originalResult.command;

  @override
  String? get name => _originalResult.name;

  @override
  Iterable<String> get options => _mergedOptions.keys;

  @override
  List<String> get rest => _originalResult.rest;

  @override
  bool wasParsed(String name) {
    // Check if it was parsed from CLI or exists in merged options
    return _originalResult.wasParsed(name) || _mergedOptions.containsKey(name);
  }

  @override
  bool flag(String name) {
    final value = _mergedOptions[name];
    if (value is bool) return value;
    return _originalResult.flag(name);
  }

  @override
  List<String> multiOption(String name) {
    final value = _mergedOptions[name];
    if (value is List<String>) return value;
    return _originalResult.multiOption(name);
  }

  @override
  String? option(String name) {
    final value = _mergedOptions[name];
    if (value is String) return value;
    return _originalResult.option(name);
  }
}
