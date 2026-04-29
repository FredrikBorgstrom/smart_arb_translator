import 'dart:io';

import 'package:yaml/yaml.dart';

/// Configuration class for reading smart_arb_translator settings from pubspec.yaml.
///
/// This class provides a structured way to load and access configuration
/// settings for the Smart ARB Translator from the pubspec.yaml file.
/// It supports all the same configuration options available via command-line
/// arguments, allowing users to store their settings in the project file.
///
/// Configuration is read from the `smart_arb_translator` section in pubspec.yaml:
/// ```yaml
/// smart_arb_translator:
///   source_dir: lib/l10n_source
///   api_key: path/to/api_key.txt
///   language_codes: [es, fr, de]
///   l10n_directory: lib/l10n
///   generate_dart: true
/// ```
class PubspecConfig {
  /// Path to the source ARB file to translate.
  final String? sourceArb;

  /// Directory containing source ARB files to translate recursively.
  final String? sourceDir;

  /// Path to an API key file (Google or OpenAI depending on service).
  final String? apiKey;

  /// Directory where translation cache will be stored.
  final String? cacheDirectory;

  /// List of target language codes for translation.
  final List<String>? languageCodes;

  /// Prefix for output ARB file names.
  final String? outputFileName;

  /// Directory where translated ARB files will be saved.
  final String? l10nDirectory;

  /// Whether to generate Dart localization code.
  final bool? generateDart;

  /// Name for the generated Dart localization class.
  final String? dartClassName;

  /// Directory for generated Dart localization files.
  final String? dartOutputDir;

  /// Main locale for Dart code generation.
  final String? dartMainLocale;

  /// Whether to automatically approve configuration changes.
  final bool? autoApprove;

  /// Localization method to use ('gen-l10n', 'intl_utils', or 'none').
  final String? l10nMethod;

  /// Whether to enable deferred loading for locales.
  final bool? useDeferredLoading;

  /// The translation service to use ('basic', 'nmt', or 'llm').
  final String? translationService;

  /// The Google Cloud Project ID (required for 'llm' service).
  final String? projectId;

  /// Authentication mode for translation API requests.
  ///
  /// - `api_key`: Uses API key query parameter authentication.
  /// - `adc`: Uses Application Default Credentials (OAuth2).
  /// - `service_account`: Uses a service account JSON key file (OAuth2).
  final String? authMode;

  /// Optional path to a service account JSON file.
  ///
  /// Used when [authMode] is `service_account`.
  final String? credentialsFile;

  /// Optional quota/billing project id for OAuth requests.
  ///
  /// Mapped to the `x-goog-user-project` header.
  final String? quotaProjectId;

  /// OpenAI model to use when `translation_service` is `openai`.
  final String? openaiModel;

  /// Optional context prompt to guide LLM translations.
  final String? translationContext;

  /// Optional file path that contains translation context text.
  final String? translationContextFile;

  /// Optional maximum number of per-language translation calls executed concurrently
  /// for a single source ARB file.
  ///
  /// `null` falls back to the default of `1`, preserving the original sequential
  /// behavior. Increase this to send multiple language requests in parallel and
  /// reduce wall-clock time for large language lists.
  final int? parallelTranslations;

  /// Creates a new pubspec configuration instance.
  ///
  /// All parameters are optional and correspond to the configuration
  /// options available in the pubspec.yaml file.
  const PubspecConfig({
    this.sourceArb,
    this.sourceDir,
    this.apiKey,
    this.cacheDirectory,
    this.languageCodes,
    this.outputFileName,
    this.l10nDirectory,
    this.generateDart,
    this.dartClassName,
    this.dartOutputDir,
    this.dartMainLocale,
    this.autoApprove,
    this.l10nMethod,
    this.useDeferredLoading,
    this.translationService,
    this.projectId,
    this.authMode,
    this.credentialsFile,
    this.quotaProjectId,
    this.openaiModel,
    this.translationContext,
    this.translationContextFile,
    this.parallelTranslations,
  });

