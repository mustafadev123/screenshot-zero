Screenshot Zero 1.2.0 — OCR implementation and phone verification

The existing Digital Darkroom screens now receive locally recognized text and
structured metadata from real imported screenshots. The five supplied images
were read with Windows.Media.Ocr for diagnostics; their actual transcripts pass
the deterministic classifier regressions. This is not a claim that Android ML
Kit has been run on these images: no Android device/emulator was connected.

Packages and platform configuration

- Reused existing google_mlkit_text_recognition ^0.15.0, resolved 0.15.1, and
  google_mlkit_commons 0.11.1. No runtime package added.
- Added Flutter SDK integration_test as a development dependency.
- Kept Flutter 3.47.4 / Dart 3.13.3, Android min SDK 24 / target 36, Java 17,
  signing configuration and existing Latin-only R8 configuration.
- Android uses bundled com.google.mlkit:text-recognition:16.0.1. It needs no
  first-use model download. Only Latin recognition is enabled.
- AndroidManifest.xml was not modified and no permissions were added.
  The existing merged release manifest includes INTERNET, ACCESS_NETWORK_STATE,
  POST_NOTIFICATIONS, VIBRATE and the app's signature-protected dynamic receiver
  permission. Network-capable ML Kit transport dependencies already existed.
  The app introduces no upload/API/backend code; OCR uses the local file.
- Existing external-action service source and its packages were preserved, but
  Zero Stack does not invoke them. Primary actions and Save only archive in-app.
  No calendar insertion, maps launch, reminder or notification occurs here.

Architecture and rules

Image picker → ImportedImage → ScreenshotTextExtractor → OcrDocument →
HeuristicScreenshotAnalyzer / StructuredExtraction → ScreenshotItem →
existing Zero Stack / Archive.

The extractor lazily creates ML Kit on supported mobile platforms, captures
text lines and their heights/block indexes, catches unreadable images, and
releases the recognizer. Web/desktop return an explicit unsupported result.
Raw OCR and private file paths are not printed in production logs.

The import controller reads one screenshot at a time, announces Reading x of n,
and catches failures per image. Failed images remain real image cards with a
Reference fallback. An operation generation prevents cancelled work overwriting
the inbox or reset demo. Processing never changes the original image files.

Classification is pure Dart and uses only recognized text. Image names, paths,
brands and exact example titles are never classification inputs.

| Category | Required combinations |
| --- | --- |
| Task | Academic task + due/submission, or course code + deadline |
| Event | Event/attendance context + date or time |
| Product | Price + purchase/variation/specification signals, or purchase + promotion |
| Place | Address + business/hours/navigation, or business + hours |
| Read | Substantial text + byline or reading-time signal |
| Reference | No eligible category, unusable/error OCR, or competing strong categories |

Only eligible categories are scored. Their independent signal groups produce
heuristic scores starting at .66–.68; a margin below .15 between the two highest
scores falls back to Reference. These scores are not calibrated probabilities.
Reference uses confidence 0 and explains the fallback in matchedSignals.
Empty/unusable/error results show Unsorted screenshot,
“We couldn’t confidently identify an action.” and Save Reference.
Readable ambiguous text may supply a reference title.

Structured extraction removes status-bar/navigation noise, uses title context
and text prominence, joins short split headlines, and extracts only detected
date/time, venue, course, address/hours, price/options, author/publication/URL.
Missing fields stay absent. Discount amounts are not reported as product prices.
No guessed source, arbitrary final-line venue, inferred year/timezone or
generated description is added.

The eight handcrafted demo items bypass both OCR and analysis. Reset restores
those original records. Archive completion retains the imported image identity,
raw text, category, signals and extracted fields.

Debug builds: long-press the category label in Zero Stack for scrollable,
selectable OCR diagnostics. Archive detail also shows diagnostics. Release builds
hide them.

Files

Created:
- lib/features/analysis/ocr_document.dart
- lib/features/analysis/structured_extraction.dart
- lib/features/analysis/analysis_diagnostics.dart
- test/ocr_fixture_test.dart, test/ocr_batch_test.dart, test/mlkit_extractor_test.dart
- test/fixtures/ocr_windows.json
- test/fixtures/manual/ (unchanged copies of the five supplied images and README)
- integration_test/ocr_fixtures_test.dart
- tool/read_fixture_text.ps1, tool/prepare_native_ocr_test.ps1
- OCR_IMPLEMENTATION.md

