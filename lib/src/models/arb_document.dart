import 'dart:convert';

import 'package:collection/collection.dart';

import 'arb_resource.dart';

/// Represents a complete ARB (Application Resource Bundle) document.
///
/// An ARB document is a JSON-based localization file format that contains
/// translatable text resources along with their metadata. This class provides
/// a structured representation of an ARB file with methods for parsing,
/// serialization, and manipulation.
///
/// ARB documents can contain:
/// - Locale information (@@locale)
/// - Last modified timestamp (@@last_modified)
/// - Application name (appName)
/// - Localization resources with their attributes
///
/// Example ARB structure:
/// ```json
/// {
///   "@@locale": "en",
///   "@@last_modified": "2023-01-01T00:00:00.000Z",
///   "appName": "My App",
///   "hello": "Hello, World!",
///   "@hello": {
///     "description": "Greeting message"
///   }
/// }
/// ```
class ArbDocument {
  /// The locale identifier for this ARB document (optional).
  ///
  /// This corresponds to the "@@locale" global attribute and defines
  /// the language/region for the translated strings in this document.
  ///
  /// Example values: "en", "es", "fr-CA", "zh-Hans"
  final String? locale;

  /// The application name (optional).
  ///
  /// This is a minimal key-value pair that can be used to identify
  /// the application or provide a display name for the app.
  final String? appName;

  /// Timestamp indicating when this ARB document was last modified.
  ///
  /// This corresponds to the "@@last_modified" global attribute and
  /// helps track changes and synchronization between different versions.
  final DateTime? lastModified;

  /// Map of all localization resources in this document.
  ///
  /// The keys are resource identifiers (e.g., "hello", "welcome_message")
  /// and the values are [ArbResource] objects containing the text and metadata.
  final Map<String, ArbResource> resources;

  /// Private constructor for creating ARB documents.
  ///
  /// Use the factory constructors [ArbDocument.empty], [ArbDocument.fromJson],
  /// or [ArbDocument.decode] to create instances.
  const ArbDocument._({
    required this.locale,
    required this.appName,
    required this.lastModified,
    required this.resources,
  });

  /// Creates an empty ARB document with optional initial values.
  ///
  /// This factory constructor creates a new ARB document with the specified
  /// metadata and an empty or provided resource map.
  ///
  /// Parameters:
  /// - [locale]: Locale identifier for the document
  /// - [appName]: Application name (optional)
  /// - [lastModified]: Last modification timestamp (optional)
  /// - [resources]: Initial resources map (defaults to empty)
  ///
  /// Returns a new [ArbDocument] instance.
  ///
  /// Example:
  /// ```dart
  /// final document = ArbDocument.empty(
  ///   locale: 'en',
  ///   appName: 'My App',
  ///   lastModified: DateTime.now(),
  /// );
  /// ```
  factory ArbDocument.empty({
    required String? locale,
    String? appName,
    DateTime? lastModified,
    Map<String, ArbResource>? resources,
  }) {
    return ArbDocument._(
      locale: locale,
      appName: appName,
      lastModified: lastModified,
      resources: resources ?? <String, ArbResource>{},
    );
  }

  /// Converts this ARB document to a JSON-serializable map.
  ///
  /// The returned map follows the ARB file format specification with
  /// global attributes (prefixed with @@) and resource entries.
  ///
  /// Returns a map suitable for JSON serialization.
  Map<String, dynamic> toJson() {
    final resourceMap = resources.values.fold<Map<String, dynamic>>(
      <String, dynamic>{},
      (previousValue, resource) {
        return <String, dynamic>{...previousValue, ...resource.toJson()};
      },
    );

    return <String, dynamic>{
      if (locale != null) '@@locale': locale,
      if (lastModified != null) '@@last_modified': lastModified!.toIso8601String(),
      if (appName != null) 'appName': appName,
      ...resourceMap,
    };
  }

