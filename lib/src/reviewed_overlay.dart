import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'models/arb_document.dart';
import 'models/translation_resource.dart';

class MissingManualCoverage {
  final String locale;
  final String sourceTopic;
  final String key;

  const MissingManualCoverage(this.locale, this.sourceTopic, this.key);

  @override
  String toString() => '$locale/$sourceTopic#$key';
}

class ManualCoverageException implements Exception {
  final List<MissingManualCoverage> missing;

  const ManualCoverageException(this.missing);

  @override
  String toString() => 'manual_only is missing reviewed or x-translations coverage for: '
      '${missing.map((entry) => entry.toString()).join(', ')}';
}

/// Reads a per-locale feature ARB and its adjacent review ledger.
class ReviewedOverlay {
  final Map<String, String> translations;

  const ReviewedOverlay(this.translations);

  static ReviewedOverlay load({
    required String? rootDirectory,
    required String locale,
    required String sourceFile,
    required Iterable<TranslationResource> resources,
    required String? translationContext,
    String reviewPromptVersion = 'review-context-v1',
  }) {
    if (rootDirectory == null || rootDirectory.trim().isEmpty) return const ReviewedOverlay({});
    final featureFile = File(
      path.join(rootDirectory, locale, path.basename(sourceFile)),
    );
    if (!featureFile.existsSync()) return const ReviewedOverlay({});

    final document = ArbDocument.decode(featureFile.readAsStringSync());
    if (document.locale != null && !_sameLocale(document.locale!, locale)) {
      throw FormatException(
        'Reviewed overlay ${featureFile.path} declares locale ${document.locale}, expected $locale.',
      );
    }
    final resourceById = <String, TranslationResource>{
      for (final resource in resources) resource.id: resource,
    };
    final ledgerFile = File(
      path.join(
        featureFile.parent.path,
        '${path.basenameWithoutExtension(featureFile.path)}.review.json',
      ),
    );
    if (!ledgerFile.existsSync()) {
      throw FormatException(
        'Reviewed overlay ${featureFile.path} is missing ledger ${ledgerFile.path}.',
      );
    }
    final ledger = jsonDecode(ledgerFile.readAsStringSync()) as Map<String, dynamic>;
    final unexpectedLedgerKeys = ledger.keys.where((key) => !document.resources.containsKey(key));
    if (unexpectedLedgerKeys.isNotEmpty) {
      throw FormatException(
          'Review ledger ${ledgerFile.path} contains unknown key(s): ${unexpectedLedgerKeys.join(', ')}.');
    }
    final results = <String, String>{};
    for (final entry in document.resources.entries) {
      final resource = resourceById[entry.key];
      if (resource == null) {
        throw FormatException(
          'Reviewed overlay ${featureFile.path} contains unknown key ${entry.key}.',
        );
      }
      final record = ledger[entry.key];
      if (record is! Map<String, dynamic>) {
        throw FormatException('Review ledger ${ledgerFile.path} lacks a record for ${entry.key}.');
      }
      _validateLedgerRecord(record, resource, entry.value.text, ledgerFile.path);
      final sourceFingerprint = TranslationFingerprint.source(resource);
      final contextFingerprint = TranslationFingerprint.reviewContext(
        resource,
        translationContext: translationContext,
        promptVersion: reviewPromptVersion,
      );
      if (record['sourceFingerprint'] == sourceFingerprint && record['contextFingerprint'] == contextFingerprint) {
        final value = entry.value.text;
        if (value.trim().isNotEmpty) results[entry.key] = value;
      }
    }
    return ReviewedOverlay(results);
  }

  static List<String> staleKeys({
    required String? rootDirectory,
    required String locale,
    required String sourceFile,
    required Iterable<TranslationResource> resources,
    required String? translationContext,
  }) {
    final resourceList = resources.toList(growable: false);
    final current = load(
      rootDirectory: rootDirectory,
      locale: locale,
      sourceFile: sourceFile,
      resources: resourceList,
      translationContext: translationContext,
    );
    return resourceList
        .where((resource) => !current.translations.containsKey(resource.id))
        .map((resource) => resource.id)
        .toList();
  }

  static bool _sameLocale(String left, String right) =>
      left.trim().replaceAll('-', '_').toLowerCase() == right.trim().replaceAll('-', '_').toLowerCase();
}

void _validateLedgerRecord(
  Map<String, dynamic> record,
  TranslationResource resource,
  String arbTranslation,
  String ledgerPath,
) {
  const required = ['source', 'translation', 'sourceFingerprint', 'contextFingerprint'];
  final missing = required.where((field) => record[field] is! String || (record[field] as String).trim().isEmpty);
  if (missing.isNotEmpty) {
    throw FormatException('Review ledger $ledgerPath is missing ${missing.join(', ')} for ${resource.id}.');
  }
  if (record['translation'] != arbTranslation) {
    throw FormatException('Review ledger $ledgerPath translation does not match reviewed ARB for ${resource.id}.');
  }
  // An old source/old fingerprint is valid review history and is classified as
  // stale below. A mismatched source paired with a current source fingerprint,
  // however, is internally inconsistent rather than merely stale.
  final currentSourceFingerprint = TranslationFingerprint.source(resource);
  if (record['source'] != resource.sourceText && record['sourceFingerprint'] == currentSourceFingerprint) {
    throw FormatException('Review ledger $ledgerPath source does not match its fingerprint for ${resource.id}.');
  }
  final hasReviewWorkflowFields = record.containsKey('reviewVersion') ||
      record.containsKey('primaryVerdict') ||
      record.containsKey('verificationVerdict');
  if (hasReviewWorkflowFields) {
    for (final field in ['primaryVerdict', 'verificationVerdict']) {
      if (record[field] is! String || (record[field] as String).trim().isEmpty) {
        throw FormatException('Review ledger $ledgerPath is missing $field for ${resource.id}.');
      }
    }
  }
}
