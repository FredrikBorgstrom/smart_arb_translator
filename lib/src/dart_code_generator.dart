import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Information about what needs to be set up in the project
class _ProjectSetupInfo {
  final bool needsIntlUtils;
  final bool needsFlutterIntl;
  final String intlUtilsVersion;
  final Map<String, dynamic> flutterIntlConfig;

  _ProjectSetupInfo({
    required this.needsIntlUtils,
    required this.needsFlutterIntl,
    required this.intlUtilsVersion,
    required this.flutterIntlConfig,
  });

  bool get needsChanges => needsIntlUtils || needsFlutterIntl;
}

/// Service for generating Dart localization code from ARB files.
///
/// This class provides integration with Flutter's localization tools,
/// supporting both the built-in `gen-l10n` tool and the third-party
/// `intl_utils` package. It handles project setup, configuration management,
/// and code generation workflows.
///
/// The generator supports:
/// - Automatic detection of existing localization setups
/// - Interactive method selection for new projects
/// - Configuration persistence in pubspec.yaml
/// - Both immediate and deferred loading patterns
/// - Clean integration with Flutter development workflows
///
/// Example usage:
/// ```dart
/// await DartCodeGenerator.generateDartCode(
///   arbDirectory: 'lib/l10n',
///   outputDirectory: 'lib/generated',
///   className: 'AppLocalizations',
///   mainLocale: 'en',
///   languageCodes: ['es', 'fr', 'de'],
///   l10nMethod: 'gen-l10n',
/// );
/// ```
class DartCodeGenerator {
  /// Generates Dart localization code from ARB files.
  ///
  /// This method orchestrates the complete Dart code generation process,
  /// including method selection, project setup, and code generation using
  /// either Flutter's built-in `gen-l10n` tool or the `intl_utils` package.
  ///
  /// The method automatically:
  /// 1. Detects the Flutter project structure
  /// 2. Determines the appropriate localization method
  /// 3. Sets up necessary dependencies and configuration
  /// 4. Generates the Dart localization code
  /// 5. Provides usage instructions
  ///
  /// Parameters:
  /// - [arbDirectory]: Directory containing the ARB files to process
  /// - [outputDirectory]: Directory where generated Dart files will be placed
  /// - [className]: Name for the generated localization class
  /// - [mainLocale]: Primary locale for the application (e.g., 'en')
  /// - [languageCodes]: List of target language codes for generation
  /// - [autoApprove]: Whether to automatically approve setup changes
  /// - [l10nMethod]: Localization method ('gen-l10n', 'intl_utils', or 'none')
  /// - [useDeferredLoading]: Whether to enable deferred loading for locales
  ///
  /// Returns a [Future<void>] that completes when code generation is finished.
  ///
  /// Throws [Exception] if code generation fails or project setup is invalid.
  ///
  /// Example:
  /// ```dart
  /// await DartCodeGenerator.generateDartCode(
  ///   arbDirectory: 'lib/l10n',
  ///   outputDirectory: 'lib/generated',
  ///   className: 'S',
  ///   mainLocale: 'en',
  ///   languageCodes: ['es', 'fr', 'de'],
  ///   autoApprove: false,
  ///   l10nMethod: 'intl_utils',
  ///   useDeferredLoading: true,
  /// );
  /// ```
  static Future<void> generateDartCode({
    required String arbDirectory,
    required String outputDirectory,
    required String className,
    required String mainLocale,
    required List<String> languageCodes,
    bool autoApprove = false,
    String? l10nMethod,
    bool useDeferredLoading = false,
  }) async {
    print('🔧 Generating Dart localization code...');

    try {
      // Find the Flutter project directory (where pubspec.yaml should be)
      final projectDir = _findFlutterProjectDirectory(arbDirectory);

      // Determine which localization method to use
      final selectedMethod = await _determineL10nMethod(projectDir, l10nMethod, autoApprove);

      if (selectedMethod == 'none') {
        print('🚫 Skipping Dart code generation (method: none)');
        print('✅ Translation completed without Dart code generation');
        return;
      } else if (selectedMethod == 'gen-l10n') {
        await _generateWithGenL10n(
          projectDirectory: projectDir,
          arbDirectory: arbDirectory,
          outputDirectory: outputDirectory,
          className: className,
          mainLocale: mainLocale,
          autoApprove: autoApprove,
          useDeferredLoading: useDeferredLoading,
        );
      } else {
        await _generateWithIntlUtils(
          projectDirectory: projectDir,
          arbDirectory: arbDirectory,
          outputDirectory: outputDirectory,
          className: className,
          mainLocale: mainLocale,
          autoApprove: autoApprove,
          useDeferredLoading: useDeferredLoading,
        );
      }

      print('✅ Dart localization code generated successfully!');
      print('📁 Generated files location: $outputDirectory');
      print('🎯 Generated class name: $className');

      _printUsageInstructions(className, outputDirectory, selectedMethod);
    } catch (e) {
      print('❌ Error generating Dart code: $e');
      rethrow;
    }
  }

