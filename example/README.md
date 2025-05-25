# Smart ARB Translator Examples

This directory contains examples of how to use Smart ARB Translator in different scenarios.

## 📁 Directory Structure

```
example/
├── README.md                    # This file
├── basic_usage.dart            # Basic programmatic usage
├── advanced_usage.dart         # Advanced features example
├── sample_arb_files/           # Sample ARB files for testing
│   ├── app_en.arb
│   ├── common_en.arb
│   └── features/
│       ├── auth_en.arb
│       └── profile_en.arb
└── scripts/
    ├── translate_single.sh     # Single file translation script
    ├── translate_directory.sh  # Directory translation script
    └── flutter_workflow.sh     # Complete Flutter workflow
```

## 🚀 Quick Start Examples

### 1. Command Line Usage

#### Translate a Single File
```bash
smart_arb_translator \
  --source_arb example/sample_arb_files/app_en.arb \
  --api_key path/to/your/api_key.txt \
  --language_codes es,fr,de \
  --output_file_name app
```

#### Translate a Directory
```bash
smart_arb_translator \
  --source_dir example/sample_arb_files \
  --api_key path/to/your/api_key.txt \
  --language_codes es,fr,de,it \
  --cache_directory example/output/cache \
  --l10n_directory example/output/l10n
```

### 2. Programmatic Usage

See `basic_usage.dart` and `advanced_usage.dart` for detailed examples.

### 3. Flutter Integration

See `scripts/flutter_workflow.sh` for a complete Flutter internationalization workflow.

## 📋 Sample ARB Files

The `sample_arb_files/` directory contains realistic ARB files that you can use to test the translation functionality:

- `app_en.arb`: Main application strings
- `common_en.arb`: Common UI elements
- `features/auth_en.arb`: Authentication-related strings
- `features/profile_en.arb`: User profile strings

## 🔧 Setup Instructions

1. **Get a Google Translate API Key**:
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Enable the Cloud Translation API
   - Create an API key
   - Save it to a text file

2. **Install Smart ARB Translator**:
   ```bash
   dart pub global activate smart_arb_translator
   ```

3. **Run the Examples**:
   ```bash
   # Navigate to the example directory
   cd example
   
   # Run basic programmatic example
   dart run basic_usage.dart
   
   # Run advanced example
   dart run advanced_usage.dart
   
   # Run shell scripts (make them executable first)
   chmod +x scripts/*.sh
   ./scripts/translate_single.sh
   ```

## 📚 Learning Path

1. **Start with**: `scripts/translate_single.sh` - Simple single file translation
2. **Progress to**: `scripts/translate_directory.sh` - Batch processing
3. **Explore**: `basic_usage.dart` - Programmatic API
4. **Master**: `advanced_usage.dart` - Advanced features
5. **Integrate**: `scripts/flutter_workflow.sh` - Complete Flutter workflow

## 🎯 Common Use Cases

### Use Case 1: Flutter App Internationalization
```bash
# 1. Translate your ARB files
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr,de

# 2. Generate Flutter localizations
flutter gen-l10n

# 3. Use in your Flutter app
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### Use Case 2: Incremental Updates
```bash
# Only translates new or changed keys (saves API costs)
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr
```

### Use Case 3: Custom Translation Overrides
Add to your ARB file:
```json
{
  "greeting": "Hello",
  "@greeting": {
    "description": "A greeting message",
    "@x-translations": {
      "es": "¡Hola!",
      "fr": "Salut!"
    }
  }
}
```

## 🐛 Troubleshooting

If you encounter issues:

1. **Check API Key**: Ensure your API key file exists and contains a valid key
2. **Verify Permissions**: Make sure you have read/write access to source and output directories
3. **Validate ARB Files**: Ensure your ARB files are valid JSON
4. **Check Network**: Verify internet connection and Google Cloud API quotas

## 📞 Getting Help

- 📖 [Main Documentation](../README.md)
- 🐛 [Report Issues](https://github.com/YOUR_USERNAME/smart_arb_translator/issues)
- 💡 [Feature Requests](https://github.com/YOUR_USERNAME/smart_arb_translator/issues)

---

Happy translating! 🌍✨ 