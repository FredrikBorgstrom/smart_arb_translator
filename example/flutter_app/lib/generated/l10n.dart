// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class AppLocalizations {
  AppLocalizations();

  static AppLocalizations? _current;

  static AppLocalizations get current {
    assert(
      _current != null,
      'No instance of AppLocalizations was loaded. Try to initialize the AppLocalizations delegate before accessing AppLocalizations.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<AppLocalizations> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = AppLocalizations();
      AppLocalizations._current = instance;

      return instance;
    });
  }

  static AppLocalizations of(BuildContext context) {
    final instance = AppLocalizations.maybeOf(context);
    assert(
      instance != null,
      'No instance of AppLocalizations present in the widget tree. Did you add AppLocalizations.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  /// `Demo app`
  String get appName {
    return Intl.message('Demo app', name: 'appName', desc: '', args: []);
  }

  /// `Smart ARB Translator Demo`
  String get appTitle {
    return Intl.message(
      'Smart ARB Translator Demo',
      name: 'appTitle',
      desc: 'The title of the application',
      args: [],
    );
  }

  /// `Change Language`
  String get changeLanguage {
    return Intl.message(
      'Change Language',
      name: 'changeLanguage',
      desc: 'Button text to change language',
      args: [],
    );
  }

  /// `{vehicleType, select, sedan{Sedan} cabriolet{Solid roof cabriolet} truck{16 wheel truck} other{Other}}`
  String commonVehicleType(Object vehicleType) {
    return Intl.select(
      vehicleType,
      {
        'sedan': 'Sedan',
        'cabriolet': 'Solid roof cabriolet',
        'truck': '16 wheel truck',
        'other': 'Other',
      },
      name: 'commonVehicleType',
      desc: 'Vehicle type',
      args: [vehicleType],
    );
  }

  /// `Current language: {language}`
  String currentLanguage(String language) {
    return Intl.message(
      'Current language: $language',
      name: 'currentLanguage',
      desc: 'Shows the current language',
      args: [language],
    );
  }

  /// `Dart Code Generation`
  String get dartCodeGen {
    return Intl.message(
      'Dart Code Generation',
      name: 'dartCodeGen',
      desc: 'Feature: Dart code generation',
      args: [],
    );
  }

  /// `Automatically generates type-safe Dart localization code`
  String get dartCodeGenDesc {
    return Intl.message(
      'Automatically generates type-safe Dart localization code',
      name: 'dartCodeGenDesc',
      desc: 'Description of Dart code generation feature',
      args: [],
    );
  }

  /// `Features`
  String get features {
    return Intl.message(
      'Features',
      name: 'features',
      desc: 'Section title for features',
      args: [],
    );
  }

  /// `Flutter Integration`
  String get flutterIntegration {
    return Intl.message(
      'Flutter Integration',
      name: 'flutterIntegration',
      desc: 'Feature: Flutter integration',
      args: [],
    );
  }

  /// `Seamless integration with Flutter's internationalization workflow`
  String get flutterIntegrationDesc {
    return Intl.message(
      'Seamless integration with Flutter\'s internationalization workflow',
      name: 'flutterIntegrationDesc',
      desc: 'Description of Flutter integration feature',
      args: [],
    );
  }

  /// `Generated at: {timestamp}`
  String generatedAt(DateTime timestamp) {
    final DateFormat timestampDateFormat = DateFormat.yMd(
      Intl.getCurrentLocale(),
    );
    final String timestampString = timestampDateFormat.format(timestamp);

    return Intl.message(
      'Generated at: $timestampString',
      name: 'generatedAt',
      desc: 'Shows when the translations were generated',
      args: [timestampString],
    );
  }

  /// `Hello, {name}!`
  String greetUser(String name) {
    return Intl.message(
      'Hello, $name!',
      name: 'greetUser',
      desc: 'Greets the user by name',
      args: [name],
    );
  }

  /// `{count,plural, =0{No items} =1{One item} other{{count} items}}`
  String itemCount(int count) {
    return Intl.plural(
      count,
      zero: 'No items',
      one: 'One item',
      other: '$count items',
      name: 'itemCount',
      desc: 'Shows the number of items',
      args: [count],
    );
  }

  /// `{sex, select, male{His birthday} female{Her birthday} other{Their birthday}}`
  String pageHomeBirthday(String sex) {
    return Intl.gender(
      sex,
      male: 'His birthday',
      female: 'Her birthday',
      other: 'Their birthday',
      name: 'pageHomeBirthday',
      desc: 'Birthday message on the Home screen',
      args: [sex],
    );
  }

  /// `{count, plural, zero{You have no new messages} one{You have 1 new message} other{You have {count} new messages}}`
  String pageHomeInboxCount(num count) {
    return Intl.plural(
      count,
      zero: 'You have no new messages',
      one: 'You have 1 new message',
      other: 'You have $count new messages',
      name: 'pageHomeInboxCount',
      desc: 'New messages count on the Home screen',
      args: [count],
    );
  }

  /// `Welcome {firstName}`
  String pageHomeTitle(String firstName) {
    return Intl.message(
      'Welcome $firstName',
      name: 'pageHomeTitle',
      desc: 'Welcome message on the Home screen',
      args: [firstName],
    );
  }

  /// `Your password`
  String get pageLoginPassword {
    return Intl.message(
      'Your password',
      name: 'pageLoginPassword',
      desc: '',
      args: [],
    );
  }

  /// `Your username`
  String get pageLoginUsername {
    return Intl.message(
      'Your username',
      name: 'pageLoginUsername',
      desc: '',
      args: [],
    );
  }

  /// `Smart Translation`
  String get smartTranslation {
    return Intl.message(
      'Smart Translation',
      name: 'smartTranslation',
      desc: 'Feature: Smart translation',
      args: [],
    );
  }

  /// `Only translates new or changed content, saving API costs`
  String get smartTranslationDesc {
    return Intl.message(
      'Only translates new or changed content, saving API costs',
      name: 'smartTranslationDesc',
      desc: 'Description of smart translation feature',
      args: [],
    );
  }

  /// `Welcome to the future of Flutter i18n!`
  String get specialGreeting {
    return Intl.message(
      'Welcome to the future of Flutter i18n!',
      name: 'specialGreeting',
      desc: 'A special greeting message',
      args: [],
    );
  }

  /// `Experience seamless internationalization with automatic Dart code generation`
  String get subtitle {
    return Intl.message(
      'Experience seamless internationalization with automatic Dart code generation',
      name: 'subtitle',
      desc: 'Subtitle explaining the app\'s purpose',
      args: [],
    );
  }

  /// `Translation test completed successfully!`
  String get testCompleted {
    return Intl.message(
      'Translation test completed successfully!',
      name: 'testCompleted',
      desc: 'Message shown when translation test is completed',
      args: [],
    );
  }

  /// `Hello`
  String get welcome {
    return Intl.message(
      'Hello',
      name: 'welcome',
      desc: 'Greeting with manual translation',
      args: [],
    );
  }

  /// `Welcome to Smart ARB Translator!`
  String get welcomeMessage {
    return Intl.message(
      'Welcome to Smart ARB Translator!',
      name: 'welcomeMessage',
      desc: 'Welcome message shown to users',
      args: [],
    );
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'de'),
      Locale.fromSubtags(languageCode: 'es'),
      Locale.fromSubtags(languageCode: 'fr'),
      Locale.fromSubtags(languageCode: 'ja'),
      Locale.fromSubtags(languageCode: 'sv'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
