/// Utility functions for the Smart ARB Translator package.
///
/// This file contains helper functions for enum handling, HTML processing,
/// and text manipulation used throughout the translation workflow.

/// Returns the string representation of an enum value.
///
/// This function extracts the enum value name from its string representation
/// by removing the enum type prefix. It's useful for serialization and
/// debugging purposes.
///
/// Parameters:
/// - [enumEntry]: The enum value to convert to string
///
/// Returns the enum value name as a string.
///
/// Example:
/// ```dart
/// enum Color { red, green, blue }
/// print(describeEnum(Color.red)); // Output: 'red'
/// ```
///
/// Throws [AssertionError] if the provided object is not an enum.
String describeEnum(Object enumEntry) {
  final description = enumEntry.toString();
  final indexOfDot = description.indexOf('.');
  assert(
    indexOfDot != -1 && indexOfDot < description.length - 1,
    'The provided object "$enumEntry" is not an enum.',
  );
  return description.substring(indexOfDot + 1);
}

/// Finds an enum value by its string representation.
///
/// This function searches through a list of enum values to find the one
/// that matches the provided string value. It's commonly used for
/// deserializing enum values from JSON or configuration files.
///
/// Parameters:
/// - [values]: List of all possible enum values to search through
/// - [value]: String representation of the enum value to find
///
/// Returns the matching enum value.
///
/// Example:
/// ```dart
/// enum Color { red, green, blue }
/// final color = enumFromString(Color.values, 'red');
/// print(color); // Output: Color.red
/// ```
///
/// Throws [StateError] if no matching enum value is found.
T enumFromString<T>(List<T> values, String value) {
  return values.firstWhere((v) => v.toString().split('.')[1] == value);
}

const _noTranslateOpen = '<span class="notranslate">';
const _noTranslateClose = '</span>';

/// Removes HTML markup from translated text and restores ICU placeholders.
///
/// This function processes text that has been through HTML encoding for
/// translation protection, removing the HTML wrapper and converting
/// no-translate spans back to ICU message format placeholders.
///
/// The function:
/// 1. Removes non-unicode characters that may be introduced during translation
/// 2. Normalizes whitespace by removing double spaces
/// 3. Removes the outer HTML span wrapper
/// 4. Converts no-translate spans back to curly brace placeholders
///
/// Parameters:
/// - [value]: HTML-encoded text to clean up
///
/// Returns cleaned text with ICU placeholders restored.
///
/// Example:
/// ```dart
/// final htmlText = '<span>Hello <span class="notranslate">name</span>!</span>';
/// final cleaned = removeHtml(htmlText);
/// print(cleaned); // Output: 'Hello {name}!'
/// ```
String removeHtml(String value) {
  return value
      // This might help in removing weird non-unicode chars
      .replaceAll(RegExp(r'~\p{Cf}+~u'), ' ')
      // Remove double spaces
      .replaceAll('  ', ' ')
      .substring('<span>'.length, value.length - '</span>'.length)
      .replaceAll(_noTranslateOpen, '{')
      .replaceAll(_noTranslateClose, '}');
}

/// Converts text with ICU placeholders to HTML format for translation protection.
///
/// This function wraps text in HTML spans and converts ICU message format
/// placeholders (curly braces) to no-translate spans. This protects the
/// placeholders from being translated by the translation service while
/// allowing the surrounding text to be translated normally.
///
/// Parameters:
/// - [value]: Text containing ICU placeholders to protect
///
/// Returns HTML-encoded text with protected placeholders.
///
/// Example:
/// ```dart
/// final text = 'Hello {name}!';
/// final htmlText = toHtml(text);
/// print(htmlText); // Output: '<span>Hello <span class="notranslate">name</span>!</span>'
/// ```
String toHtml(String value) {
  final innerText = value.replaceAll('{', _noTranslateOpen).replaceAll('}', _noTranslateClose);

  return '<span>$innerText</span>';
}
