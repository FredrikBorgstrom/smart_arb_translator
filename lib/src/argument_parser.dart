import 'dart:io';
import 'package:args/args.dart';
import 'package:console/console.dart';
import 'pubspec_config.dart';

/// Command-line argument parser for the Smart ARB Translator.
///
/// This class handles parsing and validation of command-line arguments,
/// merging them with configuration from pubspec.yaml, and providing
/// auto-configuration capabilities for new users.
///
/// The parser supports various options including:
/// - Source file/directory specification
/// - Translation API configuration
/// - Output customization
/// - Dart code generation settings
/// - Localization method selection
///
/// Arguments can be provided via command line or configured in pubspec.yaml
/// under the `smart_arb_translator` section, with CLI arguments taking precedence.
class ArbTranslatorArgumentParser {
  static const _sourceArb = 'source_arb';
  static const _sourceDir = 'source_dir';
  static const _apiKey = 'api_key';
  static const _help = 'help';
  static const _cleanCorruptedCache = 'clean-corrupted-cache';
  static const _dryRun = 'dry-run';
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
  static const _useDeferredLoading = 'use_deferred_loading';
  static const _translationService = 'translation_service';
  static const _projectId = 'project_id';
  static const _authMode = 'auth_mode';
  static const _credentialsFile = 'credentials_file';
  static const _quotaProjectId = 'quota_project_id';
  static const _openaiModel = 'openai_model';
  static const _translationContext = 'translation_context';
  static const _translationContextFile = 'translation_context_file';

  /// Initializes and configures the argument parser.
  ///
  /// This private method sets up all available command-line options with
  /// their descriptions, default values, and validation rules.
  ///
  /// Returns a configured [ArgParser] instance ready for parsing arguments.
  static ArgParser _initiateParse() {
    final parser = ArgParser();

    parser
      ..addFlag('help', hide: true, abbr: 'h')
      ..addFlag(
        _cleanCorruptedCache,
        help: 'remove only known-corrupted translation cache entries and exit',
        defaultsTo: false,
      )
      ..addFlag(
        _dryRun,
        help: 'report what would change without modifying files',
        defaultsTo: false,
      )
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
      ..addOption(
        _apiKey,
        help: 'path to api_key (required for google_basic/google_nmt, openai, and google_llm with auth_mode=api_key)',
      )
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
        help:
            'localization method to use: "gen-l10n" (Flutter built-in), "intl_utils" (intl_utils package), or "none" (no Dart generation)',
        allowed: ['gen-l10n', 'intl_utils', 'none'],
      )
      ..addFlag(
        _useDeferredLoading,
        help: 'enable deferred loading for locales (primarily for Flutter Web to reduce initial bundle size)',
        defaultsTo: false,
      )
      ..addOption(
        _translationService,
        help:
            'translation service to use: "google_basic" (v2), "google_nmt" (v2 with model=nmt), "google_llm" (v3), or "openai"',
        allowed: ['google_basic', 'google_nmt', 'google_llm', 'openai'],
        defaultsTo: 'google_basic',
      )
      ..addOption(
        _projectId,
        help: 'Google Cloud Project ID (required for "llm" service)',
      )
      ..addOption(
        _authMode,
        help:
            'authentication mode: "api_key" (default), "adc" (Application Default Credentials), or "service_account" (JSON key file)',
        allowed: ['api_key', 'adc', 'service_account'],
        defaultsTo: 'api_key',
      )
      ..addOption(
        _credentialsFile,
        help: 'path to service account JSON credentials (used when auth_mode=service_account)',
      )
      ..addOption(
        _quotaProjectId,
        help: 'quota/billing project id for OAuth requests (x-goog-user-project header)',
      )
      ..addOption(
        _openaiModel,
        help: 'OpenAI model to use when translation_service=openai',
        defaultsTo: 'gpt-4o-mini',
      )
      ..addOption(
        _translationContext,
        help: 'optional context/instructions for LLM translations (google_llm or openai)',
      )
      ..addOption(
        _translationContextFile,
        help: 'path to a file containing translation context text (appended to translation_context)',
      );

