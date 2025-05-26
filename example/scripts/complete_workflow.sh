#!/bin/bash

# Smart ARB Translator - Complete Workflow Demo
# Demonstrates advanced features and customization options

set -e

echo "🌟 Smart ARB Translator - Advanced Complete Workflow"
echo "===================================================="

# Navigate to the example Flutter app directory
cd "$(dirname "$0")/../flutter_app"

echo "📁 Working directory: $(pwd)"

# Ensure API key exists
if [ ! -f "api_key.txt" ]; then
    echo "📝 Creating API key file..."
    echo "ENTER_API_KEY_HERE" > api_key.txt
fi

echo "🔧 Configuration:"
echo "   Source: lib/l10n/app_en.arb"
echo "   Languages: Spanish, French, German, Japanese, Korean, Chinese"
echo "   Class Name: AppLocalizations"
echo "   Output: lib/generated/"
echo "   Features: Smart Translation + Dart Code Generation"

# Navigate back to root
cd ../../

echo ""
echo "🚀 Starting complete workflow..."

# Run with extensive language support
dart bin/translate.dart \
  --source_dir example/flutter_app/lib/l10n \
  --api_key example/flutter_app/api_key.txt \
  --language_codes es,fr,de,ja,ko,zh \
  --generate_dart \
  --dart_class_name AppLocalizations \
  --dart_output_dir example/flutter_app/lib/generated \
  --dart_main_locale en \
  --cache_directory example/flutter_app/.translation_cache \
  --l10n_directory example/flutter_app/lib/l10n

echo ""
echo "✅ Workflow completed!"
echo ""
echo "📊 Results:"
echo "   ✓ Translated to 6 languages"
echo "   ✓ Generated type-safe Dart code"
echo "   ✓ Ready for Flutter integration"
echo ""
echo "🔍 Check these directories:"
echo "   - example/flutter_app/lib/l10n/ (merged ARB files)"
echo "   - example/flutter_app/lib/generated/ (Dart code)"
echo "   - example/flutter_app/.translation_cache/ (cache for future runs)"
echo ""
echo "🎯 Next steps:"
echo "   1. cd example/flutter_app"
echo "   2. flutter pub get"
echo "   3. Update lib/main.dart to use generated localizations"
echo "   4. flutter run"
echo ""
echo "🌍 Your app now supports: English, Spanish, French, German, Japanese, Korean, Chinese!" 