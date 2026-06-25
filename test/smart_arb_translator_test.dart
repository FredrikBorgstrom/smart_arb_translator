import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' show join;
import 'package:smart_arb_translator/src/models/arb_document.dart';
import 'package:test/test.dart';

final _packageDirectory = Directory.current.path;

void main() {
  final testDirectory = join(
    _packageDirectory,
    _packageDirectory.endsWith('test') ? '' : 'test',
  );

  final testFileOne = File(join(testDirectory, 'resources/example_one.arb'));
  final contents = testFileOne.readAsStringSync();

  group(
    'Correctly parses arb documents',
    () {
      final document = ArbDocument.decode(
        contents,
        includeTimestampIfNull: false,
      );

      group('Top Level Fields', () {
        test(
          'Parses document appName',
          () {
            expect(document.appName, equals('Demo app'));
          },
        );

        test(
          'Parses document locale',
          () {
            expect(document.locale, equals('en'));
          },
        );

        test(
          'Last modified is null',
          () {
            expect(document.lastModified, equals(null));
          },
        );

        test(
          'Document contains resources',
          () {
            expect(document.resources.isNotEmpty, equals(true));
          },
        );
      });

      group('Resources', () {
        final pageLoginResource = document.resources.entries.firstWhere(
          (entry) => entry.key == 'pageLoginUsername',
        );
        final pageHomeResource = document.resources.entries.firstWhere(
          (entry) => entry.key == 'pageHomeInboxCount',
        );

        test('resource contains correct id', () {
          expect(pageLoginResource.key, equals('pageLoginUsername'));
        });

        test('resource has same id as internal id', () {
          expect(pageLoginResource.key, equals(pageLoginResource.value.id));
        });

        test('resource has null attributes', () {
          expect(pageLoginResource.value.attributes, isNull);
        });

        test('has same id as internal', () {
          expect(pageHomeResource.key, equals(pageHomeResource.value.id));
        });

        test('has non null and correct description', () {
          expect(
            pageHomeResource.value.attributes?.description,
            equals('New messages count on the Home screen'),
          );
        });

        test('has non empty text', () {
          final text = pageHomeResource.value.text;

          expect(
            text,
            isNotEmpty,
          );
        });

        test('has non empty tokens', () {
          final tokens = pageHomeResource.value.tokens;

          expect(
            tokens.length,
            equals(3),
          );
        });

        test('has non empty attributes placeholders', () {
          expect(
            pageHomeResource.value.attributes?.placeholders?.isNotEmpty ?? false,
            isTrue,
          );
        });

        test('There exists a key \'count\' inside placholders', () {
          expect(
            pageHomeResource.value.attributes?.placeholders?.containsKey('count') ?? false,
            isTrue,
          );
        });
      });

      test('deserialize', () {
        final deserialized = document.encode();
        final decoded = jsonDecode(deserialized) as Map<String, dynamic>;

        expect(decoded['@@locale'], equals('en'));
        expect(decoded['appName'], equals('Demo app'));
        expect(decoded['pageHomeTitle'], equals('Welcome {firstName}'));
        expect(decoded['@welcome']['x-translations'], isNull);
      });
    },
  );

  group('translates test_file', () {
    test('General help', () async {
      final task = await _runTranslator(['--help']);

      expect(
        task.stdout,
        isNotEmpty,
        reason: 'Output was expected no help was given',
      );
      expect(
        task.stderr,
        isEmpty,
        reason: 'This should not have thrown an error: ${task.stderr}',
      );
    });

    test('Throw error without arguments', () async {
      final task = await _runTranslator([]);

      expect(task.stdout, contains('Error'));
      expect(task.exitCode, equals(1));
    });

    test('Throw error without api key', () async {
      final task = await _runTranslator(['--source_arb', '/test_file.arb']);

      expect(task.stdout, contains('Error'));
      expect(task.exitCode, equals(1));
    });

    test('Translates text', () async {
      // Todo This will need a mock api test
      // final task = await Process.run(
      //   'dart',
      //   [
      //     'run',
      //     'smart_arb_translator:translate',
      //     '--source_arb',
      //     '/test_file.arb',
      //   ],
      // );
    });
  });
}

Future<ProcessResult> _runTranslator(List<String> args) {
  return Process.run(
    'dart',
    ['run', 'smart_arb_translator:translate', ...args],
    workingDirectory: _packageDirectory,
  );
}