  /// Creates an ARB document from a JSON map.
  ///
  /// This factory constructor parses ARB content from a JSON map and creates
  /// a structured [ArbDocument] instance with all resources and metadata.
  ///
  /// Parameters:
  /// - [json]: Map containing the ARB file content
  /// - [includeTimestampIfNull]: Whether to set lastModified to current time if not present
  ///
  /// Returns a new [ArbDocument] instance with parsed content.
  ///
  /// Example:
  /// ```dart
  /// final document = ArbDocument.fromJson({
  ///   '@@locale': 'en',
  ///   'hello': 'Hello, World!',
  ///   '@hello': {'description': 'Greeting'}
  /// }, includeTimestampIfNull: true);
  /// ```
  factory ArbDocument.fromJson(
    Map<String, dynamic> json, {
    required bool includeTimestampIfNull,
  }) {
    final locale = json.remove('@@locale') as String?;
    final appName = json.remove('appName') as String?;
    final lastModified = json.remove('@@last_modified') as String?;

    var dateModified = includeTimestampIfNull ? DateTime.now() : null;

    if (lastModified != null) {
      dateModified = DateTime.parse(lastModified);
    }

    final resourceEntries =
        json.entries.where((entry) => !entry.key.startsWith('@')).map<MapEntry<String, ArbResource>>((entry) {
      final attributesEntry = (json.entries.firstWhereOrNull(
        (attributeEntry) => attributeEntry.key == '@${entry.key}',
      ));

      return MapEntry(
        entry.key,
        ArbResource.fromEntries(
          textEntry: MapEntry(entry.key, entry.value as String),
          attributesEntry: attributesEntry,
        ),
      );
    });

    return ArbDocument.empty(
      locale: locale,
      appName: appName,
      lastModified: dateModified,
      resources: Map<String, ArbResource>.fromEntries(resourceEntries),
    );
  }

  /// Encodes this ARB document as a formatted JSON string.
  ///
  /// This method converts the document to JSON and formats it with the
  /// specified indentation for human readability.
  ///
  /// Parameters:
  /// - [indent]: String to use for indentation (defaults to two spaces)
  ///
  /// Returns a formatted JSON string representation of the ARB document.
  ///
  /// Example:
  /// ```dart
  /// final jsonString = document.encode(indent: '  ');
  /// print(jsonString); // Pretty-printed ARB content
  /// ```
  String encode({String indent = '  '}) {
    final encoder = JsonEncoder.withIndent(indent);
    final arbContent = encoder.convert(toJson());

    return arbContent;
  }

  /// Creates an ARB document by parsing a JSON string.
  ///
  /// This factory constructor decodes ARB content from a JSON string and
  /// creates a structured [ArbDocument] instance.
  ///
  /// Parameters:
  /// - [jsonString]: JSON string containing ARB file content
  /// - [locale]: Override locale (optional)
  /// - [includeTimestampIfNull]: Whether to set lastModified to current time if not present
  ///
  /// Returns a new [ArbDocument] instance with parsed content.
  ///
  /// Example:
  /// ```dart
  /// final jsonContent = '{"@@locale": "en", "hello": "Hello!"}';
  /// final document = ArbDocument.decode(jsonContent);
  /// ```
  factory ArbDocument.decode(
    String jsonString, {
    String? locale,
    bool includeTimestampIfNull = false,
  }) {
    final arbContent = ArbDocument.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
      includeTimestampIfNull: includeTimestampIfNull,
    );

    return arbContent;
  }

  /// Creates a copy of this ARB document with optionally modified properties.
  ///
  /// This method allows creating a new [ArbDocument] instance with some
  /// properties changed while keeping others unchanged.
  ///
  /// Parameters:
  /// - [locale]: New locale identifier (optional)
  /// - [appName]: New application name (optional)
  /// - [lastModified]: New last modified timestamp (optional)
  /// - [resources]: New resources map (optional)
  ///
  /// Returns a new [ArbDocument] instance with the specified changes.
  ///
  /// Example:
  /// ```dart
  /// final updatedDocument = document.copyWith(
  ///   locale: 'es',
  ///   lastModified: DateTime.now(),
  /// );
  /// ```
  ArbDocument copyWith({
    String? locale,
    String? appName,
    DateTime? lastModified,
    Map<String, ArbResource>? resources,
  }) {
    return ArbDocument._(
      appName: appName ?? this.appName,
      lastModified: lastModified ?? this.lastModified,
      locale: locale ?? this.locale,
      resources: resources ?? {...this.resources},
    );
  }
}
