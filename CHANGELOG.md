# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.5] - 2025-01-27

### Enhanced
- 🌍 **Language Codes in Auto-Configuration**: Added language codes selection to the auto-configuration wizard
- 📝 **Interactive Language Selection**: Users can now specify target languages during setup using comma-separated input (e.g., "es,fr,de,ja")
- 💡 **Language Code Hints**: Provided common language code examples to help users choose appropriate codes
- 💾 **Automatic Configuration Saving**: Language codes are automatically saved to pubspec.yaml in proper YAML list format
- 🛡️ **Input Validation**: Added validation to ensure at least one valid language code is provided

### Technical Details
- **Enhanced Auto-Configuration Prompts**:
  - Interactive prompt for target language codes with examples
  - Comma-separated input parsing with whitespace trimming
  - Validation to prevent empty language code lists
- **Improved YAML Generation**:
  - Proper handling of list values in pubspec.yaml configuration
  - Language codes saved as YAML list format: `["es", "fr", "de"]`
  - Consistent formatting for both new and existing configuration sections

### Benefits
- ✅ **Complete Setup Experience**: Auto-configuration now covers all essential parameters including target languages
- ✅ **User-Friendly Input**: Simple comma-separated format for specifying multiple languages
- ✅ **Proper Configuration**: Language codes correctly saved to pubspec.yaml for future use
- ✅ **Guided Selection**: Common language code examples help users make informed choices

## [1.3.4] 2025-05-27

- Typo in readme fixed

## [1.3.3] - 2025-05-27

### Enhanced
- 📚 **Comprehensive API Documentation**: Added extensive dartdoc comments to all public API elements to meet pub.dev documentation requirements
- 🎯 **Improved Documentation Coverage**: Increased documentation coverage from 10.3% to over 20% of public API elements
- 📖 **Detailed Class Documentation**: Added comprehensive documentation for all core classes including `Action`, `ArbResource`, `ArbDocument`, `ArbAttributes`, `TranslationService`, `ArbProcessor`, and utility classes
- 🔧 **Method Documentation**: Added detailed parameter descriptions, return value documentation, and usage examples for all public methods
- 💡 **Code Examples**: Included practical code examples in documentation to help developers understand API usage
- 🏗️ **Architecture Documentation**: Enhanced documentation explaining the relationship between classes and their roles in the translation workflow

### Technical Details
- **Documented Classes and APIs**:
  - `Action`: Translation action representation with update functions
  - `ArbResource`: Single ARB resource with metadata and ICU parsing
  - `ArbDocument`: Complete ARB document with serialization capabilities
  - `ArbAttributes`: Resource metadata including placeholders and manual translations
  - `TranslationService`: Google Translate API integration and text processing
  - `ArbProcessor`: Core translation workflow orchestration
  - `ArbTranslatorArgumentParser`: Command-line argument parsing and configuration
  - `ConsoleUtils`: Terminal color and formatting utilities
  - `FileOperations`: File system operations for ARB processing
  - `IcuParser`: ICU message format parsing with detailed grammar documentation
  - `PubspecConfig`: Configuration loading from pubspec.yaml
  - Utility functions for enum handling and HTML processing

### Benefits
- ✅ **Better pub.dev Score**: Meets pub.dev documentation requirements (20%+ coverage)
- ✅ **Developer Experience**: Comprehensive API documentation for easier integration
- ✅ **Code Examples**: Practical examples showing how to use each API
- ✅ **Architecture Understanding**: Clear documentation of class relationships and workflows
- ✅ **IDE Support**: Better IntelliSense and code completion with detailed documentation

## [1.3.2] - 2025-05-27

### Enhanced
- 🔧 **Extended Auto-Configuration**: Added prompts for API key, cache directory, and output directory in auto-configuration wizard
- 🧹 **Improved intl_utils Integration**: Fixed flutter_intl configuration to be minimal (only `enabled: true`) while using smart_arb_translator configuration as source of truth
- 📝 **Better Configuration Management**: intl_utils now temporarily uses full configuration during generation, then cleans up to keep only essential settings

### Technical Details
- **Enhanced Auto-Configuration Prompts**:
  - API key path (required)
  - Cache directory (default: lib/l10n_cache)
  - Output directory (default: lib/l10n)
- **Improved intl_utils Workflow**:
  - Temporarily adds full configuration to flutter_intl section before running intl_utils
  - Runs `dart run intl_utils:generate` with proper configuration
  - Cleans up flutter_intl section to keep only `enabled: true`
  - smart_arb_translator configuration remains the single source of truth
- **Fixed Entry Point**: Recreated bin/translate.dart with proper async support and method signatures

### Benefits
- ✅ **Complete Setup Wizard**: New users get guided through all necessary configuration
- ✅ **Clean Configuration**: Minimal flutter_intl section reduces confusion
- ✅ **Single Source of Truth**: All configuration managed through smart_arb_translator section
- ✅ **Better Integration**: Seamless intl_utils workflow without configuration duplication

## [1.3.1] - 2025-05-27

