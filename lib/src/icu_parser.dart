// This file incorporates work covered by the following copyright and
// permission notice:
//
//     Copyright 2013, the Dart project authors. All rights reserved.
//     Redistribution and use in source and binary forms, with or without
//     modification, are permitted provided that the following conditions are
//     met:
//
//         * Redistributions of source code must retain the above copyright
//           notice, this list of conditions and the following disclaimer.
//         * Redistributions in binary form must reproduce the above
//           copyright notice, this list of conditions and the following
//           disclaimer in the documentation and/or other materials provided
//           with the distribution.
//         * Neither the name of Google Inc. nor the names of its
//           contributors may be used to endorse or promote products derived
//           from this software without specific prior written permission.
//
//     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//     A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//     OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//     SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//     LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//     DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//     THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import 'package:petitparser/petitparser.dart';

/// Parser for ICU (International Components for Unicode) message format.
///
/// This class provides parsing capabilities for ICU message format strings,
/// which are commonly used in internationalization (i18n) for handling
/// pluralization, gender selection, and other locale-specific formatting.
///
/// The parser can handle:
/// - Simple text messages
/// - Placeholder variables (e.g., {name})
/// - Plural forms (e.g., {count, plural, one {# item} other {# items}})
/// - Gender selection (e.g., {gender, select, male {he} female {she} other {they}})
/// - General selection statements
/// - Escaped characters and quotes
///
/// Example usage:
/// ```dart
/// final parser = IcuParser();
/// final tokens = parser.parse('Hello {name}, you have {count, plural, one {# message} other {# messages}}');
/// ```
///
/// Some getters have been commented out as they weren't necessary for our
/// purposes.
class IcuParser {
  /// Parser for opening curly brace '{'.
  Parser<String> get openCurly => char('{');

  /// Parser for closing curly brace '}'.
  Parser<String> get closeCurly => char('}');

  /// Parser for two single quotes "''" which represents a single quote in ICU format.
  Parser get twoSingleQuotes => string("''").map((x) => "'");

  /// Parser for quoted curly braces "'{'" or "'}" which are escaped in ICU format.
  Parser get quotedCurly => (string("'{'") | string("'}'")).map((x) => x[1]);

  /// Parser for ICU escaped text including quoted curly braces and double quotes.
  Parser get icuEscapedText => quotedCurly | twoSingleQuotes;

  /// Parser for any curly brace (opening or closing).
  Parser get curly => openCurly | closeCurly;

  /// Parser for HTML opening tag '<'.
  Parser get html => char('<');

  /// Parser for characters not allowed in ICU text (curly braces and HTML).
  Parser get notAllowedInIcuText => curly | html;

  /// Parser for valid ICU text characters (anything except curly braces and HTML).
  Parser get icuText => notAllowedInIcuText.neg();

  // Parser<String> get notAllowedInNormalText => char('{');

  // Parser<String> get normalText => notAllowedInNormalText.neg();

  /// Parser for message text that can contain escaped characters.
  Parser get messageText => (icuEscapedText | icuText).plus().flatten();

  /// Parser for text-only messages (no placeholders).
  Parser get justText => messageText.end();

  /// Parser for optional message text (can be empty).
  Parser get optionalMessageText => (icuEscapedText | icuText).star().flatten();

  /// Parser for text containing placeholders with curly braces.
  Parser get placeholderText =>
      (optionalMessageText & openCurly & messageText & closeCurly & optionalMessageText).plus().flatten();

  // Parser<String> get nonIcuMessageText => normalText.plus().flatten();

  // Parser<int> get number => digit().plus().flatten().trim().map<int>(int.parse);

  /// Parser for identifiers (variable names, keywords).
  Parser<String> get id => (letter() & (word() | char('_')).star()).flatten().trim();

  /// Parser for comma separator with optional whitespace.
  Parser<String> get comma => char(',').trim();

