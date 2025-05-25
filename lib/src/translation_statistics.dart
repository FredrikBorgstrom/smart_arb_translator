class TranslationStatistics {
  int translatedKeys = 0;
  int translatedWords = 0;
  int translatedCharacters = 0;

  int cachedKeys = 0;
  int cachedWords = 0;
  int cachedCharacters = 0;

  void addTranslated(String text) {
    translatedKeys++;
    translatedWords += _countWords(text);
    translatedCharacters += text.length;
  }

  void addCached(String text) {
    cachedKeys++;
    cachedWords += _countWords(text);
    cachedCharacters += text.length;
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  void printSummary() {
    print('');
    print('═══════════════════════════════════════════════════════════');
    print('                    TRANSLATION SUMMARY                    ');
    print('═══════════════════════════════════════════════════════════');

    if (translatedKeys > 0) {
      print('📝 TRANSLATED (new/changed content):');
      print('   Keys:       $translatedKeys');
      print('   Words:      $translatedWords');
      print('   Characters: $translatedCharacters');
    } else {
      print('📝 TRANSLATED: No new or changed content');
    }

    print('');

    if (cachedKeys > 0) {
      print('💾 CACHED (skipped, already translated):');
      print('   Keys:       $cachedKeys');
      print('   Words:      $cachedWords');
      print('   Characters: $cachedCharacters');
    } else {
      print('💾 CACHED: No cached content found');
    }

    print('');

    final totalKeys = translatedKeys + cachedKeys;
    final totalWords = translatedWords + cachedWords;
    final totalCharacters = translatedCharacters + cachedCharacters;

    if (totalKeys > 0) {
      print('📊 TOTALS:');
      print('   Keys:       $totalKeys');
      print('   Words:      $totalWords');
      print('   Characters: $totalCharacters');

      final cacheEfficiency = totalKeys > 0 ? (cachedKeys / totalKeys * 100).toStringAsFixed(1) : '0.0';
      print('   Cache efficiency: $cacheEfficiency% ($cachedKeys/$totalKeys keys from cache)');
    }

    print('═══════════════════════════════════════════════════════════');
  }
}
