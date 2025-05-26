// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ja locale. All the
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
  String get localeName => 'ja';

  static String m0(vehicleType) =>
      "${Intl.select(vehicleType, {'sedan': 'それから', 'cabriolet': 'Solid roof cabriolet', 'truck': '16 wheel truck', 'other': 'Other'})}";

  static String m1(language) => "現在の言語: ${language}";

  static String m2(timestamp) => "生成日時: ${timestamp}";

  static String m3(name) => "こんにちは、 ${name} ！";

  static String m4(count) =>
      "${Intl.plural(count, zero: '記事はありません', one: 'One item', other: '${count} items')}";

  static String m5(sex) =>
      "${Intl.gender(sex, female: 'Her birthday', male: '彼の誕生日', other: 'Their birthday')}";

  static String m6(count) =>
      "${Intl.plural(count, zero: '新しいメッセージはありません', one: 'You have 1 new message', other: 'You have ${count} new messages')}";

  static String m7(firstName) => "ようこそ${firstName}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "appTitle": MessageLookupByLibrary.simpleMessage("スマートARBトランスレータのデモ"),
    "changeLanguage": MessageLookupByLibrary.simpleMessage("言語を変更する"),
    "commonVehicleType": m0,
    "currentLanguage": m1,
    "dartCodeGen": MessageLookupByLibrary.simpleMessage("Dartコード生成"),
    "dartCodeGenDesc": MessageLookupByLibrary.simpleMessage(
      "型安全なDartロケーションコードを自動生成",
    ),
    "features": MessageLookupByLibrary.simpleMessage("特徴"),
    "flutterIntegration": MessageLookupByLibrary.simpleMessage("Flutter統合"),
    "flutterIntegrationDesc": MessageLookupByLibrary.simpleMessage(
      "Flutterの国際化ワークフローとのシームレスな統合",
    ),
    "generatedAt": m2,
    "greetUser": m3,
    "itemCount": m4,
    "pageHomeBirthday": m5,
    "pageHomeInboxCount": m6,
    "pageHomeTitle": m7,
    "pageLoginPassword": MessageLookupByLibrary.simpleMessage("パスワード"),
    "pageLoginUsername": MessageLookupByLibrary.simpleMessage("ユーザー名"),
    "smartTranslation": MessageLookupByLibrary.simpleMessage("スマート翻訳"),
    "smartTranslationDesc": MessageLookupByLibrary.simpleMessage(
      "新規または変更されたコンテンツのみを翻訳し、API コストを削減します",
    ),
    "specialGreeting": MessageLookupByLibrary.simpleMessage(
      "Flutter i18n の未来へようこそ!",
    ),
    "subtitle": MessageLookupByLibrary.simpleMessage(
      "自動 Dart コード生成によるシームレスな国際化をお楽しみください",
    ),
    "testCompleted": MessageLookupByLibrary.simpleMessage("翻訳テストが正常に完了しました。"),
    "welcome": MessageLookupByLibrary.simpleMessage("こんにちは"),
    "welcomeMessage": MessageLookupByLibrary.simpleMessage(
      "Smart ARB Translator へようこそ!",
    ),
  };
}