    return parser;
  }

  /// Parses command-line arguments and merges them with pubspec.yaml configuration.
  ///
  /// This method performs the complete argument processing workflow:
  /// 1. Parses command-line arguments
  /// 2. Loads configuration from pubspec.yaml
  /// 3. Merges CLI args with pubspec config (CLI takes precedence)
  /// 4. Runs auto-configuration if needed
  /// 5. Validates required parameters
  ///
  /// The method handles help display, auto-configuration prompts, and
  /// validation errors with appropriate exit codes.
  ///
  /// Parameters:
  /// - [args]: List of command-line arguments to parse
  ///
  /// Returns a [Future<ArgResults>] containing the merged and validated configuration.
  ///
  /// Throws [SystemExit] (via exit()) if:
  /// - Help is requested (exit code 0)
  /// - Required arguments are missing (exit code 2)
  ///
  /// Example:
  /// ```dart
  /// final results = await ArbTranslatorArgumentParser.parseArguments([
  ///   '--source_dir', 'lib/l10n_source',
  ///   '--api_key', 'path/to/key.txt',
  ///   '--language_codes', 'es,fr,de'
  /// ]);
  /// ```
  static Future<ArgResults> parseArguments(List<String> args) async {
    final normalizedArgs = _normalizeFlagAliases(args);
    final parser = _initiateParse();
    final result = parser.parse(normalizedArgs);

    if (result[_help] as bool? ?? false) {
      print(parser.usage);
      exit(0);
    }

    // Load configuration from pubspec.yaml
    final pubspecConfig = PubspecConfig.loadFromPubspec();

    // Create merged configuration with CLI args taking precedence
    var mergedResult = _mergeWithPubspecConfig(result, pubspecConfig);
    final cleanupMode = mergedResult[_cleanCorruptedCache] as bool? ?? false;

    if (cleanupMode) {
      if (!_wasOptionExplicitlyProvided(normalizedArgs, _languageCodes)) {
        mergedResult = _updateMergedResult(mergedResult, {_languageCodes: null});
      }
      return mergedResult;
    }

    // Check if auto-configuration is needed
    final hasSourceArb = mergedResult[_sourceArb] != null;
    final hasSourceDir = mergedResult[_sourceDir] != null;
    final autoApprove = mergedResult[_autoApprove] as bool? ?? false;

    if (!hasSourceArb && !hasSourceDir) {
      if (autoApprove) {
        // Default to source_dir with lib/l10n_source when auto-approve is enabled
        print('🎯 No source configuration found, defaulting to source_dir: lib/l10n_source (auto-approve enabled)');
        mergedResult = _updateMergedResult(mergedResult, {
          _sourceDir: 'lib/l10n_source',
          _dartMainLocale: 'en',
        });
      } else {
        // Run auto-configuration to prompt user
        final autoConfig = await _runAutoConfiguration();
        mergedResult = _updateMergedResult(mergedResult, autoConfig);
      }
    }

    // Validate required fields after merging and auto-configuration
    final finalHasSourceArb = mergedResult[_sourceArb] != null;
    final finalHasSourceDir = mergedResult[_sourceDir] != null;

    if (!finalHasSourceArb && !finalHasSourceDir) {
      _setBrightRed();
      stderr.write(
          'Either --source_arb or --source_dir is required (can be set in pubspec.yaml under smart_arb_translator section).');
      exit(2);
    }

    final translationService = mergedResult[_translationService] as String? ?? 'google_basic';
    final projectId = (mergedResult[_projectId] as String?)?.trim();
    final authMode = mergedResult[_authMode] as String? ?? 'api_key';
    final apiKey = (mergedResult[_apiKey] as String?)?.trim();
    final credentialsFile = (mergedResult[_credentialsFile] as String?)?.trim();
    final translationContextFile = (mergedResult[_translationContextFile] as String?)?.trim();

    final needsApiKey =
        translationService == 'google_basic' || translationService == 'google_nmt' || translationService == 'openai'
            ? true
            : authMode == 'api_key';
    if (needsApiKey && (apiKey == null || apiKey.isEmpty)) {
      _setBrightRed();
      stderr.write('--api_key is required (can be set in pubspec.yaml under smart_arb_translator section)');
      exit(2);
    }

    if (translationService == 'openai' && authMode != 'api_key') {
      _setBrightRed();
      stderr.write('--auth_mode must be "api_key" when --translation_service is "openai".');
      exit(2);
    }

    if (translationService == 'google_llm') {
      if (projectId == null || projectId.isEmpty) {
        _setBrightRed();
        stderr.write(
            '--project_id is required when --translation_service is "google_llm" (can be set in pubspec.yaml under smart_arb_translator section)');
        exit(2);
      }

      if (authMode == 'service_account') {
        final envCredentials = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS']?.trim();
        final hasCredentials = (credentialsFile != null && credentialsFile.isNotEmpty) ||
            (envCredentials != null && envCredentials.isNotEmpty);
        if (!hasCredentials) {
          _setBrightRed();
          stderr.write(
              '--credentials_file is required when --auth_mode is "service_account" (or set GOOGLE_APPLICATION_CREDENTIALS).');
          exit(2);
        }
      }
    }

    if (translationContextFile != null && translationContextFile.isNotEmpty) {
      final contextFile = File(translationContextFile);
      if (!contextFile.existsSync()) {
        _setBrightRed();
        stderr.write('--translation_context_file does not exist: $translationContextFile');
        exit(2);
      }
    }

    return mergedResult;
  }

  /// Merges command-line arguments with pubspec.yaml configuration.
  ///
  /// This method combines configuration from multiple sources, with CLI arguments
  /// taking precedence over pubspec.yaml settings. Default values are applied
  /// for any missing configuration.
  ///
  /// Parameters:
  /// - [cliResult]: Parsed command-line arguments
  /// - [pubspecConfig]: Configuration loaded from pubspec.yaml
  ///
  /// Returns merged [ArgResults] with CLI args taking precedence.
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
    if (pubspecConfig.useDeferredLoading != null) mergedOptions[_useDeferredLoading] = pubspecConfig.useDeferredLoading;
    if (pubspecConfig.translationService != null) mergedOptions[_translationService] = pubspecConfig.translationService;
    if (pubspecConfig.projectId != null) mergedOptions[_projectId] = pubspecConfig.projectId;
    if (pubspecConfig.authMode != null) mergedOptions[_authMode] = pubspecConfig.authMode;
    if (pubspecConfig.credentialsFile != null) mergedOptions[_credentialsFile] = pubspecConfig.credentialsFile;
    if (pubspecConfig.quotaProjectId != null) mergedOptions[_quotaProjectId] = pubspecConfig.quotaProjectId;
    if (pubspecConfig.openaiModel != null) mergedOptions[_openaiModel] = pubspecConfig.openaiModel;
    if (pubspecConfig.translationContext != null) {
      mergedOptions[_translationContext] = pubspecConfig.translationContext;
    }
    if (pubspecConfig.translationContextFile != null) {
      mergedOptions[_translationContextFile] = pubspecConfig.translationContextFile;
    }

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
    mergedOptions[_useDeferredLoading] ??= false;
    mergedOptions[_translationService] ??= 'google_basic';
    mergedOptions[_authMode] ??= 'api_key';
    mergedOptions[_openaiModel] ??= 'gpt-4o-mini';

    return _MergedArgResults(mergedOptions, cliResult);
  }

  /// Runs auto-configuration to prompt user for missing source configuration
  static Future<Map<String, dynamic>> _runAutoConfiguration() async {
    print('\n🔧 Auto-configuration: No source configuration found.');
    print('Let\'s set up your project configuration.\n');

    final config = <String, dynamic>{};

    // Ask for source type
    print('What type of source do you want to translate?');
    print('1. Directory (contains multiple ARB files)');
    print('2. Single file (one ARB file)');
    print('');
    print('Enter your choice (1 for directory, 2 for file): ');

    String? sourceType;
    while (sourceType == null) {
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input == '1') {
        sourceType = 'directory';
      } else if (input == '2') {
        sourceType = 'file';
      } else {
        print('Invalid choice. Please enter 1 or 2: ');
      }
    }

    // Ask for source path
    if (sourceType == 'directory') {
      print('\nEnter the directory path containing your ARB files (default: lib/l10n_source): ');
      final input = stdin.readLineSync()?.trim() ?? '';
      config[_sourceDir] = input.isEmpty ? 'lib/l10n_source' : input;
    } else {
      print('\nEnter the path to your source ARB file: ');
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input.isEmpty) {
        _setBrightRed();
        stderr.write('Source ARB file path is required.');
        exit(2);
      }
      config[_sourceArb] = input;
    }

    // Ask for source locale
    print('\nWhat is the locale of your source files? (default: en): ');
    final localeInput = stdin.readLineSync()?.trim() ?? '';
    config[_dartMainLocale] = localeInput.isEmpty ? 'en' : localeInput;

    // Ask for translation service
    print('\nWhich translation service do you want to use?');
    print('1. Google Basic (v2) - Default');
    print('   - Standard translation service');
    print('2. Google NMT (v2 with model=nmt)');
    print('   - Neural Machine Translation model');
    print('3. Google LLM (v3)');
    print('   - Large Language Model translation (requires Project ID)');
    print('4. OpenAI');
    print('   - Uses OpenAI chat models with optional translation context');
    print('');
    print('Enter your choice (1, 2, 3, or 4) [default: 1]: ');

    final serviceInput = stdin.readLineSync()?.trim() ?? '';
    String service = 'google_basic';

    if (serviceInput == '2') {
      service = 'google_nmt';
    } else if (serviceInput == '3') {
      service = 'google_llm';
    } else if (serviceInput == '4') {
      service = 'openai';
    }

    config[_translationService] = service;

    // Ask for LLM-specific auth settings if LLM is selected
    if (service == 'google_llm') {
      print('\nEnter your Google Cloud Project ID (required for LLM service): ');
      final projectIdInput = stdin.readLineSync()?.trim() ?? '';
      if (projectIdInput.isEmpty) {
        _setBrightRed();
        stderr.write('Project ID is required for LLM service.');
        exit(2);
      }
      config[_projectId] = projectIdInput;

      print('\nChoose authentication mode for Google LLM (v3):');
      print('1. ADC (recommended)');
      print('   - Uses gcloud application-default credentials or GOOGLE_APPLICATION_CREDENTIALS');
      print('2. Service account key file');
      print('   - Uses explicit JSON key path');
      print('3. API key (legacy)');
      print('   - Kept for backward compatibility; Google v3 generally expects OAuth');
      print('');
      print('Enter your choice (1, 2, or 3) [default: 1]: ');

      final authInput = stdin.readLineSync()?.trim() ?? '';
      if (authInput == '2') {
        config[_authMode] = 'service_account';
        print('\nEnter the path to your service account JSON file: ');
        final credentialsInput = stdin.readLineSync()?.trim() ?? '';
        if (credentialsInput.isEmpty) {
          _setBrightRed();
          stderr.write('Service account credentials file path is required.');
          exit(2);
        }
        config[_credentialsFile] = credentialsInput;
      } else if (authInput == '3') {
        config[_authMode] = 'api_key';
        print('\nEnter the path to your Google Translate API key file: ');
        final apiKeyInput = stdin.readLineSync()?.trim() ?? '';
        if (apiKeyInput.isEmpty) {
          _setBrightRed();
          stderr.write('Google Translate API key path is required.');
          exit(2);
        }
        config[_apiKey] = apiKeyInput;
      } else {
        config[_authMode] = 'adc';
      }
    } else if (service == 'openai') {
      config[_authMode] = 'api_key';
      print('\nEnter the path to your OpenAI API key file: ');
      final apiKeyInput = stdin.readLineSync()?.trim() ?? '';
      if (apiKeyInput.isEmpty) {
        _setBrightRed();
        stderr.write('OpenAI API key path is required.');
        exit(2);
      }
      config[_apiKey] = apiKeyInput;

      print('\nEnter OpenAI model (default: gpt-4o-mini): ');
      final openAiModelInput = stdin.readLineSync()?.trim() ?? '';
      config[_openaiModel] = openAiModelInput.isEmpty ? 'gpt-4o-mini' : openAiModelInput;
    } else {
      // V2 services require API key authentication
      config[_authMode] = 'api_key';
      print('\nEnter the path to your Google Translate API key file: ');
      final apiKeyInput = stdin.readLineSync()?.trim() ?? '';
      if (apiKeyInput.isEmpty) {
        _setBrightRed();
        stderr.write('Google Translate API key path is required.');
        exit(2);
      }
      config[_apiKey] = apiKeyInput;
    }

    // Ask for cache directory
    print('\nEnter the cache directory for translations (default: lib/l10n_cache): ');
    final cacheInput = stdin.readLineSync()?.trim() ?? '';
    config[_cacheDirectory] = cacheInput.isEmpty ? 'lib/l10n_cache' : cacheInput;

    // Ask for output directory
    print('\nEnter the output directory for translated ARB files (default: lib/l10n): ');
    final outputInput = stdin.readLineSync()?.trim() ?? '';
    config[_l10nDirectory] = outputInput.isEmpty ? 'lib/l10n' : outputInput;

    // Ask for target languages
    print('\nEnter the language codes you want to translate to (comma-separated, e.g., es,fr,de,ja): ');
    print(
        'Common language codes: es (Spanish), fr (French), de (German), ja (Japanese), zh (Chinese), pt (Portuguese), it (Italian), ru (Russian), ar (Arabic), hi (Hindi)');
    final languagesInput = stdin.readLineSync()?.trim() ?? '';
    if (languagesInput.isEmpty) {
      _setBrightRed();
      stderr.write('At least one target language code is required.');
      exit(2);
    }

    // Parse comma-separated language codes and validate they're not empty
    final languageCodes =
        languagesInput.split(',').map((code) => code.trim()).where((code) => code.isNotEmpty).toList();

    if (languageCodes.isEmpty) {
      _setBrightRed();
      stderr.write('At least one valid language code is required.');
      exit(2);
    }

    config[_languageCodes] = languageCodes;

    if (service == 'google_llm' || service == 'openai') {
      print('\nOptional: add translation context/style guide (leave blank to skip): ');
      final contextInput = stdin.readLineSync() ?? '';
      if (contextInput.trim().isNotEmpty) {
        config[_translationContext] = contextInput.trim();
      }
    }

    // Ask for localization method (including 'none' option)
    print('\nDo you want to generate Dart localization code?');
    print('1. Yes, using gen-l10n (Flutter built-in)');
    print('   - Uses l10n.yaml configuration file');
    print('   - Runs "flutter gen-l10n" command');
    print('   - Official Flutter solution');
    print('');
    print('2. Yes, using intl_utils (Third-party package)');
    print('   - Uses flutter_intl section in pubspec.yaml');
    print('   - Runs "dart run intl_utils:generate" command');
    print('   - More configuration options');
    print('');
    print('3. No, only translate ARB files');
    print('   - Skip Dart code generation');
    print('   - Only perform translation');
    print('');
    print('Enter your choice (1 for gen-l10n, 2 for intl_utils, 3 for none): ');

    while (true) {
      final input = stdin.readLineSync()?.trim() ?? '';

      if (input == '1') {
        config[_l10nMethod] = 'gen-l10n';
        config[_generateDart] = true;
        break;
      } else if (input == '2') {
        config[_l10nMethod] = 'intl_utils';
        config[_generateDart] = true;
        break;
      } else if (input == '3') {
        config[_l10nMethod] = 'none';
        config[_generateDart] = false;
        break;
      } else {
        print('Invalid choice. Please enter 1, 2, or 3: ');
      }
    }

    // Save configuration to pubspec.yaml
    await _saveAutoConfiguration(config);

    print('\n✅ Auto-configuration completed!');
    return config;
  }

  /// Saves the auto-configuration to pubspec.yaml
  static Future<void> _saveAutoConfiguration(Map<String, dynamic> config) async {
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      print('⚠️  Warning: pubspec.yaml not found, configuration not saved.');
      return;
    }

    final pubspecContent = await pubspecFile.readAsString();
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];

    bool foundSmartArbConfig = false;
    bool inSmartArbConfig = false;
    int smartArbIndent = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if we're entering smart_arb_translator section (but not as a dependency)
      if (trimmedLine == 'smart_arb_translator:' && !_isInDependencySection(lines, i)) {
        foundSmartArbConfig = true;
        inSmartArbConfig = true;
        smartArbIndent = line.indexOf('smart_arb_translator:');
        modifiedLines.add(line);

        // Add all configuration options
        config.forEach((key, value) {
          final configKey = key.startsWith('_') ? key.substring(1) : key;
          if (value is List) {
            // Handle list values (like language_codes)
            final listItems = value.map((item) => '"$item"').join(', ');
            modifiedLines.add('${' ' * (smartArbIndent + 2)}$configKey: [$listItems]');
          } else {
            modifiedLines.add('${' ' * (smartArbIndent + 2)}$configKey: $value');
          }
        });
        continue;
      }

      // Check if we're leaving smart_arb_translator section
      if (inSmartArbConfig && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inSmartArbConfig = false;
      }

      // Skip existing configuration lines in smart_arb_translator section
      if (inSmartArbConfig && _isConfigurationLine(trimmedLine)) {
        continue;
      }

      modifiedLines.add(line);
    }

    // If smart_arb_translator section doesn't exist, add it
    if (!foundSmartArbConfig) {
      // Ensure there's a blank line before the new section
      if (modifiedLines.isNotEmpty && modifiedLines.last.trim().isNotEmpty) {
        modifiedLines.add('');
      }
      modifiedLines.add('smart_arb_translator:');
      config.forEach((key, value) {
        final configKey = key.startsWith('_') ? key.substring(1) : key;
        if (value is List) {
          // Handle list values (like language_codes)
          final listItems = value.map((item) => '"$item"').join(', ');
          modifiedLines.add('  $configKey: [$listItems]');
        } else {
          modifiedLines.add('  $configKey: $value');
        }
      });
    }

    await pubspecFile.writeAsString(modifiedLines.join('\n'));
    print('💾 Saved configuration to pubspec.yaml');
  }

  /// Helper method to check if a line is a configuration line
  static bool _isConfigurationLine(String trimmedLine) {
    final configKeys = [
      'source_arb:',
      'source_dir:',
      'api_key:',
      'cache_directory:',
      'language_codes:',
      'output_file_name:',
      'l10n_directory:',
      'generate_dart:',
      'dart_class_name:',
      'dart_output_dir:',
      'dart_main_locale:',
      'auto_approve:',
      'l10n_method:',
      'use_deferred_loading:',
      'translation_service:',
      'project_id:',
      'auth_mode:',
      'credentials_file:',
      'quota_project_id:',
      'openai_model:',
      'translation_context:',
      'translation_context_file:'
    ];
    return configKeys.any((key) => trimmedLine.startsWith(key));
  }

  /// Helper method to check if a line is within a dependency section
  static bool _isInDependencySection(List<String> lines, int currentIndex) {
    // Look backwards to find if we're in a dependencies or dev_dependencies section
    for (int i = currentIndex - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line == 'dependencies:' || line == 'dev_dependencies:') {
        return true;
      }
      // If we hit another top-level section, we're not in dependencies
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t') && line.endsWith(':')) {
        return false;
      }
    }
    return false;
  }

  /// Updates merged result with new configuration
  static ArgResults _updateMergedResult(ArgResults originalResult, Map<String, dynamic> updates) {
    final Map<String, dynamic> mergedOptions = {};

    // Copy existing options
    for (final option in originalResult.options) {
      mergedOptions[option] = originalResult[option];
    }

    // Apply updates
    updates.forEach((key, value) {
      mergedOptions[key] = value;
    });

    // Get the underlying original result if it's a _MergedArgResults, otherwise use the original
    final underlyingResult = originalResult is _MergedArgResults ? originalResult._originalResult : originalResult;

    return _MergedArgResults(mergedOptions, underlyingResult);
  }

  static void _setBrightRed() {
    Console.setTextColor(1, bright: true);
  }

  static List<String> _normalizeFlagAliases(List<String> args) {
    return args
        .map((arg) => switch (arg) {
              '--clean_corrupted_cache' => '--clean-corrupted-cache',
              '--dry_run' => '--dry-run',
              _ => arg,
            })
        .toList();
  }

  static bool _wasOptionExplicitlyProvided(List<String> args, String optionName) {
    final prefixedName = '--$optionName';
    return args.any((arg) => arg == prefixedName || arg.startsWith('$prefixedName='));
  }

  // Getters for argument names
  static String get sourceArb => _sourceArb;
  static String get sourceDir => _sourceDir;
  static String get apiKey => _apiKey;
  static String get help => _help;
  static String get cleanCorruptedCache => _cleanCorruptedCache;
  static String get dryRun => _dryRun;
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
  static String get useDeferredLoading => _useDeferredLoading;
  static String get translationService => _translationService;
  static String get projectId => _projectId;
  static String get authMode => _authMode;
  static String get credentialsFile => _credentialsFile;
  static String get quotaProjectId => _quotaProjectId;
  static String get openaiModel => _openaiModel;
  static String get translationContext => _translationContext;
  static String get translationContextFile => _translationContextFile;
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
