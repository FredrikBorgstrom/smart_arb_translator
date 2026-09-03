# Smart ARB Translator

A command-line utility for translating ARB (Application Resource Bundle) files using Google Translate, OpenAI, a local LLM, or multi-agent Codex. This package features smart change detection that only translates messages that have been added or changed. This will keep your translation costs to a minimum. A cost-saving end-to-end solution that translates your messages to Dart classes in the languages of your choice.

## 🚀 Features

- **Smart Change Detection**: Only translates modified or new content, saving API calls and time
- **Batch Processing**: Translate entire folders recursively or a single source file
- **Manual Translation Override**: Support for custom translations via `@x-translations` metadata
- **🆕 Dual Localization Support**: Choose between Flutter's built-in `gen-l10n` or `intl_utils` package
- **🤖 Auto-Configuration**: Automatically detects and configures your preferred localization method
- **📝 Intelligent Setup**: Creates `l10n.yaml` or configures `pubspec.yaml` automatically
- **🔧 Dart Code Generation**: Generate ready-to-use Dart localization code with either method or simply translate and use your own dart generator
- **⚙️ Pubspec.yaml Configuration**: Configure all parameters directly in your `pubspec.yaml` file
- **🆕 Translation Services**: Support for Google Translate v2 (Basic & NMT), Google v3 (LLM), OpenAI, local OpenAI-compatible models, and independently verified multi-agent Codex translations
- **🆕 Translation Context**: Optional LLM context prompt (inline or file-based) for domain-specific tone/terminology
- **🧹 Corrupted Cache Recovery**: Remove only known-bad cached translations from buggy package versions without deleting the whole cache
- **⚡ Parallel Translation Requests (1.8.0)**: Optionally issue multiple per-language translation calls in parallel to dramatically reduce wall-clock time for projects targeting many locales. Defaults to `1` to preserve the original strictly-sequential behavior.
- **Stats**: Gives you full statistics on the number of translations made


## 📦 Installation

### Global Installation (Recommended)

```bash
dart pub global activate smart_arb_translator
```

### Local Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  smart_arb_translator: ^1.10.0
```

Then run:

```bash
dart pub get
```

## 🚀 Quick Start

### 1. Get a Google Translate API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Translate API
4. Create credentials (API Key)
5. Save your API key to a text file (e.g., `api_key.txt`)

### 2. Auto-Configuration (NEW!)

Run without any configuration for a guided setup:

```bash
dart run smart_arb_translator
```

The tool will automatically prompt you to configure (hit `ENTER` key for default values):
- **Source type**: Directory or single file
- **Source path**: With smart defaults (lib/l10n_source for directories)
- **Source locale**: With 'en' as default
- **Translation service**: Google Basic/NMT (v2), Google LLM (v3), OpenAI, a local LLM, or Codex
- **Authentication mode**:
  - `api_key` for v2 (and legacy v3 mode)
  - `adc` for Google LLM with Application Default Credentials
  - `service_account` for Google LLM with a JSON key file
- **Cache directory**: For translation cache (default: lib/l10n_cache)
- **Output directory**: For translated ARB files (default: lib/l10n)
- **Generation method**: Choose between gen-l10n, intl_utils, or none

All choices are automatically saved to `pubspec.yaml` for future runs.

**Example Auto-Configuration Session:**
```
🔧 Auto-configuration: No source configuration found.
Let's set up your project configuration.

What type of source do you want to translate?
1. Directory (contains multiple ARB files)
2. Single file (one ARB file)

Enter your choice (1 for directory, 2 for file): 1

Enter the directory path containing your ARB files (default: lib/l10n_source): 

What is the locale of your source files? (default: en): 

Which translation service do you want to use?
1. Google Basic (v2) - Default
   - Standard translation service
2. Google NMT (v2 with model=nmt)
   - Neural Machine Translation model
3. Google LLM (v3)
   - Large Language Model translation (requires Project ID)
4. OpenAI
   - OpenAI chat model translation with optional context
5. Local LLM
   - Local OpenAI-compatible model such as Ollama or LM Studio
6. Codex
   - Signed-in Codex CLI with parallel translation and independent verification

Enter your choice (1, 2, 3, 4, 5, or 6) [default: 1]: 1

Enter the path to your Google Translate API key file: secrets/api_key.txt

Enter the cache directory for translations (default: lib/l10n_cache): 

Enter the output directory for translated ARB files (default: lib/l10n): 

Do you want to generate Dart localization code?
1. Yes, using gen-l10n (Flutter built-in)
2. Yes, using intl_utils (Third-party package)
3. No, only translate ARB files

Enter your choice (1 for gen-l10n, 2 for intl_utils, 3 for none): 2

💾 Saved configuration to pubspec.yaml
✅ Auto-configuration completed!
```

### Optional: Configure in pubspec.yaml

Add your configuration directly to `pubspec.yaml`:

```yaml
# pubspec.yaml
smart_arb_translator:
  source_dir: lib/l10n
  api_key: secrets/google_translate_api_key.txt
  language_codes: [es, fr, de, ja]
  generate_dart: true
  dart_class_name: AppLocalizations
