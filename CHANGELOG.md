# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-12-19

### Added
- ⚙️ **pubspec.yaml Configuration Support**: Configure all parameters directly in your `pubspec.yaml` file under the `smart_arb_translator` section
- 📋 **Complete Parameter Coverage**: All CLI arguments can now be set in pubspec.yaml configuration
- 🔄 **Configuration Precedence System**: CLI arguments take precedence over pubspec.yaml settings, which take precedence over defaults
- 🎯 **Flexible Language Code Formats**: Support for both YAML list format (`[es, fr, de]`) and comma-separated strings (`"es,fr,de"`)
- 🛡️ **Graceful Error Handling**: Robust handling of malformed YAML configurations
- 📚 **Comprehensive Documentation**: Updated README with configuration examples and best practices
- 🧪 **Full Test Coverage**: 13 new tests covering pubspec configuration and argument parser integration

### Enhanced
- 🔧 **Developer Experience**: Simple `smart_arb_translator` command when using pubspec.yaml configuration
- 👥 **Team Consistency**: Version-controlled configuration ensures all team members use the same settings
- 🚀 **CI/CD Integration**: Simplified build scripts with configuration stored in pubspec.yaml
- 🔄 **Backward Compatibility**: Existing CLI usage continues to work unchanged
- 📖 **IDE Support**: Better tooling integration with YAML configuration

### Technical Details
- **New Classes**:
  - `PubspecConfig`: Handles reading and parsing pubspec.yaml configuration
  - `_MergedArgResults`: Custom ArgResults implementation for merging CLI and pubspec settings
- **Configuration Options**: All 13 CLI parameters now supported in pubspec.yaml:
  - `source_dir` / `source_arb`: Source configuration
  - `api_key`: Google Translate API key path
  - `language_codes`: Target languages (list or comma-separated)
  - `cache_directory` / `l10n_directory`: Directory configuration
  - `output_file_name`: Output file naming
  - `generate_dart` / `dart_class_name` / `dart_output_dir` / `dart_main_locale`: Dart generation
  - `l10n_method`: Localization method selection
  - `auto_approve`: Automation settings

### Usage Examples
```yaml
# pubspec.yaml
smart_arb_translator:
  source_dir: lib/l10n
  api_key: secrets/google_translate_api_key.txt
  language_codes: [es, fr, de, ja]
  generate_dart: true
  dart_class_name: AppLocalizations
```

```bash
# Simple command - all configuration from pubspec.yaml
smart_arb_translator

# Override specific parameters if needed
smart_arb_translator --language_codes it,pt --generate_dart false
```

### Benefits
- ✅ **Version Control Friendly**: Configuration committed with your code
- ✅ **Team Consistency**: Everyone uses the same settings
- ✅ **No Command Memorization**: Simple command execution
- ✅ **IDE Integration**: Better tooling support
- ✅ **Cleaner CI/CD**: Simplified build scripts

## [1.0.1] - 2024-05-26

### Added
- 🎯 **Dual Localization Method Support**: Choose between Flutter's built-in `gen-l10n` or `intl_utils` package
- 🤖 **Intelligent Auto-Detection**: Automatically detects existing localization setup and chooses the appropriate method
- 📝 **Auto-Configuration**: Automatically creates `l10n.yaml` or configures `pubspec.yaml` based on chosen method
- 🔧 **Method Selection**: New `--l10n_method` parameter to explicitly choose between `gen-l10n` and `intl_utils`
- 💾 **Preference Persistence**: Saves user's localization method choice in `pubspec.yaml` for future runs
- ✅ **Auto-Approve Option**: New `--auto_approve` flag to automatically approve configuration changes

### Enhanced
- 🧠 **Smart Method Detection**: Automatically detects:
  - Existing `l10n.yaml` file → Uses `gen-l10n`
  - Existing `intl_utils` dependency or `flutter_intl` config → Uses `intl_utils`
  - Saved preference in `pubspec.yaml` → Uses saved method
  - No setup found → Prompts user to choose (or defaults to `intl_utils` with `--auto_approve`)
