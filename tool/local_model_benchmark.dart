import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:smart_arb_translator/src/local_model_benchmark.dart';
import 'package:smart_arb_translator/src/models/local_llm_options.dart';

Future<void> main(List<String> arguments) async {
  final code = await runLocalModelBenchmarkCli(arguments);
  if (code != 0) exitCode = code;
}

typedef BenchmarkRunner = Future<Map<String, dynamic>> Function({
  required LocalModelBenchmarkCorpus corpus,
  required LocalLlmOptions options,
  Iterable<String>? selectedLocales,
});

/// Testable entrypoint for the explicitly invoked local-model benchmark tool.
Future<int> runLocalModelBenchmarkCli(
  List<String> arguments, {
  BenchmarkRunner? benchmarkRunner,
  void Function(String value)? write,
  void Function(String value)? writeError,
}) async {
  final out = write ?? stdout.writeln;
  final err = writeError ?? stderr.writeln;
  final parser = ArgParser()
    ..addOption('input', help: 'Benchmark corpus JSON file.')
    ..addOption('output', help: 'Result JSON file.')
    ..addOption('model', help: 'Already-installed local model identifier.')
    ..addOption('endpoint', help: 'OpenAI-compatible local endpoint.', defaultsTo: LocalLlmOptions.defaultEndpoint)
    ..addOption('profile',
        help: 'openai_chat_json or translategemma.',
        allowed: ['openai_chat_json', 'translategemma'],
        defaultsTo: 'openai_chat_json')
    ..addMultiOption('locale', help: 'Locale(s) selected from the corpus.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
  late ArgResults result;
  try {
    result = parser.parse(arguments);
  } on FormatException catch (error) {
    err(error.message);
    err(parser.usage);
    return 64;
  }
  if (result['help'] as bool) {
    out(parser.usage);
    return 0;
  }
  try {
    for (final option in ['input', 'output', 'model']) {
      if ((result[option] as String?)?.trim().isEmpty ?? true) {
        throw ArgumentError('--$option is required.');
      }
    }
    final input = File(result['input'] as String);
    if (!input.existsSync()) throw ArgumentError('Benchmark input does not exist: ${input.path}');
    final corpus = LocalModelBenchmarkCorpus.decode(input.readAsStringSync());
    final options = LocalLlmOptions.fromConfig(
      endpoint: result['endpoint'] as String,
      model: result['model'] as String,
      profile: result['profile'] as String,
    );
    final runner = benchmarkRunner ?? LocalModelBenchmarkRunner.run;
    final output = await runner(
      corpus: corpus,
      options: options,
      selectedLocales: (result['locale'] as List<String>).isEmpty ? null : result['locale'] as List<String>,
    );
    final file = File(result['output'] as String);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
    out('Wrote local-model benchmark: ${file.path}');
    return 0;
  } catch (error) {
    err('Benchmark failed: $error');
    return 1;
  }
}
