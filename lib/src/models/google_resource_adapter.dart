import 'translation_resource.dart';

/// Lossless projection of a structured resource for Google Translation APIs.
///
/// Basic and NMT accept only a `q` text field, so descriptions, keys, and
/// prompts must not be embedded in the translatable value. Google LLM labels
/// provide an opaque diagnostic identity without changing translated output.
class GoogleResourceAdapter {
  final TranslationResource resource;

  const GoogleResourceAdapter(this.resource);

  String get flattenedText => resource.sourceText;

  String get identity => '${resource.sourceTopic}#${resource.id}';

  Map<String, String> get llmLabels => {
        'smart_arb_resource': _labelValue(identity),
      };

  /// Values with ARB interpolation/ICU syntax keep the established action
  /// projection, because Google does not promise structured ARB preservation.
  bool get supportsWholeResourceLlm =>
      resource.placeholders.isEmpty && resource.icuRoles.isEmpty && !RegExp(r'\{[^}]+\}').hasMatch(resource.sourceText);

  static String _labelValue(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '-');
    final trimmed = normalized.replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    final candidate = trimmed.isEmpty ? 'resource' : trimmed;
    return candidate.length <= 63 ? candidate : candidate.substring(0, 63);
  }
}