  /// Determines which localization method to use based on project setup and user preference.
  ///
  /// This method analyzes the project structure and existing configuration
  /// to determine the most appropriate localization method. It checks for:
  /// - Explicit method specification via parameters
  /// - Saved preferences in pubspec.yaml
  /// - Existing l10n.yaml file (indicates gen-l10n)
  /// - Existing intl_utils setup in pubspec.yaml
  /// - User preferences via interactive prompts
  ///
  /// Parameters:
  /// - [projectDir]: Path to the Flutter project directory
  /// - [l10nMethod]: Explicitly specified method (optional)
  /// - [autoApprove]: Whether to use defaults without prompting
  ///
  /// Returns the selected localization method ('gen-l10n', 'intl_utils', or 'none').
  static Future<String> _determineL10nMethod(String projectDir, String? l10nMethod, bool autoApprove) async {
    // If method is explicitly specified via command line, use it
    if (l10nMethod != null) {
      print('🎯 Using specified localization method: $l10nMethod');
      return l10nMethod;
    }

    // Check if there's already a smart_arb_translator setting in pubspec.yaml
    final pubspecFile = File(path.join(projectDir, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      final pubspecContent = await pubspecFile.readAsString();
      final pubspecYaml = loadYaml(pubspecContent) as Map;

      // Check for existing smart_arb_translator configuration
      final smartArbConfig = pubspecYaml['smart_arb_translator'] as Map?;
      if (smartArbConfig != null && smartArbConfig['l10n_method'] != null) {
        final savedMethod = smartArbConfig['l10n_method'] as String;
        print('🎯 Using saved localization method from pubspec.yaml: $savedMethod');
        return savedMethod;
      }
    }

    // Check for l10n.yaml file (indicates gen-l10n preference)
    final l10nYamlFile = File(path.join(projectDir, 'l10n.yaml'));
    if (l10nYamlFile.existsSync()) {
      print('🎯 Found l10n.yaml file, using gen-l10n method');
      await _saveL10nMethodPreference(projectDir, 'gen-l10n');
      return 'gen-l10n';
    }

    // Check for existing intl_utils setup
    if (pubspecFile.existsSync()) {
      final pubspecContent = await pubspecFile.readAsString();
      final pubspecYaml = loadYaml(pubspecContent) as Map;

      final devDependencies = pubspecYaml['dev_dependencies'] as Map? ?? {};
      final flutterIntl = pubspecYaml['flutter_intl'] as Map?;

      if (devDependencies.containsKey('intl_utils') || flutterIntl != null) {
        print('🎯 Found existing intl_utils setup, using intl_utils method');
        await _saveL10nMethodPreference(projectDir, 'intl_utils');
        return 'intl_utils';
      }
    }

    // Neither method is set up, ask the user (unless auto-approve is enabled)
    if (autoApprove) {
      print('🎯 No existing setup found, defaulting to intl_utils method (auto-approve enabled)');
      await _saveL10nMethodPreference(projectDir, 'intl_utils');
      return 'intl_utils';
    }

    return await _promptUserForL10nMethod(projectDir);
  }

  /// Prompts the user to choose between gen-l10n, intl_utils, and none.
  ///
  /// This method presents an interactive menu allowing users to select
  /// their preferred localization method. It provides detailed information
  /// about each option to help users make an informed decision.
  ///
  /// Parameters:
  /// - [projectDir]: Path to the Flutter project directory for saving preferences
  ///
  /// Returns the user's selected method ('gen-l10n', 'intl_utils', or 'none').
  static Future<String> _promptUserForL10nMethod(String projectDir) async {
    print('\n🤔 No existing localization setup found.');
    print('Please choose a localization method:');
    print('');
    print('1. gen-l10n (Flutter built-in)');
    print('   - Uses l10n.yaml configuration file');
    print('   - Runs "flutter gen-l10n" command');
    print('   - Official Flutter solution');
    print('');
    print('2. intl_utils (Third-party package)');
    print('   - Uses flutter_intl section in pubspec.yaml');
    print('   - Runs "dart run intl_utils:generate" command');
    print('   - More configuration options');
    print('');
    print('3. none (No Dart code generation)');
    print('   - Skip Dart code generation');
    print('   - Only perform translation');
    print('');
    print('Enter your choice (1 for gen-l10n, 2 for intl_utils, 3 for none): ');

    while (true) {
      final input = stdin.readLineSync()?.trim() ?? '';

      if (input == '1') {
        await _saveL10nMethodPreference(projectDir, 'gen-l10n');
        return 'gen-l10n';
      } else if (input == '2') {
        await _saveL10nMethodPreference(projectDir, 'intl_utils');
        return 'intl_utils';
      } else if (input == '3') {
        await _saveL10nMethodPreference(projectDir, 'none');
        return 'none';
      } else {
        print('Invalid choice. Please enter 1, 2, or 3: ');
      }
    }
  }

  /// Saves the user's l10n method preference to pubspec.yaml
  static Future<void> _saveL10nMethodPreference(String projectDir, String method) async {
    final pubspecFile = File(path.join(projectDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return;

    final pubspecContent = await pubspecFile.readAsString();
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];

    bool foundSmartArbConfig = false;
    bool inSmartArbConfig = false;
    int smartArbIndent = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if we're entering smart_arb_translator section (but not as a dependency)
      if (trimmedLine == 'smart_arb_translator:' && !_isInDependencySection(lines, i)) {
        foundSmartArbConfig = true;
        inSmartArbConfig = true;
        smartArbIndent = line.indexOf('smart_arb_translator:');
        modifiedLines.add(line);
        modifiedLines.add('${' ' * (smartArbIndent + 2)}l10n_method: $method');
        continue;
      }

      // Check if we're leaving smart_arb_translator section
      if (inSmartArbConfig && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inSmartArbConfig = false;
      }

      // Skip existing l10n_method lines in smart_arb_translator section
      if (inSmartArbConfig && trimmedLine.startsWith('l10n_method:')) {
        continue;
      }

      modifiedLines.add(line);
    }

    // If smart_arb_translator section doesn't exist, add it
    if (!foundSmartArbConfig) {
      // Ensure there's a blank line before the new section
      if (modifiedLines.isNotEmpty && modifiedLines.last.trim().isNotEmpty) {
        modifiedLines.add('');
      }
      modifiedLines.addAll([
        'smart_arb_translator:',
        '  l10n_method: $method',
      ]);
    }

    await pubspecFile.writeAsString(modifiedLines.join('\n'));
    print('💾 Saved localization method preference: $method');
  }

  /// Helper method to check if a line is within a dependency section
  static bool _isInDependencySection(List<String> lines, int currentIndex) {
    // Look backwards to find if we're in a dependencies or dev_dependencies section
    for (int i = currentIndex - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line == 'dependencies:' || line == 'dev_dependencies:') {
        return true;
      }
      // If we hit another top-level section, we're not in dependencies
      if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t') && line.endsWith(':')) {
        return false;
      }
    }
    return false;
  }

  /// Generates Dart code using Flutter's built-in gen-l10n
  static Future<void> _generateWithGenL10n({
    required String projectDirectory,
    required String arbDirectory,
    required String outputDirectory,
    required String className,
    required String mainLocale,
    bool autoApprove = false,
    bool useDeferredLoading = false,
  }) async {
    print('🚀 Using Flutter gen-l10n for code generation...');

    // Check if l10n.yaml exists, create it if it doesn't
    final l10nYamlFile = File(path.join(projectDirectory, 'l10n.yaml'));
    if (!l10nYamlFile.existsSync()) {
      await _createL10nYamlConfig(
        projectDirectory: projectDirectory,
        arbDirectory: arbDirectory,
        outputDirectory: outputDirectory,
        className: className,
        mainLocale: mainLocale,
        autoApprove: autoApprove,
        useDeferredLoading: useDeferredLoading,
      );
    }

    // Run flutter gen-l10n
    final result = await Process.run(
      'flutter',
      ['gen-l10n'],
      workingDirectory: projectDirectory,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to run flutter gen-l10n: ${result.stderr}');
    }

    print('✅ Flutter gen-l10n generation completed');
  }

  /// Generates Dart code using intl_utils package
  static Future<void> _generateWithIntlUtils({
    required String projectDirectory,
    required String arbDirectory,
    required String outputDirectory,
    required String className,
    required String mainLocale,
    bool autoApprove = false,
    bool useDeferredLoading = false,
  }) async {
    print('🚀 Using intl_utils for code generation...');

    // Create pubspec.yaml configuration for intl_utils
    await _createIntlUtilsConfig(
      projectDirectory: projectDirectory,
      arbDirectory: arbDirectory,
      outputDirectory: outputDirectory,
      className: className,
      mainLocale: mainLocale,
      autoApprove: autoApprove,
      useDeferredLoading: useDeferredLoading,
    );

    // Temporarily add full configuration to flutter_intl section for intl_utils
    await _addTemporaryIntlUtilsConfig(
      projectDirectory: projectDirectory,
      arbDirectory: arbDirectory,
      outputDirectory: outputDirectory,
      className: className,
      mainLocale: mainLocale,
      useDeferredLoading: useDeferredLoading,
    );

    try {
      // Run intl_utils generation
      await _runIntlUtilsGeneration(projectDirectory);
    } finally {
      // Clean up flutter_intl section to keep only enabled: true
      await _cleanupIntlUtilsConfig(projectDirectory);
    }
  }

  /// Creates l10n.yaml configuration file for gen-l10n
  static Future<void> _createL10nYamlConfig({
    required String projectDirectory,
    required String arbDirectory,
    required String outputDirectory,
    required String? className,
    required String mainLocale,
    bool autoApprove = false,
    bool useDeferredLoading = false,
  }) async {
    final l10nYamlFile = File(path.join(projectDirectory, 'l10n.yaml'));

    // Convert paths to be relative to the project directory
    final relativeArbDir = path.relative(arbDirectory, from: projectDirectory);
    final relativeOutputDir = path.relative(outputDirectory, from: projectDirectory);

    if (!autoApprove) {
      print('\n📝 Creating l10n.yaml configuration file for Flutter gen-l10n...');
      print('This will create: ${l10nYamlFile.path}');
      print('Continue? (Y/n): ');

      final input = stdin.readLineSync()?.toLowerCase().trim() ?? '';
      if (input == 'n' || input == 'no') {
        throw Exception('User declined l10n.yaml creation');
      }
    }

    if (className == null || className.isEmpty) {
      className = 'AppLocalizations';
    }

    final l10nConfig = '''
arb-dir: $relativeArbDir
template-arb-file: intl_$mainLocale.arb
output-localization-file: ${camelToSnake(className)}.dart
output-class: $className
output-dir: $relativeOutputDir
use-deferred-loading: $useDeferredLoading
''';

    await l10nYamlFile.writeAsString(l10nConfig);
    print('📝 Created l10n.yaml configuration file');
  }

  static String camelToSnake(String text) {
    return text.replaceAllMapped(RegExp(r'(?<=[a-z])[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}').toLowerCase();
  }

  /// Finds the Flutter project directory by looking for pubspec.yaml
  static String _findFlutterProjectDirectory(String arbDirectory) {
    // Convert to absolute path
    final arbDirAbsolute = path.absolute(arbDirectory);
    print('🔍 Looking for Flutter project from ARB directory: $arbDirAbsolute');

    var currentDir = Directory(arbDirAbsolute);

    // Go up the directory tree to find pubspec.yaml
    while (currentDir.parent.path != currentDir.path) {
      final pubspecFile = File(path.join(currentDir.path, 'pubspec.yaml'));
      print('🔍 Checking for pubspec.yaml at: ${pubspecFile.path}');

      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        // Check if it's a Flutter project (contains flutter dependency)
        if (content.contains('flutter:') || content.contains('flutter_test:')) {
          print('📁 Found Flutter project directory: ${currentDir.path}');
          return currentDir.path;
        } else {
          print('📄 Found pubspec.yaml but not a Flutter project');
        }
      }
      currentDir = currentDir.parent;
    }

    // Special case: if ARB directory is something like "example/flutter_app/lib/l10n"
    // Try to find the Flutter project by going up from the ARB directory
    final pathParts = arbDirAbsolute.split(path.separator);
    for (int i = pathParts.length - 1; i >= 0; i--) {
      final testPath = pathParts.sublist(0, i + 1).join(path.separator);
      final pubspecFile = File(path.join(testPath, 'pubspec.yaml'));

      if (pubspecFile.existsSync()) {
        final content = pubspecFile.readAsStringSync();
        if (content.contains('flutter:') || content.contains('flutter_test:')) {
          print('📁 Found Flutter project directory: $testPath');
          return testPath;
        }
      }
    }

    // Last resort: use the directory containing the ARB directory
    final fallbackDir = path.dirname(arbDirAbsolute);
    print('⚠️  No Flutter project found, using fallback directory: $fallbackDir');
    return fallbackDir;
  }

  /// Creates or updates pubspec.yaml with intl_utils configuration
  static Future<void> _createIntlUtilsConfig({
    required String projectDirectory,
    required String arbDirectory,
    required String outputDirectory,
    required String className,
    required String mainLocale,
    bool autoApprove = false,
    bool useDeferredLoading = false,
  }) async {
    final pubspecFile = File(path.join(projectDirectory, 'pubspec.yaml'));

    if (!pubspecFile.existsSync()) {
      throw Exception('pubspec.yaml not found in project directory: $projectDirectory');
    }

    final pubspecContent = await pubspecFile.readAsString();
    final pubspecYaml = loadYaml(pubspecContent) as Map;

    // Convert paths to be relative to the project directory
    final relativeArbDir = path.relative(arbDirectory, from: projectDirectory);
    final relativeOutputDir = path.relative(outputDirectory, from: projectDirectory);

    // Check what needs to be added
    final setupInfo =
        _analyzeProjectSetup(pubspecYaml, relativeArbDir, relativeOutputDir, className, mainLocale, useDeferredLoading);

    if (!setupInfo.needsChanges) {
      print('✅ Project already configured for intl_utils');
      return;
    }

    // Ask for user permission before making changes
    if (!autoApprove && !await _requestUserPermission(setupInfo)) {
      print('❌ Skipping pubspec.yaml modifications.');
      _printManualSetupInstructions(setupInfo);
      throw Exception('User declined pubspec.yaml modifications. Please set up manually or use --no-generate_dart');
    }

    // Make targeted modifications to preserve formatting and comments
    await _makeTargetedPubspecChanges(
      pubspecFile: pubspecFile,
      pubspecContent: pubspecContent,
      setupInfo: setupInfo,
      relativeArbDir: relativeArbDir,
      relativeOutputDir: relativeOutputDir,
      className: className,
      mainLocale: mainLocale,
      useDeferredLoading: useDeferredLoading,
    );

    print('📝 Updated pubspec.yaml with intl_utils configuration');
  }

  /// Runs intl_utils generation command
  static Future<void> _runIntlUtilsGeneration(String projectDir) async {
    print('🚀 Running intl_utils code generation...');

    final result = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: projectDir,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to run dart pub get: ${result.stderr}');
    }

    final generateResult = await Process.run(
      'dart',
      ['run', 'intl_utils:generate'],
      workingDirectory: projectDir,
    );

    if (generateResult.exitCode != 0) {
      throw Exception('Failed to generate Dart code: ${generateResult.stderr}');
    }

    print('✅ intl_utils generation completed');
  }

  /// Prints usage instructions for the generated code
  static void _printUsageInstructions(String className, String outputDirectory, String method) {
    print('\n📚 Usage Instructions:');
    print('1. Import the generated localization class:');

    if (method == 'gen-l10n') {
      print('   import \'$outputDirectory/${className.toLowerCase()}.dart\';');
    } else {
      print('   import \'$outputDirectory/l10n.dart\';');
    }

    print('');
    print('2. Add to your MaterialApp:');
    print('   MaterialApp(');
    print('     localizationsDelegates: $className.localizationsDelegates,');
    print('     supportedLocales: $className.supportedLocales,');
    print('     // ... other properties');
    print('   )');
    print('');
    print('3. Use in your widgets:');
    print('   Text($className.of(context).yourTranslationKey)');
    print('');

    if (method == 'gen-l10n') {
      print(
          '🔗 For more information, visit: https://docs.flutter.dev/development/accessibility-and-localization/internationalization');
    } else {
      print('🔗 For more information, visit: https://pub.dev/packages/intl_utils');
    }
  }

  /// Validates that required ARB files exist
  static Future<bool> validateArbFiles({
    required String arbDirectory,
    required List<String> languageCodes,
    required String mainLocale,
  }) async {
    final arbDir = Directory(arbDirectory);

    if (!arbDir.existsSync()) {
      print('❌ ARB directory not found: $arbDirectory');
      return false;
    }

    // Check for main locale file
    final mainArbFile = File(path.join(arbDirectory, 'intl_$mainLocale.arb'));
    if (!mainArbFile.existsSync()) {
      print('❌ Main ARB file not found: ${mainArbFile.path}');
      return false;
    }

    // Check for language-specific files
    final missingFiles = <String>[];
    for (final langCode in languageCodes) {
      final arbFile = File(path.join(arbDirectory, 'intl_$langCode.arb'));
      if (!arbFile.existsSync()) {
        missingFiles.add('intl_$langCode.arb');
      }
    }

    if (missingFiles.isNotEmpty) {
      print('⚠️  Some ARB files are missing: ${missingFiles.join(', ')}');
      print('   Dart code generation will proceed with available files.');
    }

    return true;
  }

  /// Analyzes the current project setup to determine what needs to be added
  static _ProjectSetupInfo _analyzeProjectSetup(
    Map pubspecYaml,
    String relativeArbDir,
    String relativeOutputDir,
    String className,
    String mainLocale,
    bool useDeferredLoading,
  ) {
    final devDependencies = pubspecYaml['dev_dependencies'] as Map? ?? {};
    final flutterIntl = pubspecYaml['flutter_intl'] as Map?;

    final needsIntlUtils = !devDependencies.containsKey('intl_utils');
    final needsFlutterIntl = flutterIntl == null;

    final flutterIntlConfig = {
      'enabled': true,
    };

    return _ProjectSetupInfo(
      needsIntlUtils: needsIntlUtils,
      needsFlutterIntl: needsFlutterIntl,
      intlUtilsVersion: '^2.8.10',
      flutterIntlConfig: flutterIntlConfig,
    );
  }

  /// Requests user permission before modifying pubspec.yaml
  static Future<bool> _requestUserPermission(_ProjectSetupInfo setupInfo) async {
    print('\n🔍 Checking Flutter project setup...');

    if (setupInfo.needsIntlUtils || setupInfo.needsFlutterIntl) {
      print('\n❌ Missing required configuration for Dart code generation:');

      if (setupInfo.needsIntlUtils) {
        print('   - intl_utils package not found in dev_dependencies');
      }

      if (setupInfo.needsFlutterIntl) {
        print('   - flutter_intl configuration not found in pubspec.yaml');
      }

      print('\n📝 To generate Dart localization code, we need to add:');

      if (setupInfo.needsIntlUtils) {
        print('\ndev_dependencies:');
        print('  intl_utils: ${setupInfo.intlUtilsVersion}');
      }

      if (setupInfo.needsFlutterIntl) {
        print('\nflutter_intl:');
        setupInfo.flutterIntlConfig.forEach((key, value) {
          print('  $key: $value');
        });
      }

      print('\nWould you like to automatically add these to your pubspec.yaml? (y/N): ');

      final input = stdin.readLineSync()?.toLowerCase().trim() ?? '';
      return input == 'y' || input == 'yes';
    }

    return true;
  }

  /// Prints manual setup instructions when user declines automatic setup
  static void _printManualSetupInstructions(_ProjectSetupInfo setupInfo) {
    print('\n📋 Manual Setup Instructions:');

    if (setupInfo.needsIntlUtils) {
      print('\n1. Add intl_utils to your dev_dependencies in pubspec.yaml:');
      print('   dev_dependencies:');
      print('     intl_utils: ${setupInfo.intlUtilsVersion}');
    }

    if (setupInfo.needsFlutterIntl) {
      print('\n2. Add flutter_intl configuration to your pubspec.yaml:');
      print('   flutter_intl:');
      setupInfo.flutterIntlConfig.forEach((key, value) {
        print('     $key: $value');
      });
    }

    print('\n3. Run: dart pub get');
    print('4. Re-run this command');
    print('\nAlternatively, use --no-generate_dart to skip Dart code generation entirely.');
  }

  /// Makes targeted changes to pubspec.yaml while preserving formatting and comments
  static Future<void> _makeTargetedPubspecChanges({
    required File pubspecFile,
    required String pubspecContent,
    required _ProjectSetupInfo setupInfo,
    required String relativeArbDir,
    required String relativeOutputDir,
    required String className,
    required String mainLocale,
    required bool useDeferredLoading,
  }) async {
    var modifiedContent = pubspecContent;

    // Add intl_utils to dev_dependencies if needed
    if (setupInfo.needsIntlUtils) {
      modifiedContent = _addIntlUtilsToDependencies(modifiedContent);
    }

    // Add flutter_intl configuration if needed
    if (setupInfo.needsFlutterIntl) {
      modifiedContent = _addFlutterIntlConfig(
        modifiedContent,
        className: className,
        mainLocale: mainLocale,
        arbDir: relativeArbDir,
        outputDir: relativeOutputDir,
        useDeferredLoading: useDeferredLoading,
      );
    }

    // Write the modified content back to the file
    await pubspecFile.writeAsString(modifiedContent);
  }

  /// Adds intl_utils to dev_dependencies section
  static String _addIntlUtilsToDependencies(String pubspecContent) {
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];
    bool inDevDependencies = false;
    bool addedIntlUtils = false;
    int devDependenciesIndent = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if we're entering dev_dependencies section
      if (trimmedLine.startsWith('dev_dependencies:')) {
        inDevDependencies = true;
        devDependenciesIndent = line.indexOf('dev_dependencies:');
        modifiedLines.add(line);
        continue;
      }

      // Check if we're leaving dev_dependencies section
      if (inDevDependencies && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inDevDependencies = false;
        // Add intl_utils before leaving the section if we haven't added it yet
        if (!addedIntlUtils) {
          modifiedLines.add('${' ' * (devDependenciesIndent + 2)}intl_utils: ^2.8.10');
          addedIntlUtils = true;
        }
      }

      // If we're in dev_dependencies and this is the last line of the file
      if (inDevDependencies && i == lines.length - 1 && !addedIntlUtils) {
        modifiedLines.add(line);
        modifiedLines.add('${' ' * (devDependenciesIndent + 2)}intl_utils: ^2.8.10');
        addedIntlUtils = true;
        continue;
      }

      modifiedLines.add(line);
    }

    // If dev_dependencies section doesn't exist, add it
    if (!addedIntlUtils) {
      modifiedLines.add('dev_dependencies:');
      modifiedLines.add('  intl_utils: ^2.8.10');
    }

    return modifiedLines.join('\n');
  }

  /// Adds flutter_intl configuration section (minimal - just enabled: true)
  /// The actual configuration is handled by smart_arb_translator section
  static String _addFlutterIntlConfig(
    String pubspecContent, {
    required String className,
    required String mainLocale,
    required String arbDir,
    required String outputDir,
    required bool useDeferredLoading,
  }) {
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];

    // Add flutter_intl configuration at the end of the file
    modifiedLines.addAll(lines);

    // Ensure there's a blank line before the new section
    if (modifiedLines.isNotEmpty && modifiedLines.last.trim().isNotEmpty) {
      modifiedLines.add('');
    }

    // Add minimal flutter_intl configuration - just enabled: true
    // The smart_arb_translator section will handle the actual configuration
    modifiedLines.addAll([
      'flutter_intl:',
      '  enabled: true',
    ]);

    return modifiedLines.join('\n');
  }

  /// Temporarily adds full configuration to flutter_intl section for intl_utils to read
  static Future<void> _addTemporaryIntlUtilsConfig({
    required String projectDirectory,
    required String arbDirectory,
    required String outputDirectory,
    required String className,
    required String mainLocale,
    required bool useDeferredLoading,
  }) async {
    final pubspecFile = File(path.join(projectDirectory, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return;

    final pubspecContent = await pubspecFile.readAsString();
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];

    // Convert paths to be relative to the project directory
    final relativeArbDir = path.relative(arbDirectory, from: projectDirectory);
    final relativeOutputDir = path.relative(outputDirectory, from: projectDirectory);

    bool inFlutterIntl = false;
    int flutterIntlIndent = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if we're entering flutter_intl section
      if (trimmedLine == 'flutter_intl:') {
        inFlutterIntl = true;
        flutterIntlIndent = line.indexOf('flutter_intl:');
        modifiedLines.add(line);

        // Add full configuration for intl_utils
        modifiedLines.addAll([
          '${' ' * (flutterIntlIndent + 2)}enabled: true',
          '${' ' * (flutterIntlIndent + 2)}class_name: $className',
          '${' ' * (flutterIntlIndent + 2)}main_locale: $mainLocale',
          '${' ' * (flutterIntlIndent + 2)}arb_dir: $relativeArbDir',
          '${' ' * (flutterIntlIndent + 2)}output_dir: $relativeOutputDir',
          '${' ' * (flutterIntlIndent + 2)}use_deferred_loading: $useDeferredLoading',
        ]);
        continue;
      }

      // Check if we're leaving flutter_intl section
      if (inFlutterIntl && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inFlutterIntl = false;
      }

      // Skip existing configuration lines in flutter_intl section
      if (inFlutterIntl &&
          (trimmedLine.startsWith('enabled:') ||
              trimmedLine.startsWith('class_name:') ||
              trimmedLine.startsWith('main_locale:') ||
              trimmedLine.startsWith('arb_dir:') ||
              trimmedLine.startsWith('output_dir:') ||
              trimmedLine.startsWith('use_deferred_loading:'))) {
        continue;
      }

      modifiedLines.add(line);
    }

    await pubspecFile.writeAsString(modifiedLines.join('\n'));
    print('📝 Temporarily added full configuration to flutter_intl section');
  }

  /// Cleans up flutter_intl section to keep only enabled: true
  static Future<void> _cleanupIntlUtilsConfig(String projectDirectory) async {
    final pubspecFile = File(path.join(projectDirectory, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) return;

    final pubspecContent = await pubspecFile.readAsString();
    final lines = pubspecContent.split('\n');
    final modifiedLines = <String>[];

    bool inFlutterIntl = false;
    int flutterIntlIndent = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // Check if we're entering flutter_intl section
      if (trimmedLine == 'flutter_intl:') {
        inFlutterIntl = true;
        flutterIntlIndent = line.indexOf('flutter_intl:');
        modifiedLines.add(line);
        // Add only enabled: true
        modifiedLines.add('${' ' * (flutterIntlIndent + 2)}enabled: true');
        continue;
      }

      // Check if we're leaving flutter_intl section
      if (inFlutterIntl && line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('\t')) {
        inFlutterIntl = false;
      }

      // Skip all configuration lines in flutter_intl section except enabled
      if (inFlutterIntl &&
          (trimmedLine.startsWith('enabled:') ||
              trimmedLine.startsWith('class_name:') ||
              trimmedLine.startsWith('main_locale:') ||
              trimmedLine.startsWith('arb_dir:') ||
              trimmedLine.startsWith('output_dir:') ||
              trimmedLine.startsWith('use_deferred_loading:'))) {
        continue;
      }

      modifiedLines.add(line);
    }

    await pubspecFile.writeAsString(modifiedLines.join('\n'));
    print('🧹 Cleaned up flutter_intl section (kept only enabled: true)');
  }
}