Modified:
- lib/features/analysis/screenshot_text_extractor.dart
- lib/features/analysis/mlkit_screenshot_text_extractor.dart
- lib/features/analysis/screenshot_analyzer.dart
- lib/features/import_preview/import_provider.dart
- lib/features/import_preview/import_preview_screen.dart
- lib/features/zero_stack/zero_stack_screen.dart
- lib/shared/widgets/page_frame.dart
- test/screenshot_analyzer_test.dart
- pubspec.yaml and dependency lockfile

Physical phone test

1. Transfer dist/Screenshot-Zero-1.2.0.apk and the five PNGs from
   test/fixtures/manual/ to your Android phone (Android 7/API 24 or newer).
2. Open the APK and allow installation from the transferring app if Android asks.
   This is a locally test-signed release build, not a store-signed distribution.
3. Launch Screenshot Zero, skip onboarding, tap Import screenshots, select all
   five images, and process them. Observe Reading 1 of 5 through Reading 5 of 5.
4. Check Task/Assignment 3 with due date/time and course; Product/Everyday Runner
   at $89; Place/Sunday Table with address/hours; Event/Campus Research Symposium
   with date/time/ballroom; Read/article headline with Maya Rahman and publication.
   OCR spelling/capitalization may differ from Windows diagnostics.
5. Skip one card and confirm it returns later. Use a primary action and Save.
   Process all cards, open Archive and inspect the original images and metadata.
   Primary button labels remain the existing design; actions stay inside the app.
6. Import a blank or non-text image and confirm the safe Reference fallback.
   Repeat a mixed batch with one unreadable or low-quality screenshot.
7. Start another batch, return home/reset before it finishes, and confirm it
   cannot replace the reset demo. Verify all eight demo cards still work.
8. Repeat the five-image import in airplane mode to verify offline recognition.

For native automated verification and diagnostic output, follow
test/fixtures/manual/README.md. Run a debug app with
`flutter run -d DEVICE_ID` to inspect OCR via the category long-press.

Known limitations

- Android native recognition and physical-phone interaction remain unverified
  here; Windows OCR regressions and mocked bridge tests are separate evidence.
- English-oriented deterministic rules and Latin recognition; small, rotated,
  stylized, cropped or multilingual text may fall back or be imperfect.
- Multi-column reading order and multiple competing items can be ambiguous.
  No semantic model, timezone resolution or calendar-valid date normalization.
- Web/desktop retain image import and Reference fallback; no ML Kit OCR there.
- Session-only storage: no database, account, sync or persistence across restarts.
- The controlled fixture bytes are only embedded in the device test target;
  normal APKs contain neither those screenshots nor their OCR transcripts.

Validation and release artifact

- flutter pub get: passed.
- flutter analyze: passed, no issues found.
- flutter test: passed, 41 tests. Includes five actual Windows-OCR transcript
  regressions, unrelated titles/filenames, sparse/conflicting inputs, missing
  fields, batch failure/cancellation, native bridge error handling, image/archive
  identity, demo reset and responsive widget flows.
- flutter build apk --release: passed.
- flutter build web --release: passed (JavaScript target; existing dependencies
  emit Wasm dry-run compatibility warnings). Web OCR uses Reference fallback.
- APK signature verification: passed. Version 1.2.0, build 3, min SDK 24,
  target SDK 36, ARM32/ARM64/x86_64.
- APK inspection confirms the bundled Latin OCR model and no fixture assets.
- Native ML Kit five-image test: prepared, not run (no connected Android device).
- Nonblocking build warnings: existing Android command-line SDK XML version
  mismatch and a Cupertino font reference. SDK configuration was not migrated.

Shareable APK:
C:\Development\Projects\Hackathon_project_1\dist\Screenshot-Zero-1.2.0.apk

Standard Flutter build output:
C:\Development\Projects\Hackathon_project_1\build\app\outputs\flutter-apk\app-release.apk

Size: 81,870,340 bytes (78.1 MiB).
SHA-256: ECDD93AE05AAEC7EA8D1158CDC9DE31A0BA8BBA454FA1092ED5DC0A926C142FA

Logs: build/analyze-results.txt, build/test-results.txt, build/apk-build.log,
build/web-build.log.
