import '../utils.dart';

/// Enumeration of resource types supported in ARB attributes.
///
/// This enum defines the possible values for the 'type' attribute
/// in ARB resource metadata.
enum ResourceType {
  /// Standard text resource type
  type
}

/// Represents metadata attributes for an ARB (Application Resource Bundle) resource.
///
/// ARB attributes provide additional information about localization resources,
/// including human-readable descriptions, placeholder definitions for ICU message
/// format variables, manual translation overrides, and resource type information.
///
/// These attributes are stored in the ARB file using keys prefixed with '@'
/// followed by the resource identifier.
///
/// Example attributes in ARB JSON:
/// ```json
/// {
///   "@welcome_message": {
///     "description": "Welcome message shown to new users",
///     "placeholders": {
///       "name": {
///         "type": "String",
///         "description": "User's display name"
///       }
///     },
///     "x-translations": {
///       "es": "¡Bienvenido, {name}!"
///     }
///   }
/// }
/// ```
class ArbAttributes {
  /// Human-readable description of the resource's purpose or context.
  ///
  /// This description helps translators understand the context and intended
  /// use of the text, leading to more accurate translations.
  final String? description;

  /// The type of resource (currently only 'type' is supported).
  ///
  /// This field can be used to specify special handling requirements
  /// for different types of localization content.
  final ResourceType? resourceType;

  /// Definitions for ICU message format placeholders used in the resource text.
  ///
  /// Each placeholder is defined with its name as the key and a map containing
  /// type information and description. This helps translators understand what
  /// values will be substituted and how to handle them in different languages.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   "count": {
  ///     "type": "int",
  ///     "description": "Number of items"
  ///   }
  /// }
  /// ```
  final Map<String, Map<String, dynamic>>? placeholders;

  /// Manual translation overrides for specific language codes.
  ///
  /// This map allows specifying manual translations that should be used instead
  /// of automatic translations from the translation service. The keys are
  /// language codes (e.g., 'es', 'fr') and values are the manual translations.
  ///
  /// Example:
  /// ```dart
  /// {
  ///   "es": "¡Hola, mundo!",
  ///   "fr": "Bonjour, le monde!"
  /// }
  /// ```
  final Map<String, dynamic>? xTranslations;

  /// Creates ARB attributes with the specified metadata.
  ///
  /// Parameters:
  /// - [description]: Human-readable description of the resource
  /// - [placeholders]: Placeholder definitions for ICU message format variables
  /// - [xTranslations]: Manual translation overrides by language code
  /// - [resourceType]: Type classification for the resource
  const ArbAttributes({
    required this.description,
    required this.placeholders,
    required this.xTranslations,
    required this.resourceType,
  });

  /// Returns true if all attribute fields are null (no metadata present).
  ///
  /// This is useful for determining whether attributes need to be serialized
  /// or can be omitted from the ARB file output.
  bool get isEmpty => description == null && placeholders == null;

  /// Returns true if any attribute field contains data.
  ///
  /// This is the inverse of [isEmpty] and indicates that the attributes
  /// contain meaningful metadata that should be preserved.
  bool get isNotEmpty => !isEmpty;

  /// Creates ARB attributes from a JSON map.
  ///
  /// This factory constructor parses attribute data from the JSON structure
  /// found in ARB files and creates a structured [ArbAttributes] instance.
  ///
  /// Parameters:
  /// - [json]: Map containing the attribute data from ARB file
  ///
  /// Returns a new [ArbAttributes] instance with parsed data.
  ///
  /// Example:
  /// ```dart
  /// final attributes = ArbAttributes.fromJson({
  ///   'description': 'Welcome message',
  ///   'placeholders': {
  ///     'name': {'type': 'String'}
  ///   }
  /// });
  /// ```
  factory ArbAttributes.fromJson(Map<String, dynamic> json) {
    final resourceType = json['type'] as String?;

    return ArbAttributes(
      description: json['description'] as String?,
      resourceType: resourceType == null ? null : enumFromString(ResourceType.values, resourceType),
      xTranslations: json['x-translations'] == null
          ? null
          : Map<String, dynamic>.from(json['x-translations'] as Map<String, dynamic>),
      placeholders: json['placeholders'] == null
          ? null
          : Map<String, Map<String, dynamic>>.from(
              json['placeholders'] as Map<String, dynamic>,
            ),
    );
  }

  /// Converts these attributes to a JSON-serializable map.
  ///
  /// Only non-null attributes are included in the output map.
  /// Note that x-translations are intentionally excluded from the output
  /// as they are used internally and should not appear in generated ARB files.
  ///
  /// Returns a map suitable for JSON serialization.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (description != null) 'description': description,
      if (placeholders != null) 'placeholders': placeholders,
    };
  }

  /* ArbAttributes copyWith({
    String? description,
    ResourceType? resourceType,
    Map<String, Map<String, dynamic>>? placeholders,
    Map<String, dynamic>? xTranslations,
  }) {
    final currentPlaceholders = this.placeholders;
    final currentXTranslations = this.xTranslations;

    return ArbAttributes(
      description: description ?? this.description,
      resourceType: resourceType ?? this.resourceType,
      placeholders: placeholders ?? (currentPlaceholders == null ? null : {...currentPlaceholders}),
      xTranslations: xTranslations ?? (currentXTranslations == null ? null : {...currentXTranslations}),
    );
  } */
}