  /// Given a list of possible keywords, return a rule that accepts any of them.
  /// e.g., given ["male", "female", "other"], accept any of them.
  Parser<String> asKeywords(List<String> list) =>
      list.map(string).cast<Parser>().reduce((a, b) => a | b).flatten().trim();

  /// Parser for plural keywords like 'zero', 'one', 'two', 'few', 'many', 'other', '=0', '=1', etc.
  Parser<String> get pluralKeyword => asKeywords(
        ['=0', '=1', '=2', 'zero', 'one', 'two', 'few', 'many', 'other'],
      );

  /// Parser for gender keywords: 'female', 'male', 'other'.
  Parser<String> get genderKeyword => asKeywords(['female', 'male', 'other']);

  var interiorText = undefined();

  /// Parser for the preface of ICU constructs (variable name and comma).
  Parser<String> get preface => (openCurly & id & comma).map((values) => values[1]);

  /// Parser for the literal word 'plural'.
  Parser get pluralLiteral => string('plural');

  /// Parser for individual plural clauses (e.g., "one {# item}").
  Parser get pluralClause => (pluralKeyword & openCurly & interiorText & closeCurly).trim().pick(2);

  /// Parser for complete plural constructs.
  Parser get plural => preface & pluralLiteral & comma & pluralClause.plus() & closeCurly;

  /// Parser for the literal word 'select'.
  Parser<String> get selectLiteral => string('select');

  /// Parser for individual select clauses.
  Parser get selectClause => (id & openCurly & interiorText & closeCurly).trim().pick(2);

  /// Parser for general select constructs.
  Parser get generalSelect => preface & selectLiteral & comma & selectClause.plus() & closeCurly;

  /// Parser for gender-specific clauses.
  Parser get genderClause => (genderKeyword & openCurly & interiorText & closeCurly).trim().pick(2);

  /// Parser for gender selection constructs.
  Parser get gender => preface & selectLiteral & comma & genderClause.plus() & closeCurly;

  /// Parser for any type of ICU construct (plural, gender, or general select).
  Parser get pluralOrGenderOrSelect => plural | gender | generalSelect;

  /// Parser for the contents of ICU constructs.
  Parser get pluralOrGenderOrSelectContents => pluralOrGenderOrSelect.map((result) => result[3]);

  /// Parser for any valid content (ICU constructs, placeholders, or text).
  Parser get contents => pluralOrGenderOrSelect | placeholderText | messageText;

  /// Parser for empty content.
  Parser get empty => epsilon();

  // Parser get parameter => openCurly & id & closeCurly;

  /// Parses an ICU message format string into a list of tokens.
  ///
  /// This method analyzes the input message and breaks it down into
  /// translatable segments, preserving the structure of ICU format
  /// constructs like plurals and selects.
  ///
  /// Parameters:
  /// - [message]: The ICU message format string to parse
  ///
  /// Returns a list of [Token] objects representing the parsed segments.
  ///
  /// Throws [Exception] if parsing fails.
  ///
  /// Example:
  /// ```dart
  /// final parser = IcuParser();
  /// final tokens = parser.parse('Hello {name}!');
  /// // Returns tokens for 'Hello ', '{name}', and '!'
  /// ```
  // TODO: Tokens can be nested deeper and we'll need to get those too using
  // fold or something
  List<Token> parse(String message) {
    final parsed = (placeholderText.token() | justText.token() | pluralOrGenderOrSelectContents).parse(message);

    if (parsed.isFailure) {
      print('Failed to parse: $message');
      print(parsed.message);
      throw Exception('parsing failed');
    } else {
      final parsedValue = parsed.value;
      print('Parsed: $parsedValue');
      return parsedValue is List ? List<Token>.from(parsedValue) : [parsedValue as Token];
    }
  }

  /// Creates a new ICU parser instance.
  ///
  /// The constructor sets up the recursive parser structure needed
  /// to handle nested ICU constructs properly.
  IcuParser() {
    // There is a cycle here, so we need the explicit set to avoid infinite recursion.
    interiorText.set((contents | empty).token());
  }
}
