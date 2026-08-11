import 'dart:io';

import 'models/arb_document.dart';
import 'models/translation_resource.dart';

class LocalizationValidationIssue {
  final String code;
  final String key;
  final String message;

  const LocalizationValidationIssue(this.code, this.key, this.message);

  @override
  String toString() => '$code [$key] $message';
}

/// Deterministic, provider-independent localization safety checks.
class LocalizationValidator {
  static final _locale = RegExp(r'^[a-z]{2,3}(?:[-_](?:[A-Z]{2}|[A-Z][a-z]{3}|\d{3}))?$');
  static final _placeholder = RegExp(r'\{\s*([A-Za-z_]\w*)\s*\}');
  static final _englishWord = RegExp(r'[A-Za-z]{3,}');
  static final _commentary = RegExp(
    r"(?:here(?:'s| is)(?: the)? translation|translation\s*:|sure[,!]|note\s*:|i (?:cannot|can't)|as an ai|have to correct|got cut off|unable to translate|sorry[,!])",
    caseSensitive: false,
  );

  static List<LocalizationValidationIssue> validatePair({
    required ArbDocument source,
    required ArbDocument target,
    required String targetLocale,
    Iterable<String> passthroughAllowlist = const [],
  }) {
    final issues = <LocalizationValidationIssue>[];
    final allowedPassthrough = passthroughAllowlist.map((value) => value.trim().toLowerCase()).toSet();
    if (!_locale.hasMatch(targetLocale)) {
      issues.add(LocalizationValidationIssue('invalid_locale', '@@locale', 'Invalid target locale $targetLocale.'));
    }
    for (final entry in source.resources.entries) {
      final targetResource = target.resources[entry.key];
      if (targetResource == null) {
        issues.add(LocalizationValidationIssue('missing_key', entry.key, 'Target resource is missing.'));
        continue;
      }
      final value = targetResource.text;
      if (value.trim().isEmpty) {
        issues.add(LocalizationValidationIssue('empty_translation', entry.key, 'Translation is empty.'));
      }
      if (_commentary.hasMatch(value)) {
        issues
            .add(LocalizationValidationIssue('translator_commentary', entry.key, 'Looks like translator commentary.'));
      }
      final sourceStructured = TranslationResource.fromArbResource(entry.value, sourceTopic: 'validation');
      final sourceSimplePlaceholders =
          _placeholder.allMatches(entry.value.text).map((match) => match.group(1)!).toSet();
      final targetSimplePlaceholders = <String>{
        ..._placeholder.allMatches(value).map((match) => match.group(1)!),
        ...TranslationResource.fromArbResource(
          targetResource,
          sourceTopic: 'validation',
        ).icuVariables,
      };
      final declaredPlaceholders = entry.value.attributes?.placeholders?.keys.toSet() ?? const <String>{};
      final sourcePlaceholders = sourceStructured.icuVariables.isEmpty
          ? sourceSimplePlaceholders
          : <String>{
              ...declaredPlaceholders,
              ...sourceSimplePlaceholders.where(sourceStructured.icuVariables.contains),
            };
      final targetPlaceholders = sourceStructured.icuVariables.isEmpty
          ? targetSimplePlaceholders
          : targetSimplePlaceholders.intersection(sourcePlaceholders);
      if (!_sameSet(sourcePlaceholders, targetPlaceholders)) {
        issues.add(
            LocalizationValidationIssue('placeholder_parity', entry.key, 'Source and target placeholders differ.'));
      }
      final targetStructured = TranslationResource.fromArbResource(targetResource, sourceTopic: 'validation');
      if (!_sameSet(sourceStructured.icuVariables.toSet(), targetStructured.icuVariables.toSet()) ||
          !_sameSet(sourceStructured.icuRoles.toSet(), targetStructured.icuRoles.toSet()) ||
          !_sameSet(sourceStructured.icuBranches.toSet(), targetStructured.icuBranches.toSet())) {
        issues.add(LocalizationValidationIssue('icu_integrity', entry.key, 'Plural/select roles or branches differ.'));
      }
      if (_looksLikePassthrough(entry.key, entry.value.text, value, targetLocale, allowedPassthrough)) {
        issues.add(LocalizationValidationIssue('source_passthrough', entry.key, 'Likely untranslated source text.'));
      }
      final scriptIssue = _scriptIssue(value, targetLocale, targetStructured);
      if (scriptIssue != null) {
        issues.add(LocalizationValidationIssue(scriptIssue, entry.key, 'Likely target-locale script mismatch.'));
      }
      if (entry.value.text.length >= 10 && value.length > entry.value.text.length * 6) {
        issues.add(LocalizationValidationIssue(
            'length_expansion', entry.key, 'Translation is more than six times source length.'));
      }
    }
    for (final entry in source.resources.entries) {
      final translations = entry.value.attributes?.xTranslations;
      if (translations == null) {
        continue;
      }
      for (final override in translations.entries) {
        if (!_locale.hasMatch(override.key) || override.value is! String || (override.value as String).trim().isEmpty) {
          issues.add(LocalizationValidationIssue(
              'invalid_x_translation', entry.key, 'Invalid x-translations entry for ${override.key}.'));
        }
      }
    }
    for (final key in target.resources.keys) {
      if (!source.resources.containsKey(key)) {
        issues.add(LocalizationValidationIssue('extra_target_key', key, 'Target has no matching source resource.'));
      }
    }
    return issues;
  }