```

Then run without any arguments:

```bash
dart run smart_arb_translator
```

### 3. Repair Corrupted Cache Entries

If you previously ran a buggy version that cached broken ICU or parameterized translations, you can remove only the bad cache entries instead of deleting the whole cache:

```bash
dart run smart_arb_translator --clean-corrupted-cache --dry-run
```

If the dry run looks correct, apply the cleanup:

```bash
dart run smart_arb_translator --clean-corrupted-cache
```

To clean only specific locales:

```bash
dart run smart_arb_translator --clean-corrupted-cache --language_codes ar,sv
```

How it works:
- Removes only cached translations that match known corruption patterns from earlier package bugs
- Keeps valid cached translations intact
- Uses `cache_directory` from your CLI or `pubspec.yaml` configuration
- Uses `language_codes` only as an optional cleanup filter in this mode

Typical recovery flow:
1. Run `--clean-corrupted-cache --dry-run`
2. Run `--clean-corrupted-cache`
3. Run `smart_arb_translator` normally to refill only the missing translations

### 4. One-Command Translation + Code Generation

```bash
# Complete Flutter i18n workflow in one command
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de,ja \
  --generate_dart \
  --dart_class_name AppLocalizations
```

This single command will:
- ✅ Translate your ARB files to multiple languages
- ✅ Generate type-safe Dart localization code
- ✅ Set up everything for Flutter integration

### 5. Use in Your Flutter App

```dart
import 'lib/generated/l10n.dart';

// In your MaterialApp
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ... rest of your app
)

// In your widgets
Text(AppLocalizations.of(context).yourTranslationKey)
```

## 🔧 Setup

### 1. Google Translate API Key

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the Google Translate API
4. Create credentials (API Key)
5. Save your API key to a text file (e.g., `api_key.txt`)

### 2. Google LLM (v3) Authentication

For `translation_service: google_llm`, Google Cloud Translation Advanced v3 is used.
`translation-llm` is called in the `us-central1` location.

Structured Google LLM requests preserve a resource identity through an opaque
request label and send a plain whole resource only when it contains no ARB
interpolation or ICU syntax. ICU/placeholder values remain on the established
action projection. Google Basic/NMT expose only the translatable `q` field, so
the package deliberately keeps descriptions and prompt context out of that
field; embedding them would leak translated metadata into the UI. Their local
resource identity/provenance remains keyed and deterministic.

- `auth_mode: adc` (recommended for local dev):
  - Run `gcloud auth application-default login`
  - Optional but recommended: `gcloud auth application-default set-quota-project YOUR_PROJECT_ID`
- `auth_mode: service_account`:
  - Create a service account with `roles/cloudtranslate.user`
  - Download JSON key and set `credentials_file: path/to/service-account.json`
- `auth_mode: api_key`:
  - Kept for backward compatibility
  - Google v3 typically expects OAuth credentials

### 3. OpenAI Authentication

For `translation_service: openai`, set `api_key` to your OpenAI API key (or a file containing the key).

Optional OpenAI settings:
- `openai_model`: e.g. `gpt-4o-mini`, `gpt-4.1-mini`
- `translation_context`: inline translation guidance
- `translation_context_file`: path to a text/markdown file with translation context

### 4. Local LLM

Use `translation_service: local_llm` with any local runtime that exposes an
OpenAI-compatible chat-completions endpoint. This includes Ollama, LM Studio,
llama.cpp, and vLLM.

No API key is required. If a self-hosted endpoint requires bearer
authentication, the existing optional `api_key` setting is sent as a bearer
token.

Example for Ollama:

```yaml
smart_arb_translator:
  translation_service: local_llm
  local_llm_url: http://127.0.0.1:11434/v1/chat/completions
  local_llm_model: qwen3.5:27b
  local_llm_json_mode: true
  local_llm_timeout_seconds: 600
  local_llm_max_output_tokens: 2048
  local_llm_reasoning_effort: none # optional; none, low, medium, or high
  local_llm_profile: openai_chat_json # or translategemma
  parallel_translations: 1
```

`translategemma` uses its translation-only contract, sends one ARB resource per
request, maps `fil` to `fil-PH`, and never falls back to a paid provider. It is
intended for an explicitly configured local model; the package never downloads
or starts one. `local_llm_max_output_tokens` prevents local reasoning models
from consuming the entire request timeout before returning a translation.
`local_llm_reasoning_effort` is optional because some compatible runtimes do
not implement it.

An optional local smoke test is excluded by default: set
`SMART_ARB_LOCAL_SMOKE_MODEL` (and optionally URL/profile) then run
`dart test -t local-smoke --run-skipped`.

### 5. Codex

Use `translation_service: codex` to run translations through the locally
installed and signed-in Codex CLI. No translation API key is required. Each
request runs in an ephemeral read-only workspace with a schema-constrained
response. The root agent must launch independent primary and verification
agents in parallel and adjudicate disagreements; failures never fall back to a
different provider.

See the official Codex documentation for
[non-interactive execution](https://learn.chatgpt.com/docs/non-interactive-mode),
[subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), and
the [agent concurrency setting](https://learn.chatgpt.com/docs/config-file/config-reference).

```yaml
smart_arb_translator:
  translation_service: codex
  codex_executable: codex       # Or an absolute executable path
  codex_model: gpt-5.6-sol      # Optional; omit to use the Codex default
  codex_reasoning_effort: high  # Optional
  codex_timeout_seconds: 900
  codex_max_agents: 3           # Minimum 2 for independent verification
  parallel_translations: 2      # Concurrent locale-level Codex runs
  translation_context_file: docs/translation_context.md
