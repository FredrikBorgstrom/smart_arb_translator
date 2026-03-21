import 'dart:io';

import 'package:args/args.dart';
import 'package:smart_arb_translator/src/cache_cleanup.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addOption(
      'cache-dir',
      defaultsTo: '../abcx3_flutter/lib/l10n_cache',
      help: 'Path to the l10n cache directory.',
    )
    ..addOption(
      'locales',
      help: 'Comma-separated locale codes to clean. Defaults to every cached locale except en.',
    )
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Report the keys that would be removed without modifying files.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Print each removed key.',
    );

  final result = parser.parse(args);
  final localeFilter = _parseLocales(result['locales'] as String?);
  final dryRun = result['dry-run'] as bool;
  final verbose = result['verbose'] as bool;
  final cleanupResult = CacheCleanupService.cleanCorruptedCache(
    cacheDirectory: result['cache-dir'] as String,
    locales: localeFilter,
    dryRun: dryRun,
  );

  if (!cleanupResult.hasChanges) {
    stdout.writeln('No corrupted cached keys found.');
    return;
  }

  final sortedLocales = cleanupResult.removedKeysByLocale.keys.toList()..sort();
  for (final locale in sortedLocales) {
    final removedKeys = cleanupResult.removedKeysByLocale[locale]!;
    stdout.writeln(
      '${dryRun ? 'Would remove' : 'Removed'} ${removedKeys.length} corrupted cached keys from $locale',
    );
    if (verbose) {
      for (final key in removedKeys) {
        stdout.writeln('  - $locale:$key');
      }
    }
  }

  stdout.writeln(
    '${dryRun ? 'Would remove' : 'Removed'} ${cleanupResult.totalRemoved} corrupted cached keys across ${cleanupResult.affectedLocales} locales.',
  );
}

Set<String>? _parseLocales(String? rawLocales) {
  if (rawLocales == null || rawLocales.trim().isEmpty) {
    return null;
  }

  return rawLocales.split(',').map((locale) => locale.trim()).where((locale) => locale.isNotEmpty).toSet();
}