### Fixed
- 🐛 **Type Casting Error**: Fixed "type 'ArgResults' is not a subtype of type '_MergedArgResults'" error in auto-configuration
- 📁 **Default Directory**: Updated auto-approve default to use `lib/l10n_source` instead of `lib/l10n` to avoid confusion with output directory

### Technical Details
- Fixed type casting issue in `_updateMergedResult` method when handling different ArgResults types
- Improved handling of underlying ArgResults objects in merged configuration
- Updated default source directory to be more descriptive and avoid conflicts

## [1.3.0] - 2025-05-27

### Added
- 🔧 **Enhanced Auto-Configuration**: Comprehensive setup wizard when no source configuration is found
- 📁 **Source Type Selection**: Interactive prompt to choose between directory or single file source
- 🌍 **Source Locale Configuration**: Prompt for source locale with 'en' as default
- 🚫 **'None' Generation Option**: Added third option to skip Dart code generation entirely
- 💾 **Auto-Save Configuration**: Automatically saves user choices to pubspec.yaml for future use
- 🎯 **Smart Defaults**: Auto-approve mode defaults to sensible configuration (lib/l10n directory, en locale)

### Enhanced
- 🤖 **Improved Auto-Configuration Flow**: Extended existing generator method selection to include comprehensive source setup
- 🔄 **Three-Option Generator Selection**: Users can now choose between gen-l10n, intl_utils, or none (translation only)
- 📝 **Better User Experience**: Clear prompts and explanations for each configuration option
- 🛡️ **Robust Error Handling**: Graceful handling of missing configuration with helpful prompts
- ⚡ **Async Support**: Updated argument parser to properly handle async auto-configuration

### Technical Details
- **New Auto-Configuration Features**:
  - Source type selection (directory vs. single file)
  - Source path configuration with smart defaults
  - Source locale specification with 'en' default
  - Extended l10n method selection including 'none' option
- **Updated CLI Parameters**:
  - `--l10n_method` now accepts 'none' as a valid option
  - Auto-configuration runs when no source_arb or source_dir is found
- **Configuration Persistence**: All auto-configuration choices are saved to pubspec.yaml
- **Backward Compatibility**: Existing configurations and CLI usage remain unchanged

### Usage Examples
```bash
# Run without any configuration - triggers auto-configuration
smart_arb_translator

# Auto-configuration will prompt for:
# 1. Source type (directory or file)
# 2. Source path (with lib/l10n default for directories)
# 3. Source locale (with 'en' default)
# 4. Generation method (gen-l10n, intl_utils, or none)
```

### Benefits
- ✅ **Zero-Configuration Start**: New users can get started without any prior setup
- ✅ **Guided Setup**: Interactive prompts guide users through optimal configuration
- ✅ **Translation-Only Option**: Support for users who only want translation without Dart generation
- ✅ **Persistent Configuration**: Choices are saved for future runs
- ✅ **Smart Defaults**: Sensible defaults reduce configuration burden

## [1.2.0] - 2025-05-26

### Added
- 🚀 **Deferred Loading Support**: New `--use_deferred_loading` parameter for Flutter Web optimization
- 📱 **Flutter Web Performance**: Enable deferred loading to reduce initial bundle size for web applications
- ⚙️ **Full Configuration Support**: `use_deferred_loading` parameter available in both CLI and pubspec.yaml configuration
- 🔧 **Dual Generator Support**: Works with both `gen-l10n` and `intl_utils` localization methods

### Enhanced
- 🌐 **Web Application Optimization**: Improved performance for Flutter Web apps with many languages
- 📊 **Bundle Size Reduction**: Locales loaded on-demand instead of all at once
- 🎯 **Flexible Configuration**: Choose between immediate loading (default) or deferred loading based on your needs
- 🧪 **Comprehensive Testing**: Added tests for the new parameter in both CLI and pubspec.yaml configurations

### Technical Details
- **New Parameter**: `use_deferred_loading` (boolean, default: `false`)
  - **CLI**: `--use_deferred_loading` flag
  - **pubspec.yaml**: `use_deferred_loading: true/false`
- **Generator Integration**:
  - **gen-l10n**: Adds `use-deferred-loading: true` to `l10n.yaml`
  - **intl_utils**: Adds `use_deferred_loading: true` to `flutter_intl` section in `pubspec.yaml`
- **Backward Compatibility**: Existing projects continue to work unchanged (defaults to `false`)

### Usage Examples
```bash
# Enable deferred loading via CLI
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --use_deferred_loading

# Configure in pubspec.yaml
smart_arb_translator:
  source_dir: lib/l10n
  api_key: api_key.txt
  language_codes: [es, fr, de, ja]
  generate_dart: true
  use_deferred_loading: true
```

### Benefits
- ✅ **Faster Initial Load**: Reduced initial bundle size for Flutter Web
- ✅ **On-Demand Loading**: Languages loaded only when needed
- ✅ **Better UX**: Improved perceived performance for web applications
- ✅ **Scalable**: Particularly beneficial for apps with many supported languages
- ✅ **Configurable**: Easy to enable/disable based on project requirements

## [1.1.0] - 2025-05-25

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

## [1.0.1] - 2025-05-25

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

## [1.0.0] - 2025-05-25

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