```

`codex_max_agents` is passed to Codex's
`agents.max_concurrent_threads_per_session` setting and controls child-agent
concurrency within one locale job;
`parallel_translations` controls how many locale jobs the translator launches
at once. Keep the product of those settings within the capacity of the signed-in
Codex environment.

For Codex-reviewed projects, configure `reviewed_translations_dir` and run with
`manual_only: true` (or `--offline`). Reviewed ledgers must minimally pair each
ARB value with `source`, `translation`, `sourceFingerprint`, and
`contextFingerprint`; review workflow ledgers additionally require primary and
verification verdicts. Provider/model changes invalidate automatic cache data,
not reviewed translations.

`LocalizationValidator.validatePair` treats unchanged short controls such as
`Back`, `Clear`, and `Background` as suspicious for non-English targets.
Consumers can pass `passthroughAllowlist` with an ARB key or literal
brand/technical token such as `ABCx3` when it is intentionally unchanged.

Before a manual-only merge, validate every English/reviewed feature pair with
the zero-network quality driver:

```bash
dart run tool/reviewed_overlay_quality.dart \
  --source-dir lib/l10n_source/en \
  --reviewed-dir lib/l10n_reviewed \
  --allowlist-file tool/localization/passthrough_allowlist.json
```

The optional allowlist is a JSON array, or an object whose `entries`, `keys`,
`literals`, or `global` arrays contain explicitly reviewed exceptions. Use a
`locales` object of locale-to-array entries for natural cognates or technical
text that is valid only in a specific target locale. These exceptions suppress
only passthrough/mixed-script findings for the named key or exact value; they
never suppress ownership, ICU, placeholder, commentary, or empty-value errors.
The command checks
feature/key ownership, locale declarations, ARB/ICU syntax, placeholders,
plural/select structure, empty values, commentary, source passthrough, scripts,
and length without constructing a translation service or making an HTTP call.

The local server and configured model must already be available. Smart ARB
Translator never downloads or selects a model automatically. Keep
`parallel_translations: 1` unless the local runtime can load and execute
multiple model requests safely.

### Local-model benchmark

Run the explicitly invoked benchmark tool only after a local model is already
installed and serving an OpenAI-compatible endpoint:

```bash
dart run tool/local_model_benchmark.dart \
  --input benchmark_corpus.json \
  --output benchmark_results_qwen2.5_32b.json \
  --model qwen2.5:32b \
  --endpoint http://127.0.0.1:11434/v1/chat/completions \
  --profile openai_chat_json \
  --locale fr --locale ar
```

The tool never downloads, starts, or chooses a model; it uses only
`translation_service: local_llm` with no provider fallback. Locales always run
sequentially. The generic `openai_chat_json` profile sends one keyed resource
batch per locale; `translategemma` retains its translation-only one-resource
internal requests. Results are ordered JSON with model/profile/endpoint-class
provenance, honest per-locale batch elapsed milliseconds, English/translation
pairs, and deterministic validation findings.

The supported benchmark corpus is a generic superset of ABCx3's schema:

```json
{
  "schema_version": 1,
  "locales": ["fr", "ar"],
  "resources": [{
    "id": "back",
    "source": "Back",
    "source_topic": "ui.arb",
    "description": "Navigation action",
    "placeholders": {},
    "icu_variables": [],
    "icu_roles": [],
    "icu_branches": [],
    "ui_role": "navigation_action",
    "screen_context": "game setup",
    "neighboring_terms": ["Next"],
    "glossary": {"board": "game board"},
    "locales": ["fr", "ar"]
  }]
}
```

`source_text` is an accepted alias for `source`; resource `locales` narrows
the top-level locales. Extra corpus fields are ignored rather than sent to the
model. Use `--help` to inspect the complete CLI without contacting a server.

ABCx3's checked-in corpus is accepted without conversion: use top-level
`schemaVersion`, `targetLocales`, and `cases`; each case maps `key` to the ARB
resource id, `feature` to source topic, and its `targetLocales` to the resource
locale subset. The original case `id` is retained as `case_id` in results.

### 5. ARB File Structure

Ensure your ARB files follow the standard format:

```json
{
  "@@locale": "en",
  "@@last_modified": "2024-01-01T00:00:00.000Z",
  "hello": "Hello",
  "@hello": {
    "description": "A greeting message"
  },
  "welcome": "Welcome {name}!",
  "@welcome": {
    "description": "Welcome message with name placeholder",
    "placeholders": {
      "name": {
        "type": "String"
      }
    }
  }
}
```

## 🎯 Usage

### Configuration Methods

Smart ARB Translator supports two configuration methods:

1. **Command Line Arguments** (Traditional)
2. **pubspec.yaml Configuration** (NEW! - Recommended)

### pubspec.yaml Configuration (Recommended)

Configure all parameters directly in your `pubspec.yaml` file under the `smart_arb_translator` section:

```yaml
# pubspec.yaml
name: my_flutter_app
description: My Flutter application

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  smart_arb_translator: ^1.9.0

