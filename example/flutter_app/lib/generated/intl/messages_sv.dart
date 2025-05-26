// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a sv locale. All the
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
  String get localeName => 'sv';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'Sedan', 'cabriolet': 'Cabriolet i massiv tak', 'truck': '16 hjul lastbil', 'other': 'Övrig'})}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Hennes födelsedag', male: 'Hans födelsedag', other: 'Deras födelsedag')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: 'Du har inga nya meddelanden', one: 'Du har 1 nytt meddelande', other: 'Du har ${count} nya meddelanden')}";

  static String m7(firstName) => "Välkommen ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appName": MessageLookupByLibrary.simpleMessage("Demo app"),
    "commonVehicleType": m0,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage("Ditt lösenord"),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage(
      "Ditt användarnamn",
    ),
    "welcome": MessageLookupByLibrary.simpleMessage("Haj på daj!"),
  };
}
