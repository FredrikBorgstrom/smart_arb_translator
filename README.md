# Smart ARB Translator

An intelligent command-line utility for translating ARB (Application Resource Bundle) files using Google Translate API. This package features smart change detection that only translates messages that have been added or changed. This will keep your translation costs to a minimum. A cost-saving end-to-end solution that translates your messages to Dart classes in the languages of your choice.

## 🚀 Features

- **Smart Change Detection**: Only translates modified or new content, saving API calls and time
- **Batch Processing**: Translate entire folders recursively or a single source file
- **Manual Translation Override**: Support for custom translations via `@x-translations` metadata
- **🆕 Dual Localization Support**: Choose between Flutter's built-in `gen-l10n` or `intl_utils` package
- **🤖 Auto-Configuration**: Automatically detects and configures your preferred localization method
- **📝 Intelligent Setup**: Creates `l10n.yaml` or configures `pubspec.yaml` automatically
- **🔧 Dart Code Generation**: Generate ready-to-use Dart localization code with either method
- **Stats**: Gives you full statistics on the number of translations made


## 📦 Installation

### Global Installation (Recommended)

```bash
dart pub global activate smart_arb_translator
```

### Local Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  smart_arb_translator: ^1.0.1
```

Then run:

```bash
dart pub get
```

## 🚀 Quick Start

### 1. Get a Google Translate API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Translate API
4. Create credentials (API Key)
5. Save your API key to a text file (e.g., `api_key.txt`)

### 2. One-Command Translation + Code Generation

```bash
# Complete Flutter i18n workflow in one command
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --dart_class_name AppLocalizations
```

This single command will:
- ✅ Translate your ARB files to multiple languages
- ✅ Generate type-safe Dart localization code
- ✅ Set up everything for Flutter integration

### 3. Use in Your Flutter App

```dart
import 'lib/generated/l10n.dart';

// In your MaterialApp
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ... rest of your app
)