# Smart ARB Translator Configuration
smart_arb_translator:
  # Source configuration (choose one)
  source_dir: lib/l10n                    # Directory containing ARB files
  # source_arb: lib/l10n/app_en.arb       # Single ARB file (alternative)
  
  # Required for google_basic/google_nmt, openai, and google_llm with auth_mode=api_key
  api_key: secrets/google_translate_api_key.txt
  
  # Target languages (multiple formats supported)
  language_codes: [es, fr, de, it, pt, ja]  # YAML list format
  # language_codes: "es,fr,de,it,pt,ja"    # Comma-separated string format
  
  # Output configuration
  cache_directory: lib/l10n_cache          # Translation cache directory
  l10n_directory: lib/l10n                 # Output directory for merged files
  output_file_name: app                    # Prefix for output files
  
  # Dart code generation
  generate_dart: true                      # Generate Dart localization code
  dart_class_name: AppLocalizations        # Name for generated class
  dart_output_dir: lib/generated           # Directory for generated Dart files
  dart_main_locale: en                     # Main locale for code generation
  
  # Localization method (auto-detected if not specified)
  l10n_method: gen-l10n                    # Options: "gen-l10n", "intl_utils", or "none"
  
  # Translation Service Configuration
  translation_service: openai                # Options: "google_basic", "google_nmt", "google_llm", "openai", "local_llm", "codex"
  project_id: my-gcp-project-id              # Required for "google_llm"
  auth_mode: api_key                         # Options: "api_key", "adc", "service_account" (openai requires "api_key")
  credentials_file: secrets/service-account.json   # Required when auth_mode=service_account
  quota_project_id: my-billing-project-id    # Optional for OAuth requests (x-goog-user-project)
  openai_model: gpt-4o-mini                  # Optional, used when translation_service=openai
  # codex_executable: codex                   # Used when translation_service=codex
  # codex_model: gpt-5.6-sol                  # Optional; defaults to the Codex configuration
  # codex_reasoning_effort: high              # Optional model reasoning override
  # codex_timeout_seconds: 900
  # codex_max_agents: 3                       # Minimum 2 for independent verification
  # local_llm_url: http://127.0.0.1:11434/v1/chat/completions
  # local_llm_model: qwen3.5:27b              # Required when translation_service=local_llm
  # local_llm_json_mode: true                 # Disable for endpoints that reject response_format
  # local_llm_timeout_seconds: 600            # Local inference can be slower than a hosted API
  # local_llm_profile: openai_chat_json        # or translategemma
  # reviewed_translations_dir: lib/l10n_reviewed
  # manual_only: true
  translation_context: Keep product terms in English
  translation_context_file: docs/translation_context.md

  # Performance
  parallel_translations: 4                 # Send up to N per-language translation requests in parallel
                                           # (default: 1 = strictly sequential, the original behavior)
  
  # Automation
  auto_approve: false                      # Auto-approve pubspec.yaml modifications
```

#### Benefits of pubspec.yaml Configuration:

- ✅ **Version Control Friendly**: Configuration is committed with your code
- ✅ **Team Consistency**: Everyone uses the same settings
- ✅ **No Command Memorization**: Simple `smart_arb_translator` command
- ✅ **IDE Integration**: Better tooling support
- ✅ **Cleaner CI/CD**: Simplified build scripts

#### Usage with pubspec.yaml:

```bash
# Simple command - all configuration from pubspec.yaml
smart_arb_translator

# Override specific parameters if needed
smart_arb_translator --language_codes es,fr --generate_dart false

# CLI arguments take precedence over pubspec.yaml settings
```

### Command Line Interface

#### Translate a Directory

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key path/to/api_key.txt \
  --language_codes es,fr,de,it \
  --cache_directory lib/l10n_cache \
  --l10n_directory lib/l10n
```

#### Translate a Single File

```bash
smart_arb_translator \
  --source_arb lib/l10n/app_en.arb \
  --api_key path/to/api_key.txt \
  --language_codes es,fr \
  --output_file_name app
```

#### Complete Translation + Dart Code Generation (NEW!)

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key path/to/api_key.txt \
  --language_codes es,fr,de,it \
  --generate_dart \
  --dart_class_name AppLocalizations \
  --dart_output_dir lib/generated
```

#### Google LLM (v3) with ADC (no API key)

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --language_codes es,fr,de,it \
  --translation_service google_llm \
  --project_id your-gcp-project-id \
  --auth_mode adc \
  --generate_dart
```

#### OpenAI with Translation Context

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --translation_service openai \
  --api_key secrets/openai_api_key.txt \
  --openai_model gpt-4o-mini \
  --translation_context "Use gaming terminology from our style guide. Keep item names in English." \
  --translation_context_file docs/translation_context.md \
  --language_codes es,fr,de
```

#### Local LLM with Translation Context

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --translation_service local_llm \
  --local_llm_url http://127.0.0.1:11434/v1/chat/completions \
  --local_llm_model qwen3.5:27b \
  --translation_context_file docs/translation_context.md \
  --local_llm_timeout_seconds 600 \
  --parallel_translations 1 \
  --language_codes es,fr,de
```

The URL may also be a server root such as `http://localhost:1234` or an
OpenAI-style `/v1` base URL; Smart ARB Translator normalizes either form to
`/v1/chat/completions`. Use `--no-local_llm_json_mode` only when a compatible
server rejects the `response_format` request field.

#### Codex with Independent Agent Verification

```bash
smart_arb_translator \
  --source_dir lib/l10n \
  --translation_service codex \
  --codex_model gpt-5.6-sol \
  --codex_reasoning_effort high \
  --codex_max_agents 3 \
  --translation_context_file docs/translation_context.md \
  --parallel_translations 2 \
  --language_codes es,fr,de
```

### Command Line Options

All options can be configured in `pubspec.yaml` under the `smart_arb_translator` section. CLI arguments take precedence over pubspec.yaml settings.

| Option | Description | Default | pubspec.yaml key |
|--------|-------------|---------|------------------|
| `--source_dir` | Source directory containing ARB files | - | `source_dir` |
| `--source_arb` | Single ARB file to translate | - | `source_arb` |
| `--api_key` | Path to API key file; optional bearer token for `local_llm` | Required for `google_basic`, `google_nmt`, `openai`, and `google_llm` with `auth_mode=api_key` | `api_key` |
| `--language_codes` | Comma-separated target language codes | `es` | `language_codes` |
| `--cache_directory` | Directory for translation cache | `lib/l10n_cache` | `cache_directory` |
| `--l10n_directory` | Output directory for merged files | `lib/l10n` | `l10n_directory` |
| `--output_file_name` | Custom output filename | `intl_` | `output_file_name` |
| `--generate_dart` | Generate Dart localization code | `false` | `generate_dart` |
| `--l10n_method` | Localization method: `gen-l10n`, `intl_utils`, or `none` | Auto-detect | `l10n_method` |
| `--dart_class_name` | Name for generated localization class | `S` | `dart_class_name` |
| `--dart_output_dir` | Directory for generated Dart files | `lib/generated` | `dart_output_dir` |
| `--dart_main_locale` | Main locale for Dart code generation | `en` | `dart_main_locale` |
| `--auto_approve` | Auto-approve configuration changes | `false` | `auto_approve` |
| `--use_deferred_loading` | Enable deferred loading for locales (Flutter Web optimization) | `false` | `use_deferred_loading` |
| `--translation_service` | Translation service: `google_basic`, `google_nmt`, `google_llm`, `openai`, `local_llm`, or `codex` | `google_basic` | `translation_service` |
| `--project_id` | Google Cloud Project ID (required for `google_llm`) | - | `project_id` |
| `--auth_mode` | Auth mode: `api_key`, `adc`, or `service_account` | `api_key` | `auth_mode` |
| `--credentials_file` | Path to service account JSON key file (required for `service_account`) | - | `credentials_file` |
| `--quota_project_id` | Optional quota/billing project id for OAuth requests | - | `quota_project_id` |
| `--openai_model` | OpenAI model to use when `translation_service=openai` | `gpt-4o-mini` | `openai_model` |
| `--codex_executable` | Codex CLI executable name or absolute path | `codex` | `codex_executable` |
| `--codex_model` | Optional Codex model override | Signed-in Codex default | `codex_model` |
| `--codex_reasoning_effort` | Optional Codex reasoning effort override | Signed-in Codex default | `codex_reasoning_effort` |
| `--codex_timeout_seconds` | Timeout for one Codex orchestration run | `900` | `codex_timeout_seconds` |
| `--codex_max_agents` | Maximum active child agents in a Codex job; minimum 2 | `3` | `codex_max_agents` |
| `--local_llm_url` | OpenAI-compatible local chat-completions endpoint or base URL | `http://127.0.0.1:11434/v1/chat/completions` | `local_llm_url` |
| `--local_llm_model` | Model identifier exposed by the local runtime; required for `local_llm` | - | `local_llm_model` |
| `--[no-]local_llm_json_mode` | Request JSON mode through `response_format` | `true` | `local_llm_json_mode` |
| `--local_llm_timeout_seconds` | Timeout for one local inference request | `600` | `local_llm_timeout_seconds` |
| `--local_llm_max_output_tokens` | Maximum completion tokens returned by one local request | `2048` | `local_llm_max_output_tokens` |
| `--local_llm_reasoning_effort` | Optional local reasoning control: `none`, `low`, `medium`, or `high` | - | `local_llm_reasoning_effort` |
| `--local_llm_profile` | `openai_chat_json` (default) or translation-only `translategemma` | `openai_chat_json` | `local_llm_profile` |
| `--translation_context` | Optional context text for LLM translation style/tone | - | `translation_context` |
| `--translation_context_file` | Optional file with context text for LLM translations | - | `translation_context_file` |
| `--parallel_translations` | Maximum number of per-language translation requests sent in parallel for a single source ARB file. Higher values speed up large language lists at the cost of more concurrent requests against the translation provider. | `1` | `parallel_translations` |
| `--reviewed_translations_dir` | Root containing `<locale>/<feature>.arb` and `<feature>.review.json` overlays | - | `reviewed_translations_dir` |
| `--manual_only`, `--offline`, `--manual` | Never call a provider; fail with exact missing coverage | `false` | `manual_only` |
| `--merge_reviewed_only` | Generate only from x-translations, reviewed overlays, or valid cache | `false` | - |
| `--validate_only` | Validate ARB syntax/locale metadata and exit without credentials or network | `false` | - |
| `--list_stale_reviewed` | List source keys without a current reviewed overlay | `false` | - |
| `--dry_run_network_plan` | Print a no-network provider-plan summary and exit | `false` | - |
| `--locale`, `--source_file`, `--key` | Limit processing to selected locales, feature ARBs, or message keys | - | - |


