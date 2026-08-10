/// Smart ARB Translator - An intelligent command-line utility for translating ARB files
///
/// This package provides smart translation capabilities for ARB (Application Resource Bundle) files
/// using Google Translate, OpenAI, and local LLMs with features like:
/// - Smart change detection to only translate modified content
/// - Modular architecture for better maintainability
/// - Support for both single files and directory processing
/// - Automatic merging to l10n directory structure
/// - Integrated Dart code generation using intl_utils
///
/// Usage:
/// ```bash
/// dart pub global activate smart_arb_translator
/// smart_arb_translator --source_dir lib/l10n --api_key path/to/api_key.txt --language_codes es,fr,de --generate_dart
/// ```
library;

export 'src/arb_processor.dart';
export 'src/argument_parser.dart';
export 'src/cache_cleanup.dart';
export 'src/console_utils.dart';
export 'src/dart_code_generator.dart';
export 'src/directory_processor.dart';
export 'src/file_operations.dart';
export 'src/icu_parser.dart';
export 'src/localization_validator.dart';
export 'src/models/arb_attributes.dart';
// Model exports
export 'src/models/arb_document.dart';
export 'src/models/arb_resource.dart';
export 'src/models/local_llm_options.dart';
export 'src/models/translation_resource.dart';
export 'src/models/google_resource_adapter.dart';
export 'src/pubspec_config.dart';
export 'src/reviewed_overlay.dart';
export 'src/single_file_processor.dart';
// Core functionality exports
export 'src/translation_service.dart';
// Utility exports
export 'src/utils.dart';
