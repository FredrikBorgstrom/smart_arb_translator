// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a fr locale. All the
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
  String get localeName => 'fr';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'Alors', 'cabriolet': 'Solid roof cabriolet', 'truck': '16 wheel truck', 'other': 'Other'})}";

  static String m1(language) => "Langue actuelle : ${language}";

  static String m2(timestamp) => "Généré à : ${timestamp}";

  static String m3(name) => "Bonjour, ${name} !";

  static String m4(count) =>
      "${Intl.plural(count, zero: 'Aucun article', one: 'One item', other: '${count} items')}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Her birthday', male: 'Son anniversaire', other: 'Their birthday')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: 'Vous n\'avez pas de nouveaux messages', one: 'You have 1 new message', other: 'You have ${count} new messages')}";

  static String m7(firstName) => "Bienvenue ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage(
      "Démo du traducteur Smart ARB",
    ),
    "changeLanguage": MessageLookupByLibrary.simpleMessage("Changer de langue"),
    "commonVehicleType": m0,
    "currentLanguage": m1,
    "dartCodeGen": MessageLookupByLibrary.simpleMessage(
      "Génération de code Dart",
    ),
    "dartCodeGenDesc": MessageLookupByLibrary.simpleMessage(
      "Génère automatiquement du code de localisation Dart de type sécurisé",
    ),
    "features": MessageLookupByLibrary.simpleMessage("Caractéristiques"),
    "flutterIntegration": MessageLookupByLibrary.simpleMessage(
      "Intégration Flutter",
    ),
    "flutterIntegrationDesc": MessageLookupByLibrary.simpleMessage(
      "Intégration transparente avec le flux de travail d\'internationalisation de Flutter",
    ),
    "generatedAt": m2,
    "greetUser": m3,
    "itemCount": m4,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage(
      "Votre mot de passe",
    ),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage(
      "Votre nom d\'utilisateur",
    ),
    "smartTranslation": MessageLookupByLibrary.simpleMessage(
      "Traduction intelligente",
    ),
    "smartTranslationDesc": MessageLookupByLibrary.simpleMessage(
      "Traduit uniquement le contenu nouveau ou modifié, ce qui permet de réduire les coûts d\'API",
    ),
    "specialGreeting": MessageLookupByLibrary.simpleMessage(
      "Bienvenue dans le futur de Flutter i18n !",
    ),
    "subtitle": MessageLookupByLibrary.simpleMessage(
      "Bénéficiez d\'une internationalisation transparente grâce à la génération automatique de code Dart",
    ),
    "testCompleted": MessageLookupByLibrary.simpleMessage(
      "Test de traduction terminé avec succès !",
    ),
    "welcome": MessageLookupByLibrary.simpleMessage("Bien venue, mec!"),
    "welcomeMessage": MessageLookupByLibrary.simpleMessage(
      "Bienvenue sur Smart ARB Translator !",
    ),
  };
}