### Configuration Precedence

When both pubspec.yaml configuration and CLI arguments are provided, the precedence is:

1. **CLI Arguments** (Highest priority)
2. **pubspec.yaml Configuration**
3. **Default Values** (Lowest priority)

#### Example:

```yaml
# pubspec.yaml
smart_arb_translator:
  language_codes: [es, fr, de]
  generate_dart: true
```

```bash
# This command will use:
# - language_codes: [it, pt] (from CLI - overrides pubspec.yaml)
# - generate_dart: true (from pubspec.yaml)
smart_arb_translator --language_codes it,pt
```

### Programmatic Usage

```dart
import 'package:smart_arb_translator/smart_arb_translator.dart';

void main() async {
  // Load configuration from pubspec.yaml
  final config = PubspecConfig.loadFromPubspec();
  if (config != null) {
    print('Loaded config: ${config.sourceDir}');
  }
  
  // Create translation service
  final translationService = TranslationService();
  
  // Translate texts
  final translations = await translationService.translateTexts(
    translateList: ['Hello', 'World'],
    parameters: {'target': 'es', 'key': 'your-api-key'},
  );
  
  print(translations); // ['Hola', 'Mundo']
}
```

## 🎨 Advanced Features

### 🔄 Dual Localization Method Support

Smart ARB Translator supports both Flutter's official localization solution and the popular third-party package:

#### **Flutter gen-l10n (Official)**
- ✅ Official Flutter solution
- ✅ Uses `l10n.yaml` configuration
- ✅ Runs `flutter gen-l10n` command
- ✅ Integrated with Flutter SDK

#### **intl_utils (Third-party)**
- ✅ More configuration options
- ✅ Uses `flutter_intl` section in `pubspec.yaml`
- ✅ Runs `dart run intl_utils:generate`
- ✅ Popular community package

#### **🤖 Intelligent Auto-Detection**

The tool automatically chooses the best method for your project:

1. **Existing `l10n.yaml`** → Uses `gen-l10n`
2. **Existing `intl_utils` setup** → Uses `intl_utils`
3. **Saved preference** → Uses your previous choice
4. **No setup found** → Prompts you to choose between `gen-l10n`, `intl_utils`, or `none` (or uses `intl_utils` with `--auto_approve`)

#### **Manual Method Selection**

```bash
# Force gen-l10n method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart \
  --l10n_method gen-l10n

# Force intl_utils method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart \
  --l10n_method intl_utils

# Skip Dart code generation (translation only)
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --l10n_method none
```

#### **🔧 Auto-Configuration**

The tool automatically sets up your project:

**For gen-l10n:**
- Creates `l10n.yaml` with proper configuration
- Sets up ARB directory and output paths
- Configures template file and class name

**For intl_utils:**
- Adds `intl_utils` to `dev_dependencies`
- Creates `flutter_intl` configuration in `pubspec.yaml`
- Sets up ARB directory and output paths

### Dart Code Generation Integration

Smart ARB Translator includes integrated Dart code generation with both methods, providing a complete end-to-end solution:

#### Benefits:
- **One Command Solution**: Translate and generate Dart code in a single step
- **Consistent Configuration**: Same settings for translation and code generation
- **Automatic Setup**: Handles `pubspec.yaml` configuration automatically
- **Type Safety**: Generated Dart code provides compile-time safety
- **IDE Support**: Full autocomplete and refactoring support
- **Performance**: Optimized for large projects with smart caching