// In your widgets
Text(AppLocalizations.of(context).yourTranslationKey)
```

## 🔧 Setup

### 1. Google Translate API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Translate API
4. Create credentials (API Key)
5. Save your API key to a text file (e.g., `api_key.txt`)

### 2. ARB File Structure

Ensure your ARB files follow the standard format:

```json
{
  "@@locale": "en",
  "@@last_modified": "2024-01-01T00:00:00.000Z",
  "hello": "Hello",
  "@hello": {
    "description": "A greeting message"
  },
  "welcome": "Welcome {name}!",
  "@welcome": {
    "description": "Welcome message with name placeholder",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
```

## 🎯 Usage

### Command Line Interface

#### Translate a Directory

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key path/to/api_key.txt \
  --language_codes es,fr,de,it \
  --cache_directory lib/l10n_cache \
  --l10n_directory lib/l10n
```

#### Translate a Single File

```bash
smart_arb_translator \
  --source_arb lib/l10n/app_en.arb \
  --api_key path/to/api_key.txt \
  --language_codes es,fr \
  --output_file_name app
```

#### Complete Translation + Dart Code Generation (NEW!)

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key path/to/api_key.txt \
  --language_codes es,fr,de,it \
  --generate_dart \
  --dart_class_name AppLocalizations \
  --dart_output_dir lib/generated
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--source_dir` | Source directory containing ARB files | - |
| `--source_arb` | Single ARB file to translate | - |
| `--api_key` | Path to Google Translate API key file | **Required** |
| `--language_codes` | Comma-separated target language codes | `es` |
| `--cache_directory` | Directory for translation cache | `lib/l10n_cache` |
| `--l10n_directory` | Output directory for merged files | `lib/l10n` |
| `--output_file_name` | Custom output filename | `intl_` |
| `--generate_dart` | Generate Dart localization code | `false` |
| `--l10n_method` | Localization method: `gen-l10n` or `intl_utils` | Auto-detect |
| `--dart_class_name` | Name for generated localization class | `S` |
| `--dart_output_dir` | Directory for generated Dart files | `lib/generated` |
| `--dart_main_locale` | Main locale for Dart code generation | `en` |
| `--auto_approve` | Auto-approve configuration changes | `false` |


### Programmatic Usage

```dart
import 'package:smart_arb_translator/smart_arb_translator.dart';

void main() async {
  // Create translation service
  final translationService = TranslationService();
  
  // Translate texts
  final translations = await translationService.translateTexts(
    translateList: ['Hello', 'World'],
    parameters: {'target': 'es', 'key': 'your-api-key'},
  );
  
  print(translations); // ['Hola', 'Mundo']
}
```

## 🎨 Advanced Features

### 🔄 Dual Localization Method Support

Smart ARB Translator supports both Flutter's official localization solution and the popular third-party package:

#### **Flutter gen-l10n (Official)**
- ✅ Official Flutter solution
- ✅ Uses `l10n.yaml` configuration
- ✅ Runs `flutter gen-l10n` command
- ✅ Integrated with Flutter SDK

#### **intl_utils (Third-party)**
- ✅ More configuration options
- ✅ Uses `flutter_intl` section in `pubspec.yaml`
- ✅ Runs `dart run intl_utils:generate`
- ✅ Popular community package

#### **🤖 Intelligent Auto-Detection**

The tool automatically chooses the best method for your project:

1. **Existing `l10n.yaml`** → Uses `gen-l10n`
2. **Existing `intl_utils` setup** → Uses `intl_utils`
3. **Saved preference** → Uses your previous choice
4. **No setup found** → Prompts you to choose (or uses `intl_utils` with `--auto_approve`)

#### **Manual Method Selection**

```bash
# Force gen-l10n method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart \
  --l10n_method gen-l10n

# Force intl_utils method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart \
  --l10n_method intl_utils
```

#### **🔧 Auto-Configuration**

The tool automatically sets up your project:

**For gen-l10n:**
- Creates `l10n.yaml` with proper configuration
- Sets up ARB directory and output paths
- Configures template file and class name

**For intl_utils:**
- Adds `intl_utils` to `dev_dependencies`
- Creates `flutter_intl` configuration in `pubspec.yaml`
- Sets up ARB directory and output paths

### Dart Code Generation Integration

Smart ARB Translator includes integrated Dart code generation with both methods, providing a complete end-to-end solution:

#### Benefits:
- **One Command Solution**: Translate and generate Dart code in a single step
- **Consistent Configuration**: Same settings for translation and code generation
- **Automatic Setup**: Handles `pubspec.yaml` configuration automatically
- **Type Safety**: Generated Dart code provides compile-time safety
- **IDE Support**: Full autocomplete and refactoring support
- **Performance**: Optimized for large projects with smart caching

#### Workflow Comparison:

**Before (Multiple Tools):**
```bash
# Step 1: Translate ARB files
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr

# Step 2: Choose and configure localization method
# Option A: Setup gen-l10n manually
# - Create l10n.yaml
# - Configure paths and class names
# - Run: flutter gen-l10n

# Option B: Setup intl_utils manually  
# - Install: dart pub add dev:intl_utils
# - Configure pubspec.yaml flutter_intl section
# - Run: dart run intl_utils:generate
```

**After (Integrated Solution):**
```bash
# Single command does everything automatically
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart
  
# The tool will:
# ✅ Translate your ARB files
# ✅ Auto-detect or prompt for localization method
# ✅ Configure l10n.yaml or pubspec.yaml automatically
# ✅ Generate type-safe Dart code
# ✅ Save your preference for future runs
```

### Manual Translation Overrides

You can provide manual translations that will override Google Translate results:

```json
{
  "greeting": "Hello",
  "@greeting": {
    "description": "A simple greeting",
    "@x-translations": {
      "es": "¡Hola!",
      "fr": "Salut!"
    }
  }
}
```

### Smart Change Detection

The tool automatically detects:
- New translation keys
- Modified source text
- Changed metadata/attributes
- Only translates what's necessary

### Batch Processing

Process entire directory structures:

```
lib/l10n/
├── common/
│   ├── app_en.arb
│   └── errors_en.arb
├── features/
│   ├── auth_en.arb
│   └── profile_en.arb
└── app_en.arb
```

All files will be processed recursively and organized in the output structure.

## 🔄 Integration with Flutter

### 1. Add to your Flutter project

```yaml
# pubspec.yaml
dev_dependencies:
  smart_arb_translator: ^1.0.1

flutter:
  generate: true
```

### 2. Translate and generate (Auto-configures for you!)

```bash
# Complete workflow: Translate ARB files + Generate Dart code
# The tool will automatically configure your preferred localization method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de \
  --generate_dart \
  --dart_class_name AppLocalizations

# This will create either:
# - l10n.yaml (for gen-l10n method) OR
# - flutter_intl config in pubspec.yaml (for intl_utils method)
```

### 3. Manual configuration (Optional)

If you prefer manual setup, you can configure either method:

**Option A: gen-l10n (Flutter official)**
```yaml
# l10n.yaml (created automatically by smart_arb_translator)
arb-dir: lib/l10n
template-arb-file: intl_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated
```

**Option B: intl_utils (Third-party)**
```yaml
# pubspec.yaml (configured automatically by smart_arb_translator)
flutter_intl:
  enabled: true
  class_name: AppLocalizations
  main_locale: en
  arb_dir: lib/l10n
  output_dir: lib/generated
  use_deferred_loading: false
```

### 4. Use in your Flutter app

```dart
import 'package:flutter/material.dart';
import 'lib/generated/l10n.dart'; // Generated by smart_arb_translator

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
      ),
      body: Center(
        child: Text(AppLocalizations.of(context).welcomeMessage),
      ),
    );
  }
}
```

## 🛠️ Development

### Project Structure

```
lib/
├── smart_arb_translator.dart          # Main library export
└── src/
    ├── argument_parser.dart           # CLI argument handling
    ├── arb_processor.dart            # ARB file processing
    ├── console_utils.dart            # Console utilities
    ├── directory_processor.dart      # Directory operations
    ├── file_operations.dart          # File utilities
    ├── single_file_processor.dart    # Single file processing
    ├── translation_service.dart      # Google Translate API
    ├── utils.dart                    # General utilities
    ├── icu_parser.dart              # ICU message parsing
    └── models/
        ├── arb_attributes.dart       # ARB metadata model
        ├── arb_document.dart         # ARB document model
        └── arb_resource.dart         # ARB resource model
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### Running Tests

