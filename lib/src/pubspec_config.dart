import 'dart:io';

import 'package:yaml/yaml.dart';

/// Configuration class for reading smart_arb_translator settings from pubspec.yaml
class PubspecConfig {
  final String? sourceArb;
  final String? sourceDir;
  final String? apiKey;
  final String? cacheDirectory;
  final List<String>? languageCodes;
  final String? outputFileName;
  final String? l10nDirectory;
  final bool? generateDart;
  final String? dartClassName;
  final String? dartOutputDir;
  final String? dartMainLocale;
  final bool? autoApprove;
  final String? l10nMethod;

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
  });

  /// Load configuration from pubspec.yaml file
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
      );
    } catch (e) {
      // If there's any error reading the config, return null
      // This allows the CLI to fall back to command-line arguments
      return null;
    }
  }

  /// Parse language codes from various YAML formats
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

  /// Check if any configuration is present
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
        l10nMethod != null;
  }

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
        'l10nMethod: $l10nMethod'
        ')';
  }
}
