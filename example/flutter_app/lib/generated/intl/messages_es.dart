// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
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
  String get localeName => 'es';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'Entonces', 'cabriolet': 'Solid roof cabriolet', 'truck': '16 wheel truck', 'other': 'Other'})}";

  static String m1(language) => "Idioma actual: ${language}";

  static String m2(timestamp) => "Generado en: ${timestamp}";

  static String m3(name) => "Hola, ${name} !";

  static String m4(count) =>
      "${Intl.plural(count, zero: 'No hay artículos', one: 'One item', other: '${count} items')}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Her birthday', male: 'Su cumpleaños', other: 'Their birthday')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: 'No tienes mensajes nuevos', one: 'You have 1 new message', other: 'You have ${count} new messages')}";

  static String m7(firstName) => "Bienvenido ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appName": MessageLookupByLibrary.simpleMessage("Demo app"),
    "appTitle": MessageLookupByLibrary.simpleMessage(
      "Demostración del traductor ARB inteligente",
    ),
    "changeLanguage": MessageLookupByLibrary.simpleMessage("Cambiar idioma"),
    "commonVehicleType": m0,
    "currentLanguage": m1,
    "dartCodeGen": MessageLookupByLibrary.simpleMessage(
      "Generación de código Dart",
    ),
    "dartCodeGenDesc": MessageLookupByLibrary.simpleMessage(
      "Generar automáticamente un código de ubicación de Dart seguro para tipos",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Características"),
    "flutterIntegration": MessageLookupByLibrary.simpleMessage(
      "Integración de Flutter",
    ),
    "flutterIntegrationDesc": MessageLookupByLibrary.simpleMessage(
      "Integración perfecta con el flujo de trabajo de internacionalización de Flutter",
    ),
    "generatedAt": m2,
    "greetUser": m3,
    "itemCount": m4,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage("Tu contraseña"),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage(
      "Tu nombre de usuario",
    ),
    "smartTranslation": MessageLookupByLibrary.simpleMessage(
      "Traducción inteligente",
    ),
    "smartTranslationDesc": MessageLookupByLibrary.simpleMessage(
      "Traduce solo contenido nuevo o modificado, lo que reduce los costos de API",
    ),
    "specialGreeting": MessageLookupByLibrary.simpleMessage(
      "¡Bienvenido al futuro de Flutter i18n!",
    ),
    "subtitle": MessageLookupByLibrary.simpleMessage(
      "Disfrute de una internacionalización perfecta con la generación automática de código Dart",
    ),
    "testCompleted": MessageLookupByLibrary.simpleMessage(
      "¡Prueba de traducción completada exitosamente!",
    ),
    "welcome": MessageLookupByLibrary.simpleMessage("Hola"),
    "welcomeMessage": MessageLookupByLibrary.simpleMessage(
      "¡Bienvenido a Smart ARB Translator!",
    ),
  };
}
