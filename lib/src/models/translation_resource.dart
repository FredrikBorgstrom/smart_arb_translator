import 'dart:convert';

import 'arb_resource.dart';

/// A complete ARB resource as seen by a context-aware translation provider.
///
/// Unlike the legacy [Action] representation this deliberately remains whole:
/// providers can therefore disambiguate short controls without losing the key,
/// ARB description, placeholders, or ICU structure that belongs to it.
class TranslationResource {
  final String id;
  final String sourceText;
  final String? description;
  final String sourceTopic;
  final Map<String, Map<String, dynamic>> placeholders;
  final List<String> icuVariables;
  final List<String> icuRoles;
  final List<String> icuBranches;
  final String? uiRole;
  final String? screenContext;
  final List<String> neighboringTerms;
  final Map<String, String> glossary;

  const TranslationResource({
    required this.id,
    required this.sourceText,
    required this.sourceTopic,
    this.description,
    this.placeholders = const {},
    this.icuVariables = const [],
    this.icuRoles = const [],
    this.icuBranches = const [],
    this.uiRole,
    this.screenContext,
    this.neighboringTerms = const [],
    this.glossary = const {},
  });

  factory TranslationResource.fromArbResource(
    ArbResource resource, {
    required String sourceTopic,
    String? uiRole,
    String? screenContext,
    List<String> neighboringTerms = const [],
    Map<String, String> glossary = const {},
  }) {
    final text = resource.text;
    final icuMatches = RegExp(
      r'\{\s*([A-Za-z_]\w*)\s*,\s*(plural|select)\s*,',
    ).allMatches(text).toList(growable: false);
    final variables = icuMatches.map((match) => match.group(1)!).toList(growable: false);
    final roles = icuMatches.map((match) => match.group(2)!).toList(growable: false);
    final branches = RegExp(r'(?:=\d+|zero|one|two|few|many|other|[A-Za-z_]\w*)\s*\{')
        .allMatches(text)
        .map(
          (match) => match.group(0)!.replaceFirst(RegExp(r'\s*\{$'), '').trim(),
        )
        .toList(growable: false);
    return TranslationResource(
      id: resource.id,
      sourceText: text,
      description: resource.attributes?.description,
      sourceTopic: sourceTopic,
      placeholders: resource.attributes?.placeholders ?? const {},
      icuVariables: variables,
      icuRoles: roles,
      icuBranches: branches,
      uiRole: uiRole,
      screenContext: screenContext,
      neighboringTerms: neighboringTerms,
      glossary: glossary,
    );
  }

  Map<String, dynamic> toJson({String? protectedSourceText}) => <String, dynamic>{
        'id': id,
        'source_text': sourceText,
        if (protectedSourceText != null) 'protected_source_text': protectedSourceText,
        if (description != null && description!.isNotEmpty) 'description': description,
        'source_topic': sourceTopic,
        if (placeholders.isNotEmpty) 'placeholders': placeholders,
        if (icuVariables.isNotEmpty) 'icu_variables': icuVariables,
        if (icuRoles.isNotEmpty) 'icu_roles': icuRoles,
        if (icuBranches.isNotEmpty) 'icu_branches': icuBranches,
        if (uiRole != null && uiRole!.isNotEmpty) 'ui_role': uiRole,
        if (screenContext != null && screenContext!.isNotEmpty) 'screen_context': screenContext,
        if (neighboringTerms.isNotEmpty) 'neighboring_terms': neighboringTerms,
        if (glossary.isNotEmpty) 'glossary': glossary,
      };
}

/// A keyed result returned by a structured translation provider.
class TranslationResult {
  final String id;
  final String translation;

  const TranslationResult({required this.id, required this.translation});

  factory TranslationResult.fromJson(Map<String, dynamic> json) => TranslationResult(
        id: json['id'] as String,
        translation: json['translation'] as String? ?? json['text'] as String,
      );
}

/// Canonical, deterministic fingerprints for reviewed overlays and cache data.
class TranslationFingerprint {
  static const algorithmVersion = 'structured-resource-v1';

  static String source(TranslationResource resource) => _hash(<String, dynamic>{
        'algorithm': algorithmVersion,
        'id': resource.id,
        'source': resource.sourceText,
        'description': resource.description,
        'placeholders': _canonical(resource.placeholders),
        'icu_variables': resource.icuVariables,
        'icu_roles': resource.icuRoles,
        'icu_branches': resource.icuBranches,
      });

  /// Review validity intentionally excludes the translation provider/model.
  /// A Codex-reviewed value remains authoritative when a user switches engines.
  static String reviewContext(
    TranslationResource resource, {
    String? translationContext,
    String promptVersion = 'review-context-v1',
    String glossaryVersion = '',
  }) =>
      _hash(<String, dynamic>{
        'algorithm': algorithmVersion,
        'topic': resource.sourceTopic,
        'ui_role': resource.uiRole,
        'screen_context': resource.screenContext,
        'neighbors': resource.neighboringTerms,
        'glossary': _canonical(resource.glossary),
        'translation_context': translationContext ?? '',
        'prompt_version': promptVersion,
        'glossary_version': glossaryVersion,
      });

  /// Cache validity includes every provider-specific input that can affect an
  /// automatically generated target value.
  static String cacheContext(
    TranslationResource resource, {
    String? translationContext,
    String provider = '',
    String endpointClass = '',
    String model = '',
    String promptVersion = 'structured-resource-v1',
    String glossaryVersion = '',
  }) =>
      _hash(<String, dynamic>{
        'review_context': reviewContext(
          resource,
          translationContext: translationContext,
          glossaryVersion: glossaryVersion,
        ),
        'provider': provider,
        'endpoint_class': endpointClass,
        'model': model,
        'prompt_version': promptVersion,
      });

  /// Backwards-compatible name for cache context fingerprints.
  static String context(
    TranslationResource resource, {
    String? translationContext,
    String provider = '',
    String model = '',
    String promptVersion = 'structured-resource-v1',
    String glossaryVersion = '',
  }) =>
      cacheContext(
        resource,
        translationContext: translationContext,
        provider: provider,
        model: model,
        promptVersion: promptVersion,
        glossaryVersion: glossaryVersion,
      );

  static String _hash(Map<String, dynamic> value) {
    // SHA is intentionally avoided here to keep this package dependency-free;
    // this stable digest is an invalidation fingerprint, not a security token.
    final input = jsonEncode(_canonical(value));
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static dynamic _canonical(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, dynamic>{
        for (final key in keys) key: _canonical(value[key]),
      };
    }
    if (value is Iterable) return value.map(_canonical).toList(growable: false);
    return value;
  }
}
