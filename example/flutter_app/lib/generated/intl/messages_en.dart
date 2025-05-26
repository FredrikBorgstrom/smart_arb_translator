// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'Sedan', 'cabriolet': 'Solid roof cabriolet', 'truck': '16 wheel truck', 'other': 'Other'})}";

  static String m1(language) => "Current language: ${language}";

  static String m2(timestamp) => "Generated at: ${timestamp}";

  static String m3(name) => "Hello, ${name}!";

  static String m4(count) =>
      "${Intl.plural(count, zero: 'No items', one: 'One item', other: '${count} items')}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Her birthday', male: 'His birthday', other: 'Their birthday')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: 'You have no new messages', one: 'You have 1 new message', other: 'You have ${count} new messages')}";

  static String m7(firstName) => "Welcome ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appName": MessageLookupByLibrary.simpleMessage("Demo app"),
    "appTitle": MessageLookupByLibrary.simpleMessage(
      "Smart ARB Translator Demo",
    ),
    "changeLanguage": MessageLookupByLibrary.simpleMessage("Change Language"),
    "commonVehicleType": m0,
    "currentLanguage": m1,
    "dartCodeGen": MessageLookupByLibrary.simpleMessage("Dart Code Generation"),
    "dartCodeGenDesc": MessageLookupByLibrary.simpleMessage(
      "Automatically generates type-safe Dart localization code",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Features"),
    "flutterIntegration": MessageLookupByLibrary.simpleMessage(
      "Flutter Integration",
    ),
    "flutterIntegrationDesc": MessageLookupByLibrary.simpleMessage(
      "Seamless integration with Flutter\'s internationalization workflow",
    ),
    "generatedAt": m2,
    "greetUser": m3,
    "itemCount": m4,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage("Your password"),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage("Your username"),
    "smartTranslation": MessageLookupByLibrary.simpleMessage(
      "Smart Translation",
    ),
    "smartTranslationDesc": MessageLookupByLibrary.simpleMessage(
      "Only translates new or changed content, saving API costs",
    ),
    "specialGreeting": MessageLookupByLibrary.simpleMessage(
      "Welcome to the future of Flutter i18n!",
    ),
    "subtitle": MessageLookupByLibrary.simpleMessage(
      "Experience seamless internationalization with automatic Dart code generation",
    ),
    "testCompleted": MessageLookupByLibrary.simpleMessage(
      "Translation test completed successfully!",
    ),
    "welcome": MessageLookupByLibrary.simpleMessage("Hello"),
    "welcomeMessage": MessageLookupByLibrary.simpleMessage(
      "Welcome to Smart ARB Translator!",
    ),
  };
}
