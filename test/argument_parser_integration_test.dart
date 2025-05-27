import 'dart:io';

import 'package:smart_arb_translator/src/argument_parser.dart';
import 'package:test/test.dart';

void main() {
  group('ArbTranslatorArgumentParser Integration', () {
    late Directory tempDir;
    late File tempPubspec;
    late String originalDir;

    setUp(() {
      originalDir = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('arg_parser_test');
      tempPubspec = File('${tempDir.path}/pubspec.yaml');
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = originalDir;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should use CLI arguments when no pubspec config exists', () async {
      // Create a basic pubspec without smart_arb_translator section
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([
        '--source_dir',
        'lib/l10n',
        '--api_key',
        'api_key.txt',
        '--language_codes',
        'es,fr',
      ]);

      expect(result[ArbTranslatorArgumentParser.sourceDir], equals('lib/l10n'));
      expect(result[ArbTranslatorArgumentParser.apiKey], equals('api_key.txt'));
      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['es', 'fr']));
    });

    test('should merge pubspec config with CLI arguments (CLI takes precedence)', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n_from_pubspec
  api_key: pubspec_api_key.txt
  language_codes: [de, it]
  generate_dart: true
  dart_class_name: PubspecLocalizations
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([
        '--api_key', 'cli_api_key.txt', // This should override pubspec
        '--language_codes', 'es,fr', // This should override pubspec
      ]);

      // CLI arguments should take precedence
      expect(result[ArbTranslatorArgumentParser.apiKey], equals('cli_api_key.txt'));
      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['es', 'fr']));

      // Pubspec values should be used when CLI doesn't override
      expect(result[ArbTranslatorArgumentParser.sourceDir], equals('lib/l10n_from_pubspec'));
      expect(result[ArbTranslatorArgumentParser.generateDart], isTrue);
      expect(result[ArbTranslatorArgumentParser.dartClassName], equals('PubspecLocalizations'));
    });

    test('should use only pubspec config when no CLI arguments provided', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: pubspec_api_key.txt
  language_codes: [es, fr, de]
  generate_dart: false
  dart_class_name: AppLocalizations
  dart_output_dir: lib/my_generated
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);

      expect(result[ArbTranslatorArgumentParser.sourceDir], equals('lib/l10n'));
      expect(result[ArbTranslatorArgumentParser.apiKey], equals('pubspec_api_key.txt'));
      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['es', 'fr', 'de']));
      expect(result[ArbTranslatorArgumentParser.generateDart], isFalse);
      expect(result[ArbTranslatorArgumentParser.dartClassName], equals('AppLocalizations'));
      expect(result[ArbTranslatorArgumentParser.dartOutputDir], equals('lib/my_generated'));
    });

    test('should apply defaults for missing values', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);

      // Check that defaults are applied
      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['es']));
      expect(result[ArbTranslatorArgumentParser.outputFileName], equals('intl_'));
      expect(result[ArbTranslatorArgumentParser.generateDart], isTrue);
      expect(result[ArbTranslatorArgumentParser.dartOutputDir], equals('lib/generated'));
      expect(result[ArbTranslatorArgumentParser.dartMainLocale], equals('en'));
      expect(result[ArbTranslatorArgumentParser.autoApprove], isFalse);
      expect(result[ArbTranslatorArgumentParser.useDeferredLoading], isFalse);
    });

    test('should handle comma-separated language codes from pubspec', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  language_codes: "es,fr,de,it"
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);

      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['es', 'fr', 'de', 'it']));
    });

    test('should handle use_deferred_loading parameter from CLI and pubspec', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  use_deferred_loading: true
''');

      // Test pubspec value when no CLI override
      var result = await ArbTranslatorArgumentParser.parseArguments([]);
      expect(result[ArbTranslatorArgumentParser.useDeferredLoading], isTrue);

      // Test CLI flag (true) - should override pubspec
      result = await ArbTranslatorArgumentParser.parseArguments([
        '--use_deferred_loading',
      ]);
      expect(result[ArbTranslatorArgumentParser.useDeferredLoading], isTrue);

      // Test with pubspec false and no CLI flag
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  use_deferred_loading: false
''');

      result = await ArbTranslatorArgumentParser.parseArguments([]);
      expect(result[ArbTranslatorArgumentParser.useDeferredLoading], isFalse);

      // Test CLI flag overriding pubspec false
      result = await ArbTranslatorArgumentParser.parseArguments([
        '--use_deferred_loading',
      ]);
      expect(result[ArbTranslatorArgumentParser.useDeferredLoading], isTrue);
    });
  });
}