#### Workflow Comparison:

**Before (Multiple Tools):**
```bash
# Step 1: Translate ARB files
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es,fr

# Step 2: Choose and configure localization method
# Option A: Setup gen-l10n manually
# - Create l10n.yaml
# - Configure paths and class names
# - Run: flutter gen-l10n

# Option B: Setup intl_utils manually  
# - Install: dart pub add dev:intl_utils
# - Configure pubspec.yaml flutter_intl section
# - Run: dart run intl_utils:generate
```

**After (Integrated Solution):**
```bash
# Single command does everything automatically
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr \
  --generate_dart
  
# The tool will:
# ✅ Translate your ARB files
# ✅ Auto-detect or prompt for localization method
# ✅ Configure l10n.yaml or pubspec.yaml automatically
# ✅ Generate type-safe Dart code
# ✅ Save your preference for future runs
```

### ⚡ Parallel Translation Requests

**Available since 1.8.0.**

By default the translator processes target languages strictly sequentially: the request for the next language is only issued after the current language has finished. For projects that target many locales (e.g. 20+ languages) this is the dominant component of wall-clock time, especially with LLM-backed services like OpenAI where a single language can take several seconds.

The `parallel_translations` option (CLI: `--parallel_translations`, pubspec key: `parallel_translations`) controls how many per-language translation requests are issued in parallel for a single source ARB file. Languages are processed in chunks of size N: each chunk runs concurrently via `Future.wait`, then the next chunk starts. Setting it to `1` (the default) reproduces the original strictly-sequential behavior.

#### When to enable it

- ✅ You translate to many languages (≥ 5–10) and the run is bottlenecked on per-language round-trips.
- ✅ Your translation provider can comfortably handle a few concurrent requests (Google Translate v2/v3 and OpenAI all do).
- ✅ You want shorter wall-clock time during local iteration or in CI.

#### When to keep it at 1

