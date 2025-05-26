#!/bin/bash

# Smart ARB Translator - Complete Workflow Test
# This script demonstrates the full translation + Dart code generation workflow

set -e  # Exit on any error

echo "🚀 Smart ARB Translator - Complete Workflow Test"
echo "=================================================="

# Navigate to the example Flutter app directory
cd "$(dirname "$0")/../flutter_app"

echo "📁 Current directory: $(pwd)"
echo "📋 Testing with provided API key..."

# Check if API key file exists
if [ ! -f "api_key.txt" ]; then
    echo "❌ API key file not found. Creating it..."
    echo "ENTER_API_KEY_HERE" > api_key.txt
fi

echo "✅ API key file ready"

# Check if source ARB file exists
if [ ! -f "lib/l10n/app_en.arb" ]; then
    echo "❌ Source ARB file not found at lib/l10n/app_en.arb"
    exit 1
fi

echo "✅ Source ARB file found"

# Run the complete workflow: Translation + Dart code generation
echo ""
echo "🔄 Running Smart ARB Translator with complete workflow..."
echo "   Languages: Spanish, French, German, Japanese"
echo "   Features: Translation + Dart Code Generation"
echo ""

# Navigate back to the root directory to run the command
cd ../../

dart bin/translate.dart \
  --source_dir example/flutter_app/lib/l10n \
  --api_key example/flutter_app/api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --dart_class_name AppLocalizations \
  --dart_output_dir example/flutter_app/lib/generated \
  --dart_main_locale en \
  --l10n_directory example/flutter_app/lib/l10n

echo ""
echo "🎉 Test completed successfully!"
echo ""
echo "📂 Generated files:"
echo "   - example/flutter_app/lib/l10n/intl_*.arb (translated ARB files)"
echo "   - example/flutter_app/lib/generated/ (Dart localization code)"
echo ""
echo "📱 To test the Flutter app:"
echo "   1. cd example/flutter_app"
echo "   2. flutter pub get"
echo "   3. Uncomment the localization imports in lib/main.dart"
echo "   4. flutter run"
echo ""
echo "✨ Happy translating!" 