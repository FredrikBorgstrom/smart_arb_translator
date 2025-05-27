# Smart ARB Translator Examples

This directory contains comprehensive examples demonstrating Smart ARB Translator's complete workflow, including the new **Dart code generation** feature.

## 🆕 **NEW: Complete Flutter Integration**

Smart ARB Translator now provides end-to-end Flutter internationalization:
**Translation → ARB Files → Dart Code → Ready-to-use Flutter App**

## 📁 Directory Structure

```
example/
├── README.md                    # This file
├── flutter_app/                # Complete Flutter example app
│   ├── lib/
│   │   ├── main.dart           # Flutter app using generated localizations
│   │   ├── l10n/               # Source ARB files
│   │   │   └── app_en.arb
│   │   └── generated/          # Generated Dart code (auto-created)
│   ├── pubspec.yaml
│   └── api_key.txt             # Your Google API key
├── sample_arb_files/           # Sample ARB files for testing
│   ├── app_en.arb
│   ├── common_en.arb
│   └── features/
│       ├── auth_en.arb
│       └── profile_en.arb
├── scripts/
│   ├── complete_workflow.sh    # NEW: Translation + Dart generation
│   ├── translate_only.sh       # Translation only
│   └── test_with_api.sh        # Test with provided API key
└── programmatic/
    ├── basic_usage.dart
    └── advanced_usage.dart
```

## 🚀 **Quick Start: Complete Workflow**

### **Option 1: One Command Solution (NEW!)**
```bash
# Complete workflow: Translate + Generate Dart code
smart_arb_translator \
  --source_dir example/flutter_app/lib/l10n \
  --api_key example/flutter_app/api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --dart_class_name AppLocalizations \
  --dart_output_dir example/flutter_app/lib/generated
```

### **Option 2: Step by Step**
```bash
# Step 1: Translate ARB files
smart_arb_translator \
  --source_dir example/flutter_app/lib/l10n \
  --api_key example/flutter_app/api_key.txt \
  --language_codes es,fr,de,ja

# Step 2: Generate Dart code
smart_arb_translator \
  --source_dir example/flutter_app/lib/l10n \
  --api_key example/flutter_app/api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart
```

## 🎯 **Live Example: Flutter App**

### **1. Setup the Example App**
```bash
cd example/flutter_app

# Add your API key
echo "ENTER_API_KEY_HERE" > api_key.txt

# Install dependencies
flutter pub get
```

### **2. Run Complete Translation + Code Generation**
```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --dart_class_name AppLocalizations
```

### **3. Run the Flutter App**
```bash
flutter run
```

The app will now support multiple languages with type-safe, auto-generated localization code!

## 📋 **Sample ARB Files**

### **Main App Strings** (`app_en.arb`)
```json
{
  "@@locale": "en",
  "@@last_modified": "2024-01-01T00:00:00.000Z",
  "appTitle": "Smart ARB Translator Demo",
  "@appTitle": {
    "description": "The title of the application"
  },
  "welcomeMessage": "Welcome to Smart ARB Translator!",
  "@welcomeMessage": {
    "description": "Welcome message shown to users"
  },
  "itemCount": "{count,plural, =0{No items} =1{One item} other{{count} items}}",
  "@itemCount": {
    "description": "Shows the number of items",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "greetUser": "Hello, {name}!",
  "@greetUser": {
    "description": "Greets the user by name",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
```

## 🔧 **Advanced Features**

### **Manual Translation Overrides**
```json
{
  "specialGreeting": "Hello there!",
  "@specialGreeting": {
    "description": "A special greeting",
    "@x-translations": {
      "es": "¡Hola amigo!",
      "fr": "Salut mon ami!",
      "de": "Hallo mein Freund!"
    }
  }
}
```

### **Smart Change Detection**
```bash
# Only translates new or modified keys (saves API costs!)
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart
```

### **Custom Configuration**
```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,ja,ko,zh \
  --generate_dart \
  --dart_class_name MyAppLocalizations \
  --dart_output_dir lib/i18n \
  --dart_main_locale en \
  --cache_directory .translation_cache \
  --l10n_directory lib/l10n_merged
```

## 📱 **Flutter Integration Example**

### **Generated Usage** (After running with `--generate_dart`)
```dart
import 'package:flutter/material.dart';
import 'lib/generated/l10n.dart'; // Auto-generated!

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart ARB Translator Demo',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle), // Type-safe!
      ),
      body: Column(
        children: [
          Text(l10n.welcomeMessage),
          Text(l10n.greetUser('John')), // With parameters!
          Text(l10n.itemCount(5)), // Plural support!
        ],
      ),
    );
  }
}
```

## 🧪 **Testing Scripts**

### **Test with Provided API Key**
```bash
# Use the provided test API key
./scripts/test_with_api.sh
```

