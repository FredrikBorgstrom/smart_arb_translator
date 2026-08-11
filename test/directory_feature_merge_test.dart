import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/directory_processor.dart';
import 'package:test/test.dart';

void main() {
  test('directory mode preserves every feature chunk before locale merge', () async {
    final temp = Directory.systemTemp.createTempSync('smart_arb_directory_feature_merge_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final source = Directory(path.join(temp.path, 'source'))..createSync(recursive: true);
    final cache = Directory(path.join(temp.path, 'cache'))..createSync(recursive: true);
    final l10n = Directory(path.join(temp.path, 'l10n'))..createSync(recursive: true);
    _writeJson(path.join(source.path, 'gameplay.arb'), <String, Object?>{
      '@@locale': 'en',
      'play': 'Play',
      '@play': <String, Object?>{
        'description': 'Primary move action.',
        'x-translations': <String, String>{'fr': 'Jouer', 'es': 'Jugar'},
      },
    });
    _writeJson(path.join(source.path, 'ui.arb'), <String, Object?>{
      '@@locale': 'en',
      'back': 'Back',
      '@back': <String, Object?>{
        'description': 'Return action.',
        'x-translations': <String, String>{'fr': 'Retour', 'es': 'Atrás'},
      },
    });
    _writeJson(path.join(cache.path, 'fr', 'intl_fr.arb'), <String, Object?>{
      '@@locale': 'fr',
      'obsolete': 'Périmé',
    });

    await DirectoryProcessor.processDirectory(
      source.path,
      <String>['en', 'fr', 'es'],
      '',
      cache.path,
      'intl_',
      l10n.path,
      manualOnly: true,
      dartMainLocale: 'en',
      parallelTranslations: 2,
    );

    final generated = _readJson(path.join(l10n.path, 'intl_fr.arb'));
    expect(generated['@@locale'], 'fr');
    expect(generated['play'], 'Jouer');
    expect(generated['back'], 'Retour');
    expect(generated, isNot(contains('obsolete')));
    expect(File(path.join(cache.path, 'fr', 'intl_fr.arb')).existsSync(), isTrue);
    expect(File(path.join(cache.path, 'fr', 'gameplay.arb')).existsSync(), isFalse);
    expect(File(path.join(cache.path, 'fr', 'ui.arb')).existsSync(), isFalse);
    final generatedSpanish = _readJson(path.join(l10n.path, 'intl_es.arb'));
    expect(generatedSpanish['play'], 'Jugar');
    expect(generatedSpanish['back'], 'Atrás');

    await DirectoryProcessor.processDirectory(
      source.path,
      <String>['en', 'fr', 'es'],
      '',
      cache.path,
      'intl_',
      l10n.path,
      manualOnly: true,
      dartMainLocale: 'en',
      parallelTranslations: 2,
      sourceFileFilters: <String>{'ui.arb'},
    );
    expect(_readJson(path.join(l10n.path, 'intl_fr.arb')), generated);

    _writeJson(path.join(source.path, 'gameplay.arb'), <String, Object?>{'@@locale': 'en'});
    await DirectoryProcessor.processDirectory(
      source.path,
      <String>['en', 'fr', 'es'],
      '',
      cache.path,
      'intl_',
      l10n.path,
      manualOnly: true,
      dartMainLocale: 'en',
      parallelTranslations: 2,
    );
    final afterDeletion = _readJson(path.join(l10n.path, 'intl_fr.arb'));
    expect(afterDeletion['back'], 'Retour');
    expect(afterDeletion, isNot(contains('play')));
  });

  test('directory mode rejects duplicate source ownership', () async {
    final temp = Directory.systemTemp.createTempSync('smart_arb_directory_duplicate_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final source = Directory(path.join(temp.path, 'source'))..createSync(recursive: true);
    _writeJson(path.join(source.path, 'a.arb'), <String, Object?>{'@@locale': 'en', 'shared': 'One'});
    _writeJson(path.join(source.path, 'b.arb'), <String, Object?>{'@@locale': 'en', 'shared': 'Two'});
    await expectLater(
      DirectoryProcessor.processDirectory(
        source.path,
        <String>['fr'],
        '',
        path.join(temp.path, 'cache'),
        'intl_',
        path.join(temp.path, 'l10n'),
        manualOnly: true,
      ),
      throwsFormatException,
    );
  });
}

void _writeJson(String filePath, Map<String, Object?> contents) {
  File(filePath)
    ..createSync(recursive: true)
    ..writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(contents)}\n');
}

Map<String, dynamic> _readJson(String filePath) =>
    (jsonDecode(File(filePath).readAsStringSync()) as Map).cast<String, dynamic>();
