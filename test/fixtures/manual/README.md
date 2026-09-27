These five controlled PNGs are unchanged copies of the images originally found
one directory above (including their existing double .png extensions).
Their names and expected labels are used only by test setup/assertions.
Production analysis never reads image names or paths to classify.

The committed ../ocr_windows.json contains actual local Windows.Media.Ocr
transcripts, including recognition errors. They are regression inputs, not
Android ML Kit output. Regenerate with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/read_fixture_text.ps1
```

Review the output in build/ocr-fixtures.windows.json before replacing the
committed regression data. OCR engine/language versions can change results.

To verify the actual Android engine, connect an Android phone with USB debugging,
authorize this computer, then run from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/prepare_native_ocr_test.ps1
flutter devices
flutter test integration_test/ocr_fixtures_test.dart -d DEVICE_ID --dart-define-from-file=build/ocr-test-defines.json
```

The script embeds image bytes only in the test target through compile-time
defines. The test writes anonymous temporary files in the app sandbox, runs
native ML Kit sequentially, asserts all five categories, and returns raw text,
fields, signals and confidence through integration-test reportData.
It deletes its temporary copies in finally. Originals remain unchanged.
No fixture images or transcripts are bundled in the normal release APK.

Expected behavior:

| Fixture | Category | Key extracted values |
| --- | --- | --- |
| task_assignment | Task | Assignment 3; Sep 30, 2026; 11:59 PM; CSC 6851 |
| product_runner | Product | Everyday Runner; $89; size 9; Cloud / Chalk |
| place_restaurant | Place | Sunday Table; 48 Peachtree Street, Atlanta, GA; open until 9 PM |
| event_symposium | Event | Campus Research Symposium; October 18, 2026; 7:30 PM; Student Center Ballroom |
| read_article | Read | How Small Models Are Changing AI; Maya Rahman; The Daily Ledger |

These are assertions for controlled examples, not title lookup rules.
The regression tests also rename inputs and use unrelated titles.