  static List<LocalizationValidationIssue> validateArbFile(File file, {String? expectedLocale}) {
    try {
      final document = ArbDocument.decode(file.readAsStringSync());
      final issues = <LocalizationValidationIssue>[];
      final actual = document.locale;
      if (actual != null && !_locale.hasMatch(actual)) {
        issues.add(
            LocalizationValidationIssue('invalid_locale', '@@locale', '${file.path} declares invalid locale $actual.'));
      }
      if (expectedLocale != null &&
          actual != null &&
          actual.replaceAll('_', '-').toLowerCase() != expectedLocale.replaceAll('_', '-').toLowerCase()) {
        issues.add(LocalizationValidationIssue(
            'locale_mismatch', '@@locale', '${file.path} declares $actual, expected $expectedLocale.'));
      }
      for (final resource in document.resources.values) {
        try {
          resource.tokens;
        } catch (error) {
          issues.add(LocalizationValidationIssue('invalid_icu', resource.id, '$error'));
        }
        final overrides = resource.attributes?.xTranslations;
        if (overrides != null) {
          for (final override in overrides.entries) {
            if (!_locale.hasMatch(override.key) ||
                override.value is! String ||
                (override.value as String).trim().isEmpty) {
              issues.add(LocalizationValidationIssue(
                  'invalid_x_translation', resource.id, 'Invalid x-translations entry for ${override.key}.'));
            }
          }
        }
      }
      return issues;
    } on FormatException catch (error) {
      return [LocalizationValidationIssue('invalid_arb', '@@file', '${file.path}: $error')];
    } catch (error) {
      return [LocalizationValidationIssue('invalid_icu_or_arb', '@@file', '${file.path}: $error')];
    }
  }

  static List<LocalizationValidationIssue> validateLocaleArtifacts({
    required Iterable<String> supportedLocales,
    required Iterable<String> generatedLocales,
  }) {
    final issues = <LocalizationValidationIssue>[];
    final seen = <String>{};
    for (final locale in generatedLocales) {
      if (!seen.add(locale)) {
        issues.add(LocalizationValidationIssue('duplicate_locale_artifact', locale, 'Duplicate locale artifact.'));
      }
      if (!supportedLocales.contains(locale)) {
        issues.add(LocalizationValidationIssue('stale_locale_artifact', locale, 'Locale is not supported.'));
      }
    }
    return issues;
  }

  static bool _sameSet(Set<String> left, Set<String> right) => left.length == right.length && left.containsAll(right);