- ⚠️ You're hitting strict provider rate limits (e.g. low free-tier OpenAI accounts).
- ⚠️ You need fully deterministic, ordered log output across language batches.
- ⚠️ You depend on side effects between languages (the implementation is side-effect-free per language, but if you've forked the package and added stateful work, sequential execution may be safer).
- ⚠️ You use a local LLM that cannot execute multiple generations concurrently without memory pressure or severe slowdown.

#### Recommended values

| Setting | Description |
|---------|-------------|
| `1` (default) | Original strictly-sequential behavior. |
| `2`–`4` | Sweet spot for most projects. Significant speedup with negligible rate-limit risk. |
| `5`–`8` | Useful for very large language lists. Verify your provider's rate limits before going this high. |
| `>8` | Not recommended; gains taper off and you risk being throttled. |

#### Example: `pubspec.yaml`

```yaml
smart_arb_translator:
  source_dir: lib/l10n_source
  language_codes: [es, fr, de, it, pt, ja, ko, zh, ar, ru, sv, fi, da, nb, nl, pl, cs, hu]
  translation_service: openai
  api_key: secrets/openai_key.txt
  parallel_translations: 4
```

#### Example: CLI

```bash
smart_arb_translator --parallel_translations 4
```

#### Implementation notes

- Cross-language work is fully isolated: each language gets its own `ArbDocument` produced via `copyWith`, so concurrent runs do not share mutable state.
- The existing per-language behavior (smart change detection, action-list batching, OpenAI per-item fallback) is unchanged. Parallelism is layered above it.
- Languages within a chunk run concurrently; chunks themselves run sequentially. This caps the maximum number of in-flight requests at exactly `parallel_translations`, regardless of how many languages you configure.
- Total time scales roughly with `ceil(num_languages / parallel_translations)`. For 33 languages, `parallel_translations: 4` reduces 33 sequential round-trips to 9 sequential chunks of up to 4 parallel calls each.

### Manual Translation Overrides

You can provide manual translations that will override Google Translate results:

```json
{
  "greeting": "Hello",
  "@greeting": {
    "description": "A simple greeting",
    "@x-translations": {
      "es": "¡Hola!",
      "fr": "Salut!"
    }
  }
}
```

### Smart Change Detection

The tool automatically detects:
- New translation keys
- Modified source text
- Changed metadata/attributes
- Only translates what's necessary

### Batch Processing

Process entire directory structures:

```
lib/l10n/
├── common/
│   ├── app_en.arb
│   └── errors_en.arb
├── features/
│   ├── auth_en.arb
│   └── profile_en.arb
└── app_en.arb
```

All files will be processed recursively and organized in the output structure.

## 🔄 Integration with Flutter

### 1. Add to your Flutter project

```yaml
# pubspec.yaml
dev_dependencies:
  smart_arb_translator: ^1.9.0

flutter:
  generate: true
```

### 2. Translate and generate (Auto-configures for you!)

```bash
# Complete workflow: Translate ARB files + Generate Dart code
# The tool will automatically configure your preferred localization method
smart_arb_translator \
  --source_dir lib/l10n \
  --api_key api_key.txt \
  --language_codes es,fr,de \
  --generate_dart \
  --dart_class_name AppLocalizations

# This will create either:
# - l10n.yaml (for gen-l10n method) OR
# - flutter_intl config in pubspec.yaml (for intl_utils method)
```

### 3. Manual configuration (Optional)

If you prefer manual setup, you can configure either method:

**Option A: gen-l10n (Flutter official)**
```yaml
# l10n.yaml (created automatically by smart_arb_translator)
arb-dir: lib/l10n
template-arb-file: intl_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated
```

**Option B: intl_utils (Third-party)**
```yaml
# pubspec.yaml (configured automatically by smart_arb_translator)
flutter_intl:
  enabled: true
  class_name: AppLocalizations
  main_locale: en
  arb_dir: lib/l10n
  output_dir: lib/generated
  use_deferred_loading: false
```

### 4. Use in your Flutter app

```dart
import 'package:flutter/material.dart';
import 'lib/generated/l10n.dart'; // Generated by smart_arb_translator

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appTitle),
      ),
      body: Center(
        child: Text(AppLocalizations.of(context).welcomeMessage),
      ),
    );
  }
}
```

## 🛠️ Development

### Project Structure

```
lib/
├── smart_arb_translator.dart          # Main library export
└── src/
    ├── argument_parser.dart           # CLI argument handling
    ├── arb_processor.dart            # ARB file processing
    ├── console_utils.dart            # Console utilities
    ├── directory_processor.dart      # Directory operations
    ├── file_operations.dart          # File utilities
    ├── single_file_processor.dart    # Single file processing
    ├── translation_service.dart      # Google Translate API
    ├── utils.dart                    # General utilities
    ├── icu_parser.dart              # ICU message parsing
    └── models/
        ├── arb_attributes.dart       # ARB metadata model
        ├── arb_document.dart         # ARB document model
        └── arb_resource.dart         # ARB resource model
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

### Running Tests

```bash
dart test
```

## 📝 Language Codes

Supported language codes include:

| Code | Language | Code | Language |
|------|----------|------|----------|
| `es` | Spanish | `fr` | French |
| `de` | German | `it` | Italian |
| `pt` | Portuguese | `ru` | Russian |
| `ja` | Japanese | `ko` | Korean |
| `zh` | Chinese | `ar` | Arabic |

[Full list of supported languages](https://cloud.google.com/translate/docs/languages)

## 🐛 Troubleshooting

### Common Issues

1. **API Key Error**: Ensure your API key file exists and contains a valid key
2. **Permission Error**: Check file permissions for source and output directories
3. **Invalid ARB**: Validate your ARB files are properly formatted JSON
4. **Network Error**: Check internet connection and API quotas

### Debug Mode

Add `--verbose` flag for detailed logging:

```bash
smart_arb_translator --source_dir lib/l10n --api_key api_key.txt --language_codes es --verbose
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

This project was originally inspired by and forked from [justkawal/arb_translator](https://github.com/justkawal/arb_translator). We're grateful for the foundation provided by the original work.

### What's New in Smart ARB Translator:
- 🧠 **Smart Change Detection**: Only translates modified content
- 🏗️ **Modular Architecture**: Complete refactor for maintainability  
- ⚡ **Enhanced Performance**: Optimized for large projects
- 📚 **Professional Documentation**: Comprehensive guides and examples
- 🔧 **Better Developer Experience**: Improved CLI and programmatic API

### Original Project Credits:
- **Original Author**: [Kawal Jeet](https://github.com/justkawal)
- **Original Repository**: [arb_translator](https://github.com/justkawal/arb_translator)
- **License**: MIT (maintained in this project)

Built with ❤️ for the Flutter community

## 📞 Support

- 🐛 [Report Issues](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 💡 [Feature Requests](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
- 📖 [Documentation](https://github.com/FredrikBorgstrom/smart_arb_translator#readme)

---

Made with ❤️ for the Flutter community

[![Pub Version](https://img.shields.io/pub/v/smart_arb_translator.svg)](https://pub.dev/packages/smart_arb_translator)
[![Pub Points](https://img.shields.io/pub/points/smart_arb_translator)](https://pub.dev/packages/smart_arb_translator/score)
[![Popularity](https://img.shields.io/pub/popularity/smart_arb_translator)](https://pub.dev/packages/smart_arb_translator/score)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/FredrikBorgstrom/smart_arb_translator?style=social)](https://github.com/FredrikBorgstrom/smart_arb_translator)
[![GitHub Issues](https://img.shields.io/github/issues/FredrikBorgstrom/smart_arb_translator)](https://github.com/FredrikBorgstrom/smart_arb_translator/issues)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/FredrikBorgstrom/smart_arb_translator)](https://github.com/FredrikBorgstrom/smart_arb_translator/commits/main)
