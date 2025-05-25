# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
