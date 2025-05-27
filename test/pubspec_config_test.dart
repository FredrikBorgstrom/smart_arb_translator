import 'dart:io';

import 'package:smart_arb_translator/src/pubspec_config.dart';
import 'package:test/test.dart';

void main() {
  group('PubspecConfig', () {
    late Directory tempDir;
    late File tempPubspec;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('pubspec_config_test');
      tempPubspec = File('${tempDir.path}/pubspec.yaml');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should return null when pubspec.yaml does not exist', () {
      final config = PubspecConfig.loadFromPubspec('non_existent_pubspec.yaml');
      expect(config, isNull);
    });

    test('should return null when smart_arb_translator section is missing', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0
dependencies:
  flutter:
    sdk: flutter
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);
      expect(config, isNull);
    });

    test('should load basic configuration from pubspec.yaml', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  language_codes: [es, fr, de]
  generate_dart: true
  dart_class_name: AppLocalizations
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);

      expect(config, isNotNull);
      expect(config!.sourceDir, equals('lib/l10n'));
      expect(config.apiKey, equals('api_key.txt'));
      expect(config.languageCodes, equals(['es', 'fr', 'de']));
      expect(config.generateDart, isTrue);
      expect(config.dartClassName, equals('AppLocalizations'));
    });

    test('should parse language codes from comma-separated string', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  language_codes: "es,fr,de,it"
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);

      expect(config, isNotNull);
      expect(config!.languageCodes, equals(['es', 'fr', 'de', 'it']));
    });

    test('should handle all configuration options', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_arb: lib/l10n/app_en.arb
  source_dir: lib/l10n
  api_key: secrets/api_key.txt
  cache_directory: lib/cache
  language_codes: [es, fr, de, it, pt]
  output_file_name: intl
  l10n_directory: lib/l10n_output
  generate_dart: false
  dart_class_name: MyLocalizations
  dart_output_dir: lib/my_generated
  dart_main_locale: en_US
  auto_approve: true
  l10n_method: intl_utils
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);

      expect(config, isNotNull);
      expect(config!.sourceArb, equals('lib/l10n/app_en.arb'));
      expect(config.sourceDir, equals('lib/l10n'));
      expect(config.apiKey, equals('secrets/api_key.txt'));
      expect(config.cacheDirectory, equals('lib/cache'));
      expect(config.languageCodes, equals(['es', 'fr', 'de', 'it', 'pt']));
      expect(config.outputFileName, equals('intl'));
      expect(config.l10nDirectory, equals('lib/l10n_output'));
      expect(config.generateDart, isFalse);
      expect(config.dartClassName, equals('MyLocalizations'));
      expect(config.dartOutputDir, equals('lib/my_generated'));
      expect(config.dartMainLocale, equals('en_US'));
      expect(config.autoApprove, isTrue);
      expect(config.l10nMethod, equals('intl_utils'));
    });

    test('should handle malformed YAML gracefully', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0
smart_arb_translator:
  source_dir: lib/l10n
  api_key: [invalid: yaml: structure
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);
      expect(config, isNull);
    });

    test('hasAnyConfig should return true when any config is present', () {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
''');

      final config = PubspecConfig.loadFromPubspec(tempPubspec.path);
      expect(config, isNotNull);
      expect(config!.hasAnyConfig, isTrue);
    });

    test('hasAnyConfig should return false when no config is present', () {
      const config = PubspecConfig();
      expect(config.hasAnyConfig, isFalse);
    });
  });
}
