import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:smart_arb_translator/src/cache_cleanup.dart';
import 'package:test/test.dart';

void main() {
  group('CacheCleanupService', () {
    late Directory tempDir;
    late Directory cacheDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('cache_cleanup_test');
      cacheDir = Directory(path.join(tempDir.path, 'l10n_cache'))..createSync(recursive: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('removes only corrupted cached keys and keeps valid ones', () {
      _writeArb(
        cacheDir,
        'en',
        '''
{
  "@@locale": "en",
  "swapTilesSuccess": "{count, plural, zero{You must select at least one game tile to swap} one{You swapped one game tile} other{You swapped {count} game tiles.}}",
  "@swapTilesSuccess": {
    "description": "Swap tiles notification",
    "placeholders": {
      "count": {}
    }
  },
  "hours": "{count, plural, zero{{count} hours} one{1 hour} other{{count} hours}}",
  "@hours": {
    "description": "hours",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "welcome": "Welcome"
}
''',
      );

      _writeArb(
        cacheDir,
        'sv',
        '''
{
  "@@locale": "sv",
  "swapTilesSuccess": "{count, plural, zero{{count, plural, zero{Du måste välja minst en spelbricka att byta} one{Du bytte en spelbricka} other{Du bytte {count} spelbrickor.}}} one{You swapped one game tile} other{You swapped {count} game tiles.}}",
  "@swapTilesSuccess": {
    "description": "Swap tiles notification",
    "placeholders": {
      "count": {}
    }
  },
  "hours": "{count, plural, zero{{count} timmar} one{1 hour} other{{count} hours}}",
  "@hours": {
    "description": "hours",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "welcome": "Välkommen"
}
''',
      );

      final dryRunResult = CacheCleanupService.cleanCorruptedCache(
        cacheDirectory: cacheDir.path,
        dryRun: true,
      );
      expect(dryRunResult.totalRemoved, equals(2));
      expect(dryRunResult.removedKeysByLocale['sv'], containsAll(['swapTilesSuccess', 'hours']));

      final result = CacheCleanupService.cleanCorruptedCache(
        cacheDirectory: cacheDir.path,
      );

      expect(result.totalRemoved, equals(2));
      final updatedSv = File(path.join(cacheDir.path, 'sv', 'intl_sv.arb')).readAsStringSync();
      expect(updatedSv, isNot(contains('"swapTilesSuccess"')));
      expect(updatedSv, isNot(contains('"@swapTilesSuccess"')));
      expect(updatedSv, isNot(contains('"hours"')));
      expect(updatedSv, contains('"welcome": "Välkommen"'));
    });

    test('limits cleanup to requested locales', () {
      _writeArb(
        cacheDir,
        'en',
        '''
{
  "@@locale": "en",
  "hours": "{count, plural, zero{{count} hours} one{1 hour} other{{count} hours}}",
  "@hours": {
    "description": "hours",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
''',
      );

      _writeArb(
        cacheDir,
        'ar',
        '''
{
  "@@locale": "ar",
  "hours": "{count, plural, zero{{count} الساعات} one{1 hour} other{{count} hours}}",
  "@hours": {
    "description": "hours",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
''',
      );

      _writeArb(
        cacheDir,
        'sv',
        '''
{
  "@@locale": "sv",
  "hours": "{count, plural, zero{{count} timmar} one{1 hour} other{{count} hours}}",
  "@hours": {
    "description": "hours",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
''',
      );

      final result = CacheCleanupService.cleanCorruptedCache(
        cacheDirectory: cacheDir.path,
        locales: {'ar'},
      );

      expect(result.totalRemoved, equals(1));
      expect(result.removedKeysByLocale.keys, equals({'ar'}));

      final arContents = File(path.join(cacheDir.path, 'ar', 'intl_ar.arb')).readAsStringSync();
      final svContents = File(path.join(cacheDir.path, 'sv', 'intl_sv.arb')).readAsStringSync();
      expect(arContents, isNot(contains('"hours"')));
      expect(svContents, contains('"hours"'));
    });
  });
}

void _writeArb(Directory cacheDir, String locale, String contents) {
  final localeDir = Directory(path.join(cacheDir.path, locale))..createSync(recursive: true);
  File(path.join(localeDir.path, 'intl_$locale.arb')).writeAsStringSync(contents.trim());
}
