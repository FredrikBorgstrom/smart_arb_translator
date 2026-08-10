import 'dart:convert';

import 'package:http/http.dart' as http;

import 'localization_validator.dart';
import 'models/arb_document.dart';
import 'models/arb_resource.dart';
import 'models/local_llm_options.dart';
import 'models/translation_resource.dart';
import 'translation_service.dart';

/// Parses and runs the source-controlled local-model benchmark corpus.
///
/// The accepted generic superset is:
/// ```json
/// {"schema_version":1,"locales":["fr"],"resources":[
///   {"id":"back","source":"Back","source_topic":"ui.arb",
///    "description":"...","placeholders":{},"icu_roles":[],
///    "icu_branches":[],"ui_role":"...","screen_context":"...",
///    "neighboring_terms":[],"glossary":{},"locales":["fr"]}
/// ]}
/// ```
/// ABCx3's exact aliases are also accepted: `schemaVersion`, `targetLocales`,
/// and `cases`, where a case uses `key`, `feature`, and `targetLocales`.
/// `source_text` is accepted as an alias for `source`; a resource's `locales`
/// narrows the top-level set. Unknown fields are retained out of provider input.
class LocalModelBenchmarkCorpus {
  final int schemaVersion;
  final List<String> locales;
  final List<BenchmarkCorpusResource> resources;

  const LocalModelBenchmarkCorpus({
    required this.schemaVersion,
    required this.locales,
    required this.resources,
  });

  factory LocalModelBenchmarkCorpus.decode(String input) {
    final json = jsonDecode(input);
    if (json is! Map<String, dynamic>) throw const FormatException('Benchmark corpus must be a JSON object.');
    final rawResources = json['resources'] ?? json['cases'];
    if (rawResources is! List) throw const FormatException('Benchmark corpus requires resources or ABCx3 cases array.');
    final locales = _strings(json['locales'] ?? json['targetLocales'], field: 'locales/targetLocales');
    if (locales.isEmpty) throw const FormatException('Benchmark corpus requires at least one locale.');
    final resources = rawResources.map((value) => BenchmarkCorpusResource.fromJson(value)).toList(growable: false);
    return LocalModelBenchmarkCorpus(
      schemaVersion: json['schema_version'] is int
          ? json['schema_version'] as int
          : (json['schemaVersion'] is int ? json['schemaVersion'] as int : 1),
      locales: locales,
      resources: resources,
    );
  }
}

class BenchmarkCorpusResource {
  final TranslationResource resource;
  final List<String>? locales;
  final String? caseId;

  const BenchmarkCorpusResource(this.resource, this.locales, {this.caseId});

  factory BenchmarkCorpusResource.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) throw const FormatException('Each benchmark resource must be an object.');
    final id = _required(value, value.containsKey('key') ? 'key' : 'id');
    final source = _required(value, value.containsKey('source_text') ? 'source_text' : 'source');
    final description = _optional(value['description']);
    final sourceTopic = _optional(value['source_topic']) ?? _optional(value['feature']) ?? 'benchmark.arb';
    final placeholders = _stringDynamicMap(value['placeholders']);
    final parsed = TranslationResource.fromArbResource(
      ArbResource.fromEntries(
        textEntry: MapEntry(id, source),
        attributesEntry: MapEntry('@$id', <String, dynamic>{
          if (description != null) 'description': description,
          if (placeholders.isNotEmpty) 'placeholders': placeholders,
        }),
      ),
      sourceTopic: sourceTopic,
      uiRole: _optional(value['ui_role']),
      screenContext: _optional(value['screen_context']),
      neighboringTerms: _strings(value['neighboring_terms']),
      glossary: _stringMap(value['glossary']),
    );
    return BenchmarkCorpusResource(
      TranslationResource(
        id: id,
        sourceText: source,
        sourceTopic: sourceTopic,
        description: description,
        placeholders: placeholders,
        icuVariables: _strings(value['icu_variables']).isEmpty ? parsed.icuVariables : _strings(value['icu_variables']),
        icuRoles: _strings(value['icu_roles']).isEmpty ? parsed.icuRoles : _strings(value['icu_roles']),
        icuBranches: _strings(value['icu_branches']).isEmpty ? parsed.icuBranches : _strings(value['icu_branches']),
        uiRole: parsed.uiRole,
        screenContext: parsed.screenContext,
        neighboringTerms: parsed.neighboringTerms,
        glossary: parsed.glossary,
      ),
      value.containsKey('locales') || value.containsKey('targetLocales')
          ? _strings(value['locales'] ?? value['targetLocales'], field: 'resource locales')
          : null,
      caseId: _optional(value['id']),
    );
  }
}

typedef BenchmarkTranslate = Future<List<TranslationResult>> Function({
  required List<TranslationResource> resources,
  required Map<String, dynamic> parameters,
  required LocalLlmOptions localLlmOptions,
  http.Client? client,
});

/// Runs exactly one local model request at a time. It never selects a provider
/// other than `local_llm`, starts a runtime, downloads a model, or falls back.
class LocalModelBenchmarkRunner {
  static Future<Map<String, dynamic>> run({
    required LocalModelBenchmarkCorpus corpus,
    required LocalLlmOptions options,
    Iterable<String>? selectedLocales,
    http.Client? client,
    BenchmarkTranslate? translate,
  }) async {
    final localeSet = selectedLocales == null ? corpus.locales.toSet() : selectedLocales.toSet();
    final locales = corpus.locales.where(localeSet.contains).toList(growable: false);
    if (locales.isEmpty) throw ArgumentError('None of the requested locales are in the benchmark corpus.');
    final call = translate ?? _translate;
    final records = <Map<String, dynamic>>[];
    final batches = <Map<String, dynamic>>[];

    for (final locale in locales) {
      final entries = corpus.resources
          .where((entry) => entry.locales == null || entry.locales!.contains(locale))
          .toList(growable: false);
      if (entries.isEmpty) continue;
      final stopwatch = Stopwatch()..start();
      Map<String, String>? translations;
      Object? error;
      try {
        final result = await call(
          resources: entries.map((entry) => entry.resource).toList(growable: false),
          parameters: {'target': locale},
          localLlmOptions: options,
          client: client,
        );
        if (result.length != entries.length) {
          throw FormatException('Local benchmark returned ${result.length} values for ${entries.length} resources.');
        }
        translations = {for (final value in result) value.id: value.translation};
        if (translations.length != entries.length ||
            entries.any((entry) => !translations!.containsKey(entry.resource.id))) {
          throw FormatException('Local benchmark response did not preserve every resource id.');
        }
      } catch (exception) {
        error = exception;
      } finally {
        stopwatch.stop();
      }
      final batchElapsed = stopwatch.elapsedMilliseconds;
      batches.add(<String, dynamic>{
        'locale': locale,
        'resource_count': entries.length,
        'elapsed_ms': batchElapsed,
        'request_mode': options.profile == LocalLlmProfile.translategemma
            ? 'translation_only_one_resource_internal'
            : 'keyed_batch',
        if (error != null) 'error': error.toString(),
      });
      for (final entry in entries) {
        final translation = translations?[entry.resource.id];
        records.add(<String, dynamic>{
          'locale': locale,
          'id': entry.resource.id,
          if (entry.caseId != null) 'case_id': entry.caseId,
          'source_topic': entry.resource.sourceTopic,
          'english': entry.resource.sourceText,
          if (translation != null) 'translation': translation,
          'batch_elapsed_ms': batchElapsed,
          'validation': translation == null ? const [] : _validation(entry.resource, translation, locale),
          if (error != null) 'error': error.toString(),
        });
      }
    }
    return <String, dynamic>{
      'schema_version': 1,
      'benchmark_corpus_schema_version': corpus.schemaVersion,
      'provenance': <String, dynamic>{
        'translation_service': 'local_llm',
        'model': options.model,
        'profile': options.profile.name == 'openaiChatJson' ? 'openai_chat_json' : 'translategemma',
        'endpoint_class': '${options.endpoint.scheme}://${options.endpoint.host}',
        'parallel_translations': 1,
        'fallback': 'none',
      },
      'batches': batches,
      'results': records,
    };
  }

  static Future<List<TranslationResult>> _translate({
    required List<TranslationResource> resources,
    required Map<String, dynamic> parameters,
    required LocalLlmOptions localLlmOptions,
    http.Client? client,
  }) =>
      TranslationService.translateResources(
        resources: resources,
        parameters: parameters,
        translationService: 'local_llm',
        localLlmOptions: localLlmOptions,
        client: client,
        allowPerItemFallback: false,
      );

  static List<Map<String, dynamic>> _validation(TranslationResource source, String translated, String locale) {
    final sourceArb = ArbDocument.empty(
      locale: 'en',
      resources: {
        source.id: _arbResource(
          source.id,
          source.sourceText,
          placeholders: source.placeholders,
        ),
      },
    );
    final targetArb = ArbDocument.empty(
      locale: locale,
      resources: {
        source.id: _arbResource(
          source.id,
          translated,
          placeholders: source.placeholders,
        ),
      },
    );
    return LocalizationValidator.validatePair(source: sourceArb, target: targetArb, targetLocale: locale)
        .map((issue) => <String, dynamic>{'code': issue.code, 'key': issue.key, 'message': issue.message})
        .toList(growable: false);
  }

  static ArbResource _arbResource(
    String id,
    String text, {
    Map<String, Map<String, dynamic>> placeholders = const {},
  }) =>
      ArbResource.fromEntries(
        textEntry: MapEntry(id, text),
        attributesEntry:
            placeholders.isEmpty ? null : MapEntry('@$id', <String, dynamic>{'placeholders': placeholders}),
      );
}

String _required(Map<String, dynamic> value, String field) {
  final string = value[field];
  if (string is! String || string.trim().isEmpty) {
    throw FormatException('Benchmark resource requires non-empty $field.');
  }
  return string;
}

String? _optional(dynamic value) => value is String && value.trim().isNotEmpty ? value.trim() : null;

List<String> _strings(dynamic value, {String field = 'list'}) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be an array of strings.');
  }
  return value.cast<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false);
}

Map<String, String> _stringMap(dynamic value) {
  if (value == null) return const {};
  if (value is! Map || value.entries.any((entry) => entry.key is! String || entry.value is! String)) {
    throw const FormatException('glossary must be an object of string values.');
  }
  return Map<String, String>.from(value);
}

Map<String, Map<String, dynamic>> _stringDynamicMap(dynamic value) {
  if (value == null) return const {};
  if (value is! Map || value.entries.any((entry) => entry.key is! String || entry.value is! Map)) {
    throw const FormatException('placeholders must be an object of objects.');
  }
  return <String, Map<String, dynamic>>{
    for (final entry in value.entries) entry.key as String: Map<String, dynamic>.from(entry.value as Map),
  };
}
