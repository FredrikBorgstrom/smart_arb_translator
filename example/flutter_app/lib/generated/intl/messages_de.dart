// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a de locale. All the
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
  String get localeName => 'de';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'Dann', 'cabriolet': 'Solid roof cabriolet', 'truck': '16 wheel truck', 'other': 'Other'})}";

  static String m1(language) => "Aktuelle Sprache: ${language}";

  static String m2(timestamp) => "Generiert am: ${timestamp}";

  static String m3(name) => "Hallo, ${name} !";

  static String m4(count) =>
      "${Intl.plural(count, zero: 'Keine Artikel', one: 'One item', other: '${count} items')}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Her birthday', male: 'Sein Geburtstag', other: 'Their birthday')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: 'Sie haben keine neuen Nachrichten', one: 'You have 1 new message', other: 'You have ${count} new messages')}";

  static String m7(firstName) => "Willkommen ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage(
      "Demo des Smart ARB-Übersetzers",
    ),
    "changeLanguage": MessageLookupByLibrary.simpleMessage("Sprache ändern"),
    "commonVehicleType": m0,
    "currentLanguage": m1,
    "dartCodeGen": MessageLookupByLibrary.simpleMessage("Dart-Codegenerierung"),
    "dartCodeGenDesc": MessageLookupByLibrary.simpleMessage(
      "Automatisch typsicheren Dart-Standortcode generieren",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Merkmale"),
    "flutterIntegration": MessageLookupByLibrary.simpleMessage(
      "Flutter-Integration",
    ),
    "flutterIntegrationDesc": MessageLookupByLibrary.simpleMessage(
      "Nahtlose Integration in den Internationalisierungs-Workflow von Flutter",
    ),
    "generatedAt": m2,
    "greetUser": m3,
    "itemCount": m4,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage("Ihr Passwort"),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage(
      "Ihr Benutzername",
    ),
    "smartTranslation": MessageLookupByLibrary.simpleMessage(
      "Intelligente Übersetzung",
    ),
    "smartTranslationDesc": MessageLookupByLibrary.simpleMessage(
      "Übersetzt nur neue oder geänderte Inhalte und reduziert so die API-Kosten",
    ),
    "specialGreeting": MessageLookupByLibrary.simpleMessage(
      "Willkommen in der Zukunft von Flutter i18n!",
    ),
    "subtitle": MessageLookupByLibrary.simpleMessage(
      "Genießen Sie nahtlose Internationalisierung mit der automatischen Dart-Codegenerierung",
    ),
    "testCompleted": MessageLookupByLibrary.simpleMessage(
      "Übersetzungstest erfolgreich abgeschlossen!",
    ),
    "welcome": MessageLookupByLibrary.simpleMessage("Hallo"),
    "welcomeMessage": MessageLookupByLibrary.simpleMessage(
      "Willkommen beim Smart ARB Translator!",
    ),
  };
}