  /// Loads configuration from a pubspec.yaml file.
  ///
  /// This static method reads the specified pubspec.yaml file and extracts
  /// the smart_arb_translator configuration section. If the file doesn't exist
  /// or doesn't contain the configuration section, returns null.
  ///
  /// Parameters:
  /// - [pubspecPath]: Path to the pubspec.yaml file (defaults to 'pubspec.yaml')
  ///
  /// Returns a [PubspecConfig] instance with the loaded configuration,
  /// or null if no configuration is found or an error occurs.
  ///
  /// Example:
  /// ```dart
  /// final config = PubspecConfig.loadFromPubspec();
  /// if (config != null) {
  ///   print('Source directory: ${config.sourceDir}');
  /// }
  /// ```
  static PubspecConfig? loadFromPubspec([String pubspecPath = 'pubspec.yaml']) {
    try {
      final pubspecFile = File(pubspecPath);
      if (!pubspecFile.existsSync()) {
        return null;
      }

      final yamlContent = pubspecFile.readAsStringSync();
      final yamlMap = loadYaml(yamlContent) as YamlMap?;

      if (yamlMap == null) {
        return null;
      }

      final config = yamlMap['smart_arb_translator'] as YamlMap?;
      if (config == null) {
        return null;
      }

      return PubspecConfig(
        sourceArb: config['source_arb'] as String?,
        sourceDir: config['source_dir'] as String?,
        apiKey: config['api_key'] as String?,
        cacheDirectory: config['cache_directory'] as String?,
        languageCodes: _parseLanguageCodes(config['language_codes']),
        outputFileName: config['output_file_name'] as String?,
        l10nDirectory: config['l10n_directory'] as String?,
        generateDart: config['generate_dart'] as bool?,
        dartClassName: config['dart_class_name'] as String?,
        dartOutputDir: config['dart_output_dir'] as String?,
        dartMainLocale: config['dart_main_locale'] as String?,
        autoApprove: config['auto_approve'] as bool?,
        l10nMethod: config['l10n_method'] as String?,
        useDeferredLoading: config['use_deferred_loading'] as bool?,
        translationService: config['translation_service'] as String?,
        projectId: config['project_id'] as String?,
        authMode: config['auth_mode'] as String?,
        credentialsFile: config['credentials_file'] as String?,
        quotaProjectId: config['quota_project_id'] as String?,
        openaiModel: config['openai_model'] as String?,
        translationContext: config['translation_context'] as String?,
        translationContextFile: config['translation_context_file'] as String?,
        parallelTranslations: _parsePositiveInt(config['parallel_translations']),
      );
    } catch (e) {
      // If there's any error reading the config, return null
      // This allows the CLI to fall back to command-line arguments
      return null;
    }
  }

  /// Parses language codes from various YAML formats.
  ///
  /// This private helper method handles different ways language codes
  /// can be specified in the YAML configuration:
  /// - As a comma-separated string: "es,fr,de"
  /// - As a YAML list: [es, fr, de]
  /// - As a regular Dart list
  ///
  /// Parameters:
  /// - [languageCodes]: The language codes value from YAML
  ///
  /// Returns a list of language code strings, or null if parsing fails.
  static List<String>? _parseLanguageCodes(dynamic languageCodes) {
    if (languageCodes == null) return null;

    if (languageCodes is String) {
      // Handle comma-separated string: "es,fr,de"
      return languageCodes.split(',').map((e) => e.trim()).toList();
    } else if (languageCodes is YamlList) {
      // Handle YAML list: [es, fr, de]
      return languageCodes.map((e) => e.toString()).toList();
    } else if (languageCodes is List) {
      // Handle regular list
      return languageCodes.map((e) => e.toString()).toList();
    }

    return null;
  }

  /// Parses an optional positive integer from a YAML scalar value.
  ///
  /// Accepts native ints or numeric strings, returning `null` for any other
  /// value or when the parsed result is less than 1.
  static int? _parsePositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value < 1 ? null : value;
    final parsed = int.tryParse(value.toString().trim());
    if (parsed == null || parsed < 1) return null;
    return parsed;
  }

  /// Checks if any configuration values are present.
  ///
  /// This getter returns true if at least one configuration option
  /// has been set, indicating that the pubspec.yaml file contains
  /// smart_arb_translator configuration.
  ///
  /// Returns true if any configuration is present, false otherwise.
  bool get hasAnyConfig {
    return sourceArb != null ||
        sourceDir != null ||
        apiKey != null ||
        cacheDirectory != null ||
        languageCodes != null ||
        outputFileName != null ||
        l10nDirectory != null ||
        generateDart != null ||
        dartClassName != null ||
        dartOutputDir != null ||
        dartMainLocale != null ||
        autoApprove != null ||
        l10nMethod != null ||
        useDeferredLoading != null ||
        translationService != null ||
        projectId != null ||
        authMode != null ||
        credentialsFile != null ||
        quotaProjectId != null ||
        openaiModel != null ||
        translationContext != null ||
        translationContextFile != null ||
        parallelTranslations != null;
  }

  /// Returns a string representation of this configuration.
  ///
  /// This method provides a detailed string representation of all
  /// configuration values, useful for debugging and logging.
  @override
  String toString() {
    return 'PubspecConfig('
        'sourceArb: $sourceArb, '
        'sourceDir: $sourceDir, '
        'apiKey: $apiKey, '
        'cacheDirectory: $cacheDirectory, '
        'languageCodes: $languageCodes, '
        'outputFileName: $outputFileName, '
        'l10nDirectory: $l10nDirectory, '
        'generateDart: $generateDart, '
        'dartClassName: $dartClassName, '
        'dartOutputDir: $dartOutputDir, '
        'dartMainLocale: $dartMainLocale, '
        'autoApprove: $autoApprove, '
        'l10nMethod: $l10nMethod, '
        'useDeferredLoading: $useDeferredLoading, '
        'translationService: $translationService, '
        'projectId: $projectId, '
        'authMode: $authMode, '
        'credentialsFile: $credentialsFile, '
        'quotaProjectId: $quotaProjectId, '
        'openaiModel: $openaiModel, '
        'translationContext: $translationContext, '
        'translationContextFile: $translationContextFile, '
        'parallelTranslations: $parallelTranslations'
        ')';
  }
}
