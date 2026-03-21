import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:smart_arb_translator/src/models/arb_resource.dart';

final RegExp _englishWordRegex = RegExp(r'[A-Za-z]{3,}');
final RegExp _placeholderRegex = RegExp(r'\{[^}]+\}');
final RegExp _nonLetterRegex = RegExp(r'[^A-Za-z ]+');
final RegExp _nestedIcuRegex = RegExp(r'\{(\w+),\s*(plural|select),[\s\S]*\{\{\1,\s*\2,');
final RegExp _icuOptionRegex = RegExp(
  r'(?:=\d+|zero|one|two|few|many|other|[A-Za-z_][A-Za-z0-9_]*)\{((?:[^{}]|\{[^{}]+\})*)\}',
);

class CacheCleanupResult {
  final Map<String, List<String>> removedKeysByLocale;
  final bool dryRun;

  const CacheCleanupResult({
    required this.removedKeysByLocale,
    required this.dryRun,
  });

  int get totalRemoved => removedKeysByLocale.values.fold<int>(0, (sum, keys) => sum + keys.length);

  int get affectedLocales => removedKeysByLocale.length;

  bool get hasChanges => totalRemoved > 0;
}

class CacheCleanupService {
  static CacheCleanupResult cleanCorruptedCache({
    required String cacheDirectory,
    Set<String>? locales,
    bool dryRun = false,
  }) {
    final cacheDir = Directory(path.normalize(path.absolute(cacheDirectory)));
    if (!cacheDir.existsSync()) {
      throw ArgumentError('Cache directory does not exist: ${cacheDir.path}');
    }

    final englishFile = File(path.join(cacheDir.path, 'en', 'intl_en.arb'));
    if (!englishFile.existsSync()) {
      throw ArgumentError('English cache file not found: ${englishFile.path}');
    }

    final sourceDocument = ArbDocument.decode(englishFile.readAsStringSync());
    final removedKeysByLocale = <String, List<String>>{};

    final localeDirs = cacheDir
        .listSync()
        .whereType<Directory>()
        .where((dir) => path.basename(dir.path) != 'en')
        .where((dir) => locales == null || locales.contains(path.basename(dir.path)))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final localeDir in localeDirs) {
      final locale = path.basename(localeDir.path);
      final cacheFile = File(path.join(localeDir.path, 'intl_$locale.arb'));
      if (!cacheFile.existsSync()) {
        continue;
      }

      final localizedDocument = ArbDocument.decode(cacheFile.readAsStringSync());
      final updatedResources = <String, ArbResource>{...localizedDocument.resources};
      final removedKeys = <String>[];

      for (final entry in localizedDocument.resources.entries) {
        final sourceResource = sourceDocument.resources[entry.key];
        if (sourceResource == null || !_isPotentiallyAffectedSource(sourceResource)) {
          continue;
        }

        if (_isCorruptedCachedResource(
          sourceResource: sourceResource,
          localizedText: entry.value.text,
          locale: locale,
        )) {
          updatedResources.remove(entry.key);
          removedKeys.add(entry.key);
        }
      }

      if (removedKeys.isEmpty) {
        continue;
      }

      removedKeysByLocale[locale] = removedKeys;

      if (!dryRun) {
        final cleanedDocument = localizedDocument.copyWith(resources: updatedResources);
        cacheFile.writeAsStringSync(cleanedDocument.encode());
      }
    }

    return CacheCleanupResult(
      removedKeysByLocale: removedKeysByLocale,
      dryRun: dryRun,
    );
  }
}

bool _isPotentiallyAffectedSource(ArbResource sourceResource) {
  return sourceResource.text.contains('{') ||
      (sourceResource.attributes?.placeholders?.isNotEmpty ?? false) ||
      (sourceResource.attributes?.xTranslations?.isNotEmpty ?? false);
}

bool _isCorruptedCachedResource({
  required ArbResource sourceResource,
  required String localizedText,
  required String locale,
}) {
  if (localizedText.contains('SMART_ARB_PH_')) {
    return true;
  }

  if (_nestedIcuRegex.hasMatch(localizedText)) {
    return true;
  }

  final manualTranslation = sourceResource.attributes?.xTranslations?[locale];
  if (manualTranslation is String &&
      manualTranslation.isNotEmpty &&
      localizedText.contains(manualTranslation) &&
      localizedText != manualTranslation) {
    return true;
  }

  for (final englishSegment in _englishSourceSegments(sourceResource)) {
    if (localizedText.contains(englishSegment)) {
      return true;
    }
  }

  return false;
}

Iterable<String> _englishSourceSegments(ArbResource sourceResource) sync* {
  final seen = <String>{};
  final isIcuMessage = _isIcuMessage(sourceResource.text);
  for (final candidate in <String>[
    sourceResource.text,
    ..._extractIcuOptionTexts(sourceResource.text),
  ]) {
    if (seen.contains(candidate)) {
      continue;
    }
    seen.add(candidate);
    if (_looksLikeEnglishSegment(candidate, allowShortIcuBranch: isIcuMessage)) {
      yield candidate;
    }
  }
}

bool _looksLikeEnglishSegment(String text, {required bool allowShortIcuBranch}) {
  final withoutPlaceholders = text.replaceAll(_placeholderRegex, ' ');
  final lettersOnly = withoutPlaceholders.replaceAll(_nonLetterRegex, ' ');
  final englishWords = _englishWordRegex.allMatches(lettersOnly).map((match) => match.group(0)!).toList();
  if (allowShortIcuBranch && englishWords.isNotEmpty && RegExp(r'^\s*(?:\d+|\{[^}]+\})\s+[A-Za-z]').hasMatch(text)) {
    return true;
  }
  final minimumWordCount = allowShortIcuBranch ? 2 : 3;
  return englishWords.length >= minimumWordCount;
}

bool _isIcuMessage(String text) => RegExp(r'\{\w+,\s*(plural|select),').hasMatch(text);

Iterable<String> _extractIcuOptionTexts(String text) sync* {
  for (final match in _icuOptionRegex.allMatches(text)) {
    final optionText = match.group(1);
    if (optionText != null && optionText.isNotEmpty) {
      yield optionText;
    }
  }
}
