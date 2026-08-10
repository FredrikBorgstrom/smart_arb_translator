import 'dart:io';

import 'package:test/test.dart';

void main() {
  Future<ProcessResult> runCli(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        ['run', 'bin/translate.dart', ...arguments],
        workingDirectory: Directory.current.path,
      );

  test('public CLI inspection and manual-only controls need neither key nor HTTP', () async {
    final temp = await Directory.systemTemp.createTemp('smart-arb-cli-controls');
    addTearDown(() => temp.delete(recursive: true));
    final source = File('${temp.path}/ui.arb')..writeAsStringSync('''
{"@@locale":"en","back":"Back","@back":{"x-translations":{"fr":"Retour"}}}
''');

    final validate = await runCli(['--source_arb', source.path, '--validate_only', '--no-generate_dart']);
    expect(validate.exitCode, 0, reason: '${validate.stdout}\n${validate.stderr}');

    final dryPlan = await runCli(['--source_arb', source.path, '--dry_run_network_plan', '--no-generate_dart']);
    expect(dryPlan.exitCode, 0, reason: '${dryPlan.stdout}\n${dryPlan.stderr}');
    expect(dryPlan.stdout, contains('Dry-run network plan'));

    final stale = await runCli([
      '--source_arb',
      source.path,
      '--language_codes',
      'fr',
      '--list_stale_reviewed',
      '--no-generate_dart',
    ]);
    expect(stale.exitCode, 0, reason: '${stale.stdout}\n${stale.stderr}');
    expect(stale.stdout, contains('fr/ui.arb#back'));

    final output = Directory('${temp.path}/out');
    final manual = await runCli([
      '--source_arb',
      source.path,
      '--language_codes',
      'fr',
      '--l10n_directory',
      output.path,
      '--manual_only',
      '--no-generate_dart',
    ]);
    expect(manual.exitCode, 0, reason: '${manual.stdout}\n${manual.stderr}');
    expect(File('${output.path}/intl_fr.arb').existsSync(), isTrue);
  }, timeout: const Timeout(Duration(minutes: 1)));
}
