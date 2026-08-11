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
      expect(result[ArbTranslatorArgumentParser.authMode], equals('api_key'));
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

    test('should allow clean-corrupted-cache mode without source or api key', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([
        '--clean-corrupted-cache',
      ]);

      expect(result[ArbTranslatorArgumentParser.cleanCorruptedCache], isTrue);
      expect(result[ArbTranslatorArgumentParser.sourceDir], isNull);
      expect(result[ArbTranslatorArgumentParser.sourceArb], isNull);
      expect(result[ArbTranslatorArgumentParser.apiKey], isNull);
      expect(result[ArbTranslatorArgumentParser.languageCodes], isNull);
    });

    test('should support cleanup flag aliases and explicit language filtering', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  language_codes: [de, it]
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([
        '--clean_corrupted_cache',
        '--dry_run',
        '--language_codes',
        'sv,ar',
      ]);

      expect(result[ArbTranslatorArgumentParser.cleanCorruptedCache], isTrue);
      expect(result[ArbTranslatorArgumentParser.dryRun], isTrue);
      expect(result[ArbTranslatorArgumentParser.languageCodes], equals(['sv', 'ar']));
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

    test('should allow google_llm with adc auth mode without api_key', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  translation_service: google_llm
  project_id: my-project
  auth_mode: adc
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);
      expect(result[ArbTranslatorArgumentParser.translationService], equals('google_llm'));
      expect(result[ArbTranslatorArgumentParser.projectId], equals('my-project'));
      expect(result[ArbTranslatorArgumentParser.authMode], equals('adc'));
      expect(result[ArbTranslatorArgumentParser.apiKey], isNull);
    });

    test('should allow google_llm with service_account auth mode and credentials file without api_key', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  translation_service: google_llm
  project_id: my-project
  auth_mode: service_account
  credentials_file: secrets/service-account.json
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);
      expect(result[ArbTranslatorArgumentParser.translationService], equals('google_llm'));
      expect(result[ArbTranslatorArgumentParser.projectId], equals('my-project'));
      expect(result[ArbTranslatorArgumentParser.authMode], equals('service_account'));
      expect(result[ArbTranslatorArgumentParser.credentialsFile], equals('secrets/service-account.json'));
      expect(result[ArbTranslatorArgumentParser.apiKey], isNull);
    });

    test('should support openai settings from pubspec including translation context', () async {
      File('${tempDir.path}/context.txt').writeAsStringSync('Use a friendly product tone');

      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  translation_service: openai
  api_key: openai_key.txt
  openai_model: gpt-4.1-mini
  translation_context: Keep product names in English
  translation_context_file: context.txt
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);
      expect(result[ArbTranslatorArgumentParser.translationService], equals('openai'));
      expect(result[ArbTranslatorArgumentParser.apiKey], equals('openai_key.txt'));
      expect(result[ArbTranslatorArgumentParser.openaiModel], equals('gpt-4.1-mini'));
      expect(result[ArbTranslatorArgumentParser.translationContext], equals('Keep product names in English'));
      expect(result[ArbTranslatorArgumentParser.translationContextFile], equals('context.txt'));
      expect(result[ArbTranslatorArgumentParser.authMode], equals('api_key'));
    });

    test('should allow CLI openai overrides for model and context', () async {
      File('${tempDir.path}/style_guide.txt').writeAsStringSync('Prefer short verbs');

      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  api_key: openai_key.txt
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([
        '--translation_service',
        'openai',
        '--openai_model',
        'gpt-4.1-mini',
        '--translation_context',
        'Use casual tone',
        '--translation_context_file',
        'style_guide.txt',
      ]);

      expect(result[ArbTranslatorArgumentParser.translationService], equals('openai'));
      expect(result[ArbTranslatorArgumentParser.openaiModel], equals('gpt-4.1-mini'));
      expect(result[ArbTranslatorArgumentParser.translationContext], equals('Use casual tone'));
      expect(result[ArbTranslatorArgumentParser.translationContextFile], equals('style_guide.txt'));
    });

    test('should support a local LLM from pubspec without an API key', () async {
      tempPubspec.writeAsStringSync('''
name: test_app
version: 1.0.0

smart_arb_translator:
  source_dir: lib/l10n
  translation_service: local_llm
  local_llm_url: http://127.0.0.1:11434/v1
  local_llm_model: qwen2.5:32b
  local_llm_json_mode: false
  local_llm_timeout_seconds: 900
  local_llm_max_output_tokens: 768
  local_llm_reasoning_effort: none
''');

      final result = await ArbTranslatorArgumentParser.parseArguments([]);

      expect(result[ArbTranslatorArgumentParser.translationService], equals('local_llm'));
      expect(result[ArbTranslatorArgumentParser.apiKey], isNull);
      expect(result[ArbTranslatorArgumentParser.localLlmUrl], equals('http://127.0.0.1:11434/v1'));
      expect(result[ArbTranslatorArgumentParser.localLlmModel], equals('qwen2.5:32b'));
      expect(result[ArbTranslatorArgumentParser.localLlmJsonMode], isFalse);
      expect(
        ArbTranslatorArgumentParser.parseLocalLlmTimeoutSeconds(
          result[ArbTranslatorArgumentParser.localLlmTimeoutSeconds],
        ),
        equals(900),
      );
      expect(
        ArbTranslatorArgumentParser.parseLocalLlmMaxOutputTokens(
          result[ArbTranslatorArgumentParser.localLlmMaxOutputTokens],
        ),
        equals(768),
      );
      expect(
        result[ArbTranslatorArgumentParser.localLlmReasoningEffort],
        equals('none'),
      );
    });
  });
}