  /// A caller may allow a resource key or literal value for brands/technical
  /// tokens that deliberately remain unchanged across locales.
  static bool _looksLikePassthrough(
    String key,
    String source,
    String target,
    String locale,
    Set<String> allowlist,
  ) {
    if (locale.toLowerCase().startsWith('en')) return false;
    final normalizedSource = source.replaceAll(_placeholder, '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final normalizedTarget = target.replaceAll(_placeholder, '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (allowlist.contains(key.toLowerCase()) ||
        allowlist.contains(normalizedSource) ||
        allowlist.contains(normalizedTarget)) {
      return false;
    }
    if (normalizedSource != normalizedTarget) return false;
    // Short imperative controls are the most consequential false-successes.
    // Keep this conservative: only alphabetic words/phrases qualify, while
    // URLs, IDs, and punctuation-heavy technical strings do not.
    return RegExp(r'^[a-z][a-z0-9]*(?:[ -][a-z][a-z0-9]*)*$', caseSensitive: false).hasMatch(normalizedSource);
  }

  static String? _scriptIssue(
    String value,
    String locale,
    TranslationResource structured,
  ) {
    final profile = _scriptProfile(locale);
    if (profile == null) return null;
    // Ignore technical values and tolerate a single product/brand word.
    var prose = value
        .replaceAll(_placeholder, '')
        .replaceAll(RegExp(r'https?://\S+', caseSensitive: false), '')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    // ICU syntax is deliberately ASCII in every locale. Exclude its variable,
    // role, and branch tokens while retaining the human-readable branch text;
    // otherwise valid Japanese/Korean messages look spuriously mixed-script.
    for (final token in <String>{
      ...structured.icuVariables,
      ...structured.icuRoles,
      ...structured.icuBranches,
    }) {
      final escaped = RegExp.escape(token);
      final pattern = token.startsWith('=') ? RegExp(escaped) : RegExp('(?<![A-Za-z0-9_])$escaped(?![A-Za-z0-9_])');
      prose = prose.replaceAll(pattern, ' ');
    }
    prose = prose.replaceAll(RegExp(r'\boffset\s*:\s*\d+\b'), ' ').replaceAll(RegExp(r'[{},]'), ' ');
    final expectedCharacters = profile.allMatches(prose).length;
    final latinWords = _englishWord.allMatches(prose).map((match) => match.group(0)!).toList(growable: false);
    final latinCharacters = latinWords.fold<int>(0, (sum, word) => sum + word.length);
    if (expectedCharacters == 0 && latinWords.length >= 2) return 'target_script_mismatch';
    if (expectedCharacters > 0 && latinWords.length >= 2 && latinCharacters > expectedCharacters * 2) {
      return 'likely_mixed_language';
    }
    return null;
  }

  static RegExp? _scriptProfile(String locale) {
    final parts = locale.toLowerCase().split(RegExp('[-_]'));
    final language = parts.first;
    String? explicitScript;
    for (final part in parts.skip(1)) {
      if (part.length == 4) {
        explicitScript = part;
        break;
      }
    }
    if (explicitScript == 'latn') return null;
    if (explicitScript == 'cyrl') return RegExp(r'[\u0400-\u052F]');
    if (const {'ar', 'fa', 'ur', 'ps'}.contains(language)) return RegExp(r'[\u0600-\u06FF]');
    if (language == 'el') return RegExp(r'[\u0370-\u03FF]');
    if (language == 'hy') return RegExp(r'[\u0530-\u058F]');
    if (language == 'ka') return RegExp(r'[\u10A0-\u10FF]');
    if (const {'ru', 'uk', 'bg', 'be', 'mk', 'sr', 'kk', 'ky', 'mn'}.contains(language)) {
      return RegExp(r'[\u0400-\u052F]');
    }
    if (language == 'th') return RegExp(r'[\u0E00-\u0E7F]');
    if (language == 'ko') return RegExp(r'[\uAC00-\uD7AF\u4E00-\u9FFF]');
    if (language == 'ja') return RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF]');
    if (language == 'zh') return RegExp(r'[\u3400-\u9FFF]');
    return null;
  }
}
