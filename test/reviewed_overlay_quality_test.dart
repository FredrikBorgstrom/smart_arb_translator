import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/reviewed_overlay_quality.dart';

void main() {
  late Directory root;
  late Directory source;
  late Directory reviewed;

  setUp(() {
    root = Directory.systemTemp.createTempSync('reviewed_overlay_quality_');
    source = Directory('${root.path}/source')..createSync();
    reviewed = Directory('${root.path}/reviewed')..createSync();
    _write(
      File('${source.path}/ui.arb'),
      <String, Object?>{
        '@@locale': 'en',
        'back': 'Back',
        '@back': <String, Object?>{'description': 'Navigation action.'},
      },
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('quality CLI validates every paired reviewed feature without a provider', () {
    final fr = Directory('${reviewed.path}/fr')..createSync();
    _write(File('${fr.path}/ui.arb'), <String, Object?>{'@@locale': 'fr', 'back': 'Retour'});
    final output = <String>[];

    final code = runReviewedOverlayQualityCli(
      <String>['--source-dir', source.path, '--reviewed-dir', reviewed.path],
      write: output.add,
    );
    final report = jsonDecode(output.single) as Map<String, dynamic>;

    expect(code, 0);
    expect(report, containsPair('valid', true));
    expect(report, containsPair('pair_count', 1));
  });

  test('quality CLI reports passthrough and accepts an explicit paired allowlist', () {
    _write(File('${source.path}/ui.arb'), <String, Object?>{
      '@@locale': 'en',
      'back': 'Back',
      '@back': <String, Object?>{'description': 'Navigation action.'},
      'emailHint': 'name@example.com',
    });
    final ar = Directory('${reviewed.path}/ar')..createSync();
    _write(File('${ar.path}/ui.arb'), <String, Object?>{
      '@@locale': 'ar',
      'back': 'Back',
      'emailHint': 'name@example.com',
    });
    final failed = <String>[];
    expect(
      runReviewedOverlayQualityCli(
        <String>['--source-dir', source.path, '--reviewed-dir', reviewed.path],
        write: failed.add,
      ),
      1,
    );
    final failedReport = jsonDecode(failed.single) as Map<String, dynamic>;
    expect(
      failedReport['issues'],
      contains(predicate<Map>((issue) => issue['code'] == 'source_passthrough' && issue['key'] == 'back')),
    );
    expect(
      failedReport['issues'],
      contains(predicate<Map>((issue) => issue['code'] == 'target_script_mismatch' && issue['key'] == 'emailHint')),
    );

    final allowlist = File('${root.path}/allowlist.json');
    _write(allowlist, <String, Object?>{
      'locales': <String, Object?>{
        'ar': <String>['back', 'emailHint'],
      },
    });
    final passed = <String>[];
    expect(
      runReviewedOverlayQualityCli(
        <String>[
          '--source-dir',
          source.path,
          '--reviewed-dir',
          reviewed.path,
          '--allowlist-file',
          allowlist.path,
        ],
        write: passed.add,
      ),
      0,
    );
    expect(jsonDecode(passed.single), containsPair('valid', true));

    final fr = Directory('${reviewed.path}/fr')..createSync();
    _write(File('${fr.path}/ui.arb'), <String, Object?>{
      '@@locale': 'fr',
      'back': 'Back',
      'emailHint': 'nom@example.com',
    });
    final localeScoped = <String>[];
    expect(
      runReviewedOverlayQualityCli(
        <String>[
          '--source-dir',
          source.path,
          '--reviewed-dir',
          reviewed.path,
          '--allowlist-file',
          allowlist.path,
        ],
        write: localeScoped.add,
      ),
      1,
    );
    expect(
      (jsonDecode(localeScoped.single) as Map<String, dynamic>)['issues'],
      contains(predicate<Map>((issue) => issue['locale'] == 'fr' && issue['code'] == 'source_passthrough')),
    );
  });

  test('quality CLI fails on missing feature ownership', () {
    Directory('${reviewed.path}/fr').createSync();
    final output = <String>[];
    expect(
      runReviewedOverlayQualityCli(
        <String>['--source-dir', source.path, '--reviewed-dir', reviewed.path],
        write: output.add,
      ),
      1,
    );
    final report = jsonDecode(output.single) as Map<String, dynamic>;
    expect(
      report['issues'],
      contains(predicate<Map>((issue) => issue['code'] == 'missing_reviewed_feature')),
    );
  });
}

void _write(File file, Object value) {
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');
}