```bash
dart test
```

## 📝 Language Codes

Supported language codes include:

| Code | Language | Code | Language |
|------|----------|------|----------|
| `es` | Spanish | `fr` | French |
| `de` | German | `it` | Italian |
| `pt` | Portuguese | `ru` | Russian |
| `ja` | Japanese | `ko` | Korean |
| `zh` | Chinese | `ar` | Arabic |

[Full list of supported languages](https://cloud.google.com/translate/docs/languages)

## 🐛 Troubleshooting

### Common Issues

1. **API Key Error**: Ensure your API key file exists and contains a valid key
2. **Permission Error**: Check file permissions for source and output directories
3. **Invalid ARB**: Validate your ARB files are properly formatted JSON
4. **Network Error**: Check internet connection and API quotas

### Debug Mode

Add `--verbose` flag for detailed logging:

```bash
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es --verbose
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project was originally inspired by and forked from [justkawal/arb_translator](https://github.com/justkawal/arb_translator). We're grateful for the foundation provided by the original work.

### What's New in Smart ARB Translator:
- 🧠 **Smart Change Detection**: Only translates modified content
- 🏗️ **Modular Architecture**: Complete refactor for maintainability  
- ⚡ **Enhanced Performance**: Optimized for large projects
- 📚 **Professional Documentation**: Comprehensive guides and examples
- 🔧 **Better Developer Experience**: Improved CLI and programmatic API

### Original Project Credits:
- **Original Author**: [Kawal Jeet](https://github.com/justkawal)
- **Original Repository**: [arb_translator](https://github.com/justkawal/arb_translator)
- **License**: MIT (maintained in this project)

Built with ❤️ for the Flutter community

## 📞 Support

- 🐛 [Report Issues](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 💡 [Feature Requests](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 📖 [Documentation](https://github.com/FredrikBorgstrom/smart_arb_translator#readme)

---

Made with ❤️ for the Flutter community

[![Pub Version](https://img.shields.io/pub/v/smart_arb_translator.svg)](https://pub.dev/packages/smart_arb_translator)
[![Pub Points](https://img.shields.io/pub/points/smart_arb_translator)](https://pub.dev/packages/smart_arb_translator/score)
[![Popularity](https://img.shields.io/pub/popularity/smart_arb_translator)](https://pub.dev/packages/smart_arb_translator/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/FredrikBorgstrom/smart_arb_translator?style=social)](https://github.com/FredrikBorgstrom/smart_arb_translator)
[![GitHub Issues](https://img.shields.io/github/issues/FredrikBorgstrom/smart_arb_translator)](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/FredrikBorgstrom/smart_arb_translator)](https://github.com/FredrikBorgstrom/smart_arb_translator/commits/main)