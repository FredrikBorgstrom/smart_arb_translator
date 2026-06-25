import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:test/test.dart';

void main() {
  group('source locale protection', () {
    late Directory tempDir;
    late Directory cacheDir;
    late Directory l10nDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('source_locale_protection_test');
      cacheDir = Directory(path.join(tempDir.path, 'l10n_cache'))..createSync(recursive: true);
      l10nDir = Directory(path.join(tempDir.path, 'l10n'))..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('rebuilds intl_en from source chunks instead of stale translated English output', () async {
      final enDir = Directory(path.join(cacheDir.path, 'en'))..createSync(recursive: true);
      _writeJson(path.join(enDir.path, 'gameplay.arb'), {
        '@@locale': 'en',
        'play': 'Play',
        '@play': {'description': 'Primary play button'},
      });
      _writeJson(path.join(enDir.path, 'legal.arb'), {
        '@@locale': 'en',
        'authProviderReminderTitle': 'Secure Your Account',
      });
      _writeJson(path.join(enDir.path, 'intl_en.arb'), {
        '@@locale': 'en',
        'play': 'Jugar',
        'authProviderReminderTitle': 'Asegura Tu Cuenta',
      });

      final esDir = Directory(path.join(cacheDir.path, 'es'))..createSync(recursive: true);
      _writeJson(path.join(esDir.path, 'intl_es.arb'), {
        '@@locale': 'es',
        'play': 'Jugar',
        'authProviderReminderTitle': 'Asegura Tu Cuenta',
      });

      await DirectoryProcessor.mergeToL10nDirectory(
        cacheDir.path,
        l10nDir.path,
        ['en', 'es'],
        sourceLocaleDirectory: enDir.path,
        mainLocale: 'en',
      );

      final generatedEnglish = _readJson(path.join(l10nDir.path, 'intl_en.arb'));
      expect(generatedEnglish['play'], 'Play');
      expect(generatedEnglish['authProviderReminderTitle'], 'Secure Your Account');
      expect(generatedEnglish['@play'], {'description': 'Primary play button'});

      expect(File(path.join(l10nDir.path, 'intl_en.arb')).existsSync(), isTrue);
      expect(File(path.join(l10nDir.path, 'intl_es.arb')).existsSync(), isTrue);
    });
  });
}

void _writeJson(String filePath, Map<String, dynamic> contents) {
  File(filePath)
    ..createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(contents)}\n');
}

Map<String, dynamic> _readJson(String filePath) {
  return (jsonDecode(File(filePath).readAsStringSync()) as Map).cast<String, dynamic>();
}