- 🔄 **Flutter gen-l10n Integration**: Full support for Flutter's official localization solution
- 📋 **Interactive Setup**: User-friendly prompts when no existing setup is detected
- 🛡️ **Safe Configuration**: Asks for permission before modifying project files (unless auto-approved)

### Technical Details
- **New Command Options**:
  - `--l10n_method`: Choose between `gen-l10n` or `intl_utils`
  - `--auto_approve`: Automatically approve configuration changes
- **Auto-Configuration Features**:
  - Creates `l10n.yaml` with proper paths and class names for `gen-l10n`
  - Adds `intl_utils` dependency and `flutter_intl` config for `intl_utils`
  - Preserves existing file formatting and comments
- **Intelligent Detection Logic**: Comprehensive project analysis to determine the best localization method

### Usage Examples
```bash
# Auto-detect and configure (interactive)
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr --generate_dart

# Force specific method
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr --generate_dart --l10n_method gen-l10n

# Auto-approve configuration changes
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr --generate_dart --auto_approve
```

## [1.0.0] - 2024-01-01

### Added
- 🎉 **Initial release of Smart ARB Translator**
- ✨ **Smart Change Detection**: Only translates modified or new content
- 🏗️ **Modular Architecture**: Refactored into clean, maintainable modules
- 📁 **Batch Processing**: Recursive directory translation support
- 🔄 **Automatic Merging**: Seamless l10n directory integration
- 🎯 **Manual Translation Override**: Support for `@x-translations` metadata
- 🛠️ **Flexible Output**: Customizable file naming and directory structure
- 🚨 **Robust Error Handling**: Detailed feedback and error messages
- 📚 **Comprehensive Documentation**: Complete README with examples
- 🧪 **Programmatic API**: Use as a library in your Dart projects

### Changed
- 🔄 **Package Name**: Renamed from `arb_translator` to `smart_arb_translator`
- 🏗️ **Architecture**: Complete refactor into modular components:
  - `TranslationService`: Google Translate API integration
  - `ArbProcessor`: ARB file processing and action management
  - `FileOperations`: File and directory utilities
  - `DirectoryProcessor`: Batch directory processing
  - `SingleFileProcessor`: Individual file processing with change detection
  - `ArbTranslatorArgumentParser`: Command-line argument handling
  - `ConsoleUtils`: Console output utilities
- 🎨 **CLI Interface**: Improved command-line experience
- 📦 **Dependencies**: Updated to latest package versions

### Enhanced
- 🧠 **Intelligence**: Smart detection of changes to minimize API calls
- ⚡ **Performance**: Optimized processing for large projects
- 🔧 **Maintainability**: Clean separation of concerns
- 📖 **Documentation**: Comprehensive guides and examples
- 🎯 **User Experience**: Better error messages and feedback

### Technical Details
- **Minimum Dart SDK**: 3.0.1
- **Dependencies**: Updated all dependencies to latest versions
- **Architecture**: Modular design with clear separation of concerns
- **Testing**: Foundation for comprehensive test coverage
- **Documentation**: Complete API documentation and usage examples

### Migration from arb_translator
If you're migrating from the original `arb_translator` package:

1. **Update pubspec.yaml**:
   ```yaml
   dev_dependencies:
     smart_arb_translator: ^1.0.0  # instead of arb_translator
   ```

2. **Update command usage**:
   ```bash
   smart_arb_translator  # instead of pub run arb_translator:translate
   ```

3. **Argument changes**:
   - `--append-lang-code` / `--no-append-lang-code` (instead of `--append_lang_code`)
   - All other arguments remain the same

4. **New features available**:
   - Smart change detection (automatic)
   - Improved error handling
   - Better performance
   - Programmatic API access

### Acknowledgments
- Originally forked from [justkawal/arb_translator](https://github.com/justkawal/arb_translator)
- Enhanced with modern architecture and smart features
- Built for the Flutter community

---

**Note**: This is the first release of Smart ARB Translator as a standalone package. 
Future releases will follow semantic versioning with detailed changelogs.
