import 'package:petitparser/petitparser.dart';
import 'package:smart_arb_translator/src/icu_parser.dart';

import 'arb_attributes.dart';

/// Enumeration of supported ARB resource types.
///
/// Currently only text resources are supported, but this enum allows for
/// future expansion to support other resource types like images or audio.
enum ArbResourceType {
  /// Text-based localization resource
  text
}

/// Represents a single localization resource within an ARB (Application Resource Bundle) file.
///
/// An ARB resource consists of a unique identifier, the localizable text content,
/// and optional attributes that provide metadata about the resource such as
/// descriptions, placeholders, and manual translation overrides.
///
/// Example ARB resource in JSON:
/// ```json
/// {
///   "welcome_message": "Welcome, {name}!",
///   "@welcome_message": {
///     "description": "Welcome message shown to users",
///     "placeholders": {
///       "name": {
///         "type": "String",
///         "description": "User's display name"
///       }
///     }
///   }
/// }
/// ```
class ArbResource {
  /// The unique identifier for this resource within the ARB file.
  ///
  /// This serves as the key in the ARB JSON structure and is used to
  /// reference the resource in application code.
  final String id;

  /// The attribute identifier for this resource (prefixed with '@').
  ///
  /// This is automatically generated as '@{id}' and is used to store
  /// metadata about the resource in the ARB file structure.
  final String attributeId;

  /// The localizable text content of this resource.
  ///
  /// This text may contain ICU message format placeholders like {name}
  /// or other formatting directives that will be processed during localization.
  final String text;

  /// Optional metadata attributes for this resource.
  ///
  /// Attributes can include descriptions, placeholder definitions,
  /// manual translation overrides, and other metadata.
  final ArbAttributes? attributes;

  /// Parses the text content into ICU message format tokens.
  ///
  /// This getter analyzes the text and returns a list of tokens that represent
  /// the structure of the ICU message, including literal text and placeholders.
  List<Token> get tokens => IcuParser().parse(text);

  /// Private constructor for creating ARB resources.
  ///
  /// Use the factory constructors [ArbResource.fromEntries] to create instances.
  const ArbResource._({
    required this.id,
    required this.text,
    required this.attributes,
  }) : attributeId = '@$id';

  /// Creates an ARB resource from JSON map entries.
  ///
  /// This factory constructor takes the text entry (key-value pair) and
  /// optional attributes entry from an ARB file and creates a structured
  /// [ArbResource] instance.
  ///
  /// Parameters:
  /// - [textEntry]: The main resource entry containing the ID and text
  /// - [attributesEntry]: Optional entry containing resource metadata
  ///
  /// Returns a new [ArbResource] instance.
  ///
  /// Example:
  /// ```dart
  /// final resource = ArbResource.fromEntries(
  ///   textEntry: MapEntry('hello', 'Hello, World!'),
  ///   attributesEntry: MapEntry('@hello', {'description': 'Greeting message'}),
  /// );
  /// ```
  factory ArbResource.fromEntries({
    required MapEntry<String, String> textEntry,
    required MapEntry<String, dynamic>? attributesEntry,
  }) {
    return ArbResource._(
      id: textEntry.key,
      text: textEntry.value,
      attributes: attributesEntry?.value != null
          ? ArbAttributes.fromJson(
              attributesEntry!.value as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Converts this ARB resource to a JSON-serializable map.
  ///
  /// The returned map contains the resource ID as key and text as value,
  /// plus an optional attributes entry if attributes are present.
  ///
  /// Returns a map suitable for JSON serialization.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{id: text, if (attributes != null) attributeId: attributes!.toJson()};
  }

  /// Creates a copy of this ARB resource with optionally modified properties.
  ///
  /// This method allows creating a new [ArbResource] instance with some
  /// properties changed while keeping others unchanged.
  ///
  /// Parameters:
  /// - [id]: New resource ID (optional)
  /// - [text]: New text content (optional)
  /// - [attributes]: New attributes (optional)
  ///
  /// Returns a new [ArbResource] instance with the specified changes.
  ArbResource copyWith({
    String? id,
    String? text,
    ArbAttributes? attributes,
  }) {
    return ArbResource._(
      id: id ?? this.id,
      text: text ?? this.text,
      attributes: attributes ?? this.attributes,
    );
  }
}
