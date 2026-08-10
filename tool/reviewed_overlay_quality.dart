import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/smart_arb_translator.dart';

void main(List<String> arguments) {
  final code = runReviewedOverlayQualityCli(arguments);
  if (code != 0) exitCode = code;
}

/// Validates every paired English/reviewed feature ARB without invoking a
/// translation provider. This is intended as the final quality gate before a
/// manual-only merge.
int runReviewedOverlayQualityCli(
  List<String> arguments, {
  void Function(String value)? write,
  void Function(String value)? writeError,
}) {
  final out = write ?? stdout.writeln;
  final err = writeError ?? stderr.writeln;
  final parser = ArgParser()
    ..addOption('source-dir', help: 'Directory containing English feature ARBs.')
    ..addOption('reviewed-dir', help: 'Directory containing <locale>/<feature>.arb reviewed overlays.')
    ..addMultiOption('locale', help: 'Locale(s) to validate; defaults to every reviewed locale directory.')
    ..addOption(
      'allowlist-file',
      help: 'JSON array, or object with entries/keys/literals arrays, approved to remain source-equal.',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
  late ArgResults result;
  try {
    result = parser.parse(arguments);
  } on FormatException catch (error) {
    err(error.message);
    err(parser.usage);
    return 64;
  }
  if (result['help'] as bool) {
    out(parser.usage);
    return 0;
  }
  try {
    final sourceValue = (result['source-dir'] as String?)?.trim();
    final reviewedValue = (result['reviewed-dir'] as String?)?.trim();
    if (sourceValue == null || sourceValue.isEmpty) throw ArgumentError('--source-dir is required.');
    if (reviewedValue == null || reviewedValue.isEmpty) throw ArgumentError('--reviewed-dir is required.');
    final sourceDirectory = Directory(sourceValue);
    final reviewedDirectory = Directory(reviewedValue);
    if (!sourceDirectory.existsSync()) throw ArgumentError('Source directory does not exist: $sourceValue');
    if (!reviewedDirectory.existsSync()) throw ArgumentError('Reviewed directory does not exist: $reviewedValue');
    final allowlist = _readAllowlist(result['allowlist-file'] as String?);
    final requested = (result['locale'] as List<String>)
        .map((locale) => locale.trim().toLowerCase())
        .where((locale) => locale.isNotEmpty)
        .toSet();
    final discovered = reviewedDirectory
        .listSync()
        .whereType<Directory>()
        .map((directory) => path.basename(directory.path).toLowerCase())
        .toSet();
    final locales = (requested.isEmpty ? discovered : requested).toList()..sort();
    final sourceFiles = sourceDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
    if (sourceFiles.isEmpty) throw ArgumentError('Source directory has no ARB files: $sourceValue');
    final expectedFeatures = sourceFiles.map((file) => path.basename(file.path)).toSet();
    final issues = <Map<String, Object?>>[];
    var pairCount = 0;
    for (final locale in locales) {
      final localeDirectory = Directory(path.join(reviewedDirectory.path, locale));
      if (!localeDirectory.existsSync()) {
        issues.add(_issue(locale, '@@locale', 'missing_locale_directory', '@@file', localeDirectory.path));
        continue;
      }
      final actualFeatures = localeDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .map((file) => path.basename(file.path))
          .toSet();
      for (final unexpected in actualFeatures.difference(expectedFeatures).toList()..sort()) {
        issues.add(_issue(locale, unexpected, 'unexpected_reviewed_feature', '@@file', unexpected));
      }
      for (final sourceFile in sourceFiles) {
        final feature = path.basename(sourceFile.path);
        final targetFile = File(path.join(localeDirectory.path, feature));
        if (!targetFile.existsSync()) {
          issues.add(_issue(locale, feature, 'missing_reviewed_feature', '@@file', targetFile.path));
          continue;
        }
        pairCount++;
        try {
          final source = ArbDocument.decode(sourceFile.readAsStringSync());
          final target = ArbDocument.decode(targetFile.readAsStringSync());
          if (target.locale != null && !_sameLocale(target.locale!, locale)) {
            issues.add(_issue(locale, feature, 'locale_mismatch', '@@locale', 'Declares ${target.locale}.'));
          }
          final localeAllowlist = allowlist.forLocale(locale);
          for (final issue in LocalizationValidator.validatePair(
            source: source,
            target: target,
            targetLocale: locale,
            passthroughAllowlist: localeAllowlist,
          )) {
            final targetValue = target.resources[issue.key]?.text;
            if (_isAllowlistedQualityIssue(issue, targetValue, localeAllowlist)) continue;
            issues.add(_issue(locale, feature, issue.code, issue.key, issue.message));
          }
        } catch (error) {
          issues.add(_issue(locale, feature, 'invalid_arb_or_icu', '@@file', error.toString()));
        }
      }
    }
    issues.sort((left, right) {
      final leftKey = '${left['locale']}:${left['feature']}:${left['key']}:${left['code']}';
      final rightKey = '${right['locale']}:${right['feature']}:${right['key']}:${right['code']}';
      return leftKey.compareTo(rightKey);
    });
    final report = <String, Object?>{
      'schema_version': 1,
      'valid': issues.isEmpty,
      'locale_count': locales.length,
      'pair_count': pairCount,
      'issue_count': issues.length,
      'allowlist_count': allowlist.length,
      'issues': issues,
    };
    out(const JsonEncoder.withIndent('  ').convert(report));
    return issues.isEmpty ? 0 : 1;
  } catch (error) {
    err('Reviewed overlay validation failed: $error');
    return 1;
  }
}

_QualityAllowlist _readAllowlist(String? filePath) {
  if (filePath == null || filePath.trim().isEmpty) {
    return const _QualityAllowlist(<String>{}, <String, Set<String>>{});
  }
  final file = File(filePath);
  if (!file.existsSync()) throw ArgumentError('Allowlist file does not exist: ${file.path}');
  final decoded = jsonDecode(file.readAsStringSync());
  final values = <Object?>[];
  final localeValues = <String, Set<String>>{};
  if (decoded is List) {
    values.addAll(decoded);
  } else if (decoded is Map) {
    for (final field in const <String>['entries', 'keys', 'literals', 'global']) {
      final entries = decoded[field];
      if (entries is List) values.addAll(entries);
    }
    final locales = decoded['locales'];
    if (locales != null && locales is! Map) {
      throw const FormatException('Allowlist locales must be an object of string arrays.');
    }
    if (locales is Map) {
      for (final entry in locales.entries) {
        if (entry.key is! String || entry.value is! List) {
          throw const FormatException('Allowlist locales must be an object of string arrays.');
        }
        localeValues[entry.key.toString().toLowerCase()] = _validatedStrings(entry.value as List);
      }
    }
  } else {
    throw const FormatException('Allowlist must be a JSON array or object.');
  }
  return _QualityAllowlist(_validatedStrings(values), localeValues);
}

Set<String> _validatedStrings(List<Object?> values) {
  if (values.any((value) => value is! String || value.trim().isEmpty)) {
    throw const FormatException('Allowlist entries must be non-empty strings.');
  }
  return values.cast<String>().map((value) => value.trim()).toSet();
}

class _QualityAllowlist {
  const _QualityAllowlist(this.global, this.locales);

  final Set<String> global;
  final Map<String, Set<String>> locales;

  int get length => global.length + locales.values.fold<int>(0, (sum, entries) => sum + entries.length);

  Set<String> forLocale(String locale) => <String>{...global, ...?locales[locale.toLowerCase()]};
}

bool _isAllowlistedQualityIssue(
  LocalizationValidationIssue issue,
  String? targetValue,
  Set<String> allowlist,
) {
  if (!const <String>{'source_passthrough', 'target_script_mismatch', 'likely_mixed_language'}.contains(issue.code)) {
    return false;
  }
  final normalized = allowlist.map((value) => value.trim().toLowerCase()).toSet();
  return normalized.contains(issue.key.toLowerCase()) ||
      (targetValue != null && normalized.contains(targetValue.trim().toLowerCase()));
}

Map<String, Object?> _issue(String locale, String feature, String code, String key, String message) =>
    <String, Object?>{'locale': locale, 'feature': feature, 'code': code, 'key': key, 'message': message};

bool _sameLocale(String left, String right) =>
    left.trim().replaceAll('-', '_').toLowerCase() == right.trim().replaceAll('-', '_').toLowerCase();