### **Complete Workflow Test**
```bash
# Test the entire translation + code generation workflow
./scripts/complete_workflow.sh
```

## 📊 **Performance Benefits**

| Feature | Before | After (Smart ARB Translator) |
|---------|--------|-------------------------------|
| **Setup Time** | 30+ minutes | 2 minutes |
| **Translation Cost** | Full retranslation | Only changed content |
| **Code Generation** | Manual setup | Automatic |
| **Type Safety** | Runtime errors | Compile-time safety |
| **Maintenance** | Multiple tools | Single command |

## 🌍 **Supported Languages**

Test with multiple languages:
```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,it,pt,ru,ja,ko,zh,ar,hi,th \
  --generate_dart
```

## 🐛 **Troubleshooting**

### **Common Issues & Solutions**

1. **API Key Issues**
   ```bash
   # Verify API key
   echo "ENTER_API_KEY_HERE" > api_key.txt
   ```

2. **Permission Errors**
   ```bash
   # Fix permissions
   chmod -R 755 lib/
   ```

3. **Dart Generation Fails**
   ```bash
   # Ensure pubspec.yaml exists
   flutter create . --project-name my_app
   ```

4. **Missing Dependencies**
   ```bash
   # Install required dependencies
   dart pub add intl
   flutter pub get
   ```

## 📚 **Learning Path**

1. **🟢 Beginner**: Run `./scripts/test_with_api.sh`
2. **🟡 Intermediate**: Modify `example/flutter_app/lib/l10n/app_en.arb`
3. **🟠 Advanced**: Create custom ARB structure
4. **🔴 Expert**: Integrate into existing Flutter project

## 🎉 **What's New in v1.0.0**

- ✅ **Dart Code Generation**: Complete intl_utils integration
- ✅ **One Command Solution**: Translation + code generation
- ✅ **Type Safety**: Compile-time localization safety
- ✅ **Smart Caching**: Only translate what changed
- ✅ **Flutter Ready**: Drop-in Flutter integration

## 📞 **Getting Help**

- 📖 [Main Documentation](../README.md)
- 🐛 [Report Issues](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 💡 [Feature Requests](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 🎯 [Live Examples](./flutter_app/)

---

**Ready to revolutionize your Flutter i18n workflow?** 🚀✨ 

## pubspec.yaml Configuration Example

The `pubspec_config_example.yaml` file shows how to configure all Smart ARB Translator parameters directly in your `pubspec.yaml` file.

### Benefits of pubspec.yaml Configuration:

- ✅ **Version Control Friendly**: Configuration is committed with your code
- ✅ **Team Consistency**: Everyone uses the same settings
- ✅ **No Command Memorization**: Simple `smart_arb_translator` command
- ✅ **IDE Integration**: Better tooling support
- ✅ **Cleaner CI/CD**: Simplified build scripts

### Usage:

1. Copy the configuration from `pubspec_config_example.yaml` to your project's `pubspec.yaml`
2. Modify the values to match your project structure
3. Run the simple command:

```bash
smart_arb_translator
```

### Configuration Options:

All CLI parameters can be configured in the `smart_arb_translator` section:

```yaml
smart_arb_translator:
  # Source configuration (choose one)
  source_dir: lib/l10n                    # Directory containing ARB files
  source_arb: lib/l10n/app_en.arb         # Single ARB file (alternative)
  
  # Required: Google Translate API key
  api_key: secrets/google_translate_api_key.txt
  
  # Target languages (multiple formats supported)
  language_codes: [es, fr, de, it, pt, ja]  # YAML list format
  language_codes: "es,fr,de,it,pt,ja"      # Comma-separated string format
  
  # Output configuration
  cache_directory: lib/l10n_cache          # Translation cache directory
  l10n_directory: lib/l10n                 # Output directory for merged files
  output_file_name: app                    # Prefix for output files
  
  # Dart code generation
  generate_dart: true                      # Generate Dart localization code
  dart_class_name: AppLocalizations        # Name for generated class
  dart_output_dir: lib/generated           # Directory for generated Dart files
  dart_main_locale: en                     # Main locale for code generation
  
  # Localization method (auto-detected if not specified)
  l10n_method: gen-l10n                    # Options: "gen-l10n" or "intl_utils"
  
  # Automation
  auto_approve: false                      # Auto-approve pubspec.yaml modifications
```

### Configuration Precedence:

When both pubspec.yaml configuration and CLI arguments are provided:

1. **CLI Arguments** (Highest priority)
2. **pubspec.yaml Configuration**
3. **Default Values** (Lowest priority)

### Example Override:

```yaml
# pubspec.yaml
smart_arb_translator:
  language_codes: [es, fr, de]
  generate_dart: true
```

```bash
# This command will use:
# - language_codes: [it, pt] (from CLI - overrides pubspec.yaml)
# - generate_dart: true (from pubspec.yaml)
smart_arb_translator --language_codes it,pt
``` 