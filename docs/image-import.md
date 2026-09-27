# Real image import — Screenshot Zero 1.1.0

The existing Digital Darkroom UI and navigation are preserved. Real images can now be selected, reviewed, removed, processed with temporary reference metadata, and viewed in the session archive. OCR and external actions remain unimplemented.

## APK and phone installation

- APK: `dist/Screenshot-Zero-1.1.0.apk` (47.6 MiB / 49,882,275 bytes).
- Version: 1.1.0, Android version code 2.
- Android 7.0 / API 24 or newer; universal APK includes arm64-v8a, armeabi-v7a, and x86_64.
- Built in release mode and signed using the project's existing local development key. Signature verification passed. This is a sideloaded test build, not a store-signed production release.

Copy the APK to your phone's Downloads folder using USB or your preferred file transfer method. Open it in Files, allow that file manager to install unknown apps if Android asks, and choose Install (or Update for the previous build signed on this computer). You do not need Flutter or a running development server on your phone.

Alternatively, with USB debugging enabled and the phone authorized:

```sh
adb install -r dist/Screenshot-Zero-1.1.0.apk
```

## Exact manual Android test

1. Launch Screenshot Zero and reach Home using Start with screenshots or Skip intro.
2. Tap Import screenshots. The system image selector should open without a broad gallery-access request.
3. Choose 3–6 screenshots and confirm selection.
4. Check that the contact sheet displays those exact images and the correct selected count.
5. Tap the small × on one thumbnail. Confirm the selected count and Process button both decrease by one.
6. Press Process N screenshots. This replaces the current session collection; it does not alter source photos.
7. Confirm Zero Stack displays your first real image with Ready to organize / Imported screenshot and an explicit temporary-demo-details label.
8. Tap Skip once. Confirm the next image appears and the skipped image remains waiting.
9. Tap Save or SAVE REFERENCE. Confirm progress advances and your next real image appears.
10. Process all remaining images. Inbox Zero should remain visible until you choose another action.
11. Tap View archive. Check that processed entries retain their real thumbnails; tap an entry for its image and details. Imported items are references in this phase, so use ALL or REFERENCES.
12. Return Home and choose Demo options → Reset demo. Confirm the original eight illustrated cards return. Replay introduction → Explore demo also explicitly loads those eight.
13. Additional checks: open the picker and cancel; the current inbox must stay unchanged. Select one image, then remove it; Process must be disabled and Choose screenshots must be available. Try a larger selection; at most 20 images are kept and any truncation is explained.
14. Optional Android lifecycle check: with Don't keep activities enabled in Developer options, repeat selection and verify the selected files are recovered into Import Preview if Android recreates the activity. This is selection recovery, not permanent inbox persistence.

Physical-device behavior was not tested here because no Android phone was connected. Automated tests substitute the picker result while exercising real file decoding, state, and navigation.

## Packages

Added compatible versions without changing Flutter/Dart SDK constraints:

- `image_picker: ^1.2.3`
- `image_picker_android: ^0.8.13+23`
- `image_picker_platform_interface: ^2.11.1`

The Android implementation and platform interface are direct dependencies because the service explicitly enables `useAndroidPhotoPicker`. Existing go_router and Riverpod versions remain unchanged. Flutter remains 3.47.4 / Dart constraint `^3.13.3`.

References: [official image_picker documentation](https://pub.dev/packages/image_picker), [official Android implementation setup](https://pub.dev/packages/image_picker_android).

## Structure and image representation

```text
PickerImageImportService
  → ImportedImage (path + display name; no image bytes)
  → ImportController (pending selection, busy state, limit/error notice)
  → MockScreenshotAnalyzer on Process
  → ScreenshotItem with importedImage
  → existing inbox / Zero Stack / Archive
```

`ImageImportService` opens the multi-image picker, translates cancellation/errors, handles Android lost-data recovery, and caps results at 20. It asks for a platform selection limit, but also keeps only the first 20 if the platform ignores the limit. Full metadata, resizing, and compression are not requested. It never deletes or edits source files.

Pending selections are separate from the inbox. Cancellation and failure retain existing state. Removing a preview only removes a reference from the selection. Process explicitly replaces the current collection and releases pending selection references. The UI explains that this replaces the session. Reset/Explore demo clears pending selections and restores only handcrafted cards.

`ImportedImage` stores a native selected-file path or browser blob URL plus a display name. `ScreenshotItem` has exactly one image source: handcrafted `artwork` or `importedImage`. Its completion method preserves that image reference when archiving. Imported images receive the REFERENCE intent, Ready to organize title, and explicitly temporary demo details; no classification is performed. All mapping is in `MockScreenshotAnalyzer`, separate from the picker and widgets.

`ScreenshotImage` selects handcrafted artwork or `ImportedImageView`. Native rendering uses FileImage; the conditional web implementation uses the selected blob URL. ResizeImage bounds decoded native images to their display size, capped at 1440 pixels per side, with an aspect-preserving fit policy. The grid is lazy and contains images without stretching or cropping them. App state stores no duplicated byte arrays. Loading and decode failures show quiet placeholders. File and blob references are session-scoped; restarting/refreshing may reset imported data.

## Android changes and permissions

No manual changes were needed to AndroidManifest.xml, Gradle, minSdk, or targetSdk. Official plugin registration and manifest merging add the picker provider and Photo Picker backport metadata. The Android service explicitly opts into the Photo Picker and runs retrieveLostData once at startup to handle activity destruction. Browser startup skips that Android-only API.

The packaged release manifest was inspected with Android build tools:

- No READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE, READ_MEDIA_IMAGES, camera, or Internet permissions.
- No runtime gallery/storage permission requests were introduced.
- AndroidX merges the internal signature permission `com.screenshotzero.screenshot_zero.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. This is not a photo-access permission and does not prompt the user.

## Created files

- `lib/domain/models/imported_image.dart`
- `lib/features/import_preview/data/image_import_service.dart`
- `lib/features/import_preview/import_provider.dart`
- `lib/features/import_preview/import_button.dart`
- `lib/mock/mock_screenshot_analyzer.dart`
- `lib/shared/widgets/imported_image_view.dart`
- `lib/shared/widgets/screenshot_image.dart`
- `lib/shared/widgets/image_source/image_provider_native.dart`
- `lib/shared/widgets/image_source/image_provider_web.dart`
- `test/image_import_service_test.dart`
- `test/import_flow_test.dart`
- `test/support/fake_image_import_service.dart`
- `test/fixtures/selected.png`, `selected-1.png`, `selected-2.png`
- `docs/image-import.md`
- Generated test artifact: `dist/Screenshot-Zero-1.1.0.apk`

## Modified files

- `pubspec.yaml`, `pubspec.lock`: official picker dependencies and app version 1.1.0+2.
- `lib/app/app.dart`: one-time interrupted Android selection recovery.
- `lib/domain/models/screenshot_item.dart`: real-image reference preserved through completion.
- `lib/features/import_preview/import_preview_screen.dart`: actual contact sheet, dynamic count, removal, empty state, privacy line.
- `lib/features/home/home_screen.dart`: real picker button, explicit demo label, reset cleanup.
- `lib/features/onboarding/onboarding_screen.dart`: Explore demo explicitly restores demo state.
- `lib/features/zero_stack/inbox_provider.dart`: atomic collection replacement.
- `lib/features/zero_stack/inbox_zero_screen.dart`: real Import more action.
- `lib/features/zero_stack/zero_stack_screen.dart`: clear temporary metadata labeling.
- `lib/features/zero_stack/screenshot_deck.dart`: shared real/demo renderer.
- `lib/features/archive/archive_screen.dart`, `archive_detail.dart`: real thumbnails and detail image.
- `lib/shared/widgets/screenshot_art.dart`: retains dedicated handcrafted-art rendering.
- `test/widget_test.dart`: preserved demo flow with injected picker service.
- `tool/capture_previews.dart`: deterministic picker-free preview harness.
- `.gitignore`: excludes packaged APK artifacts in dist.
- `README.md`: updated run, import, and testing instructions.

## Verification

- `flutter pub get`: passed.
- `flutter analyze`: no issues found.
- `flutter test`: all 14 tests passed.
- `flutter build apk --release --no-pub`: passed.
- `flutter build web --no-pub`: passed, including the compiler's Wasm compatibility dry run.
- APK signature verified with apksigner; manifest inspected with aapt.

Tests cover the 20-image service limit, no resize/compression arguments, cancellation/error translation, Android recovery, real FileImage decoding, aspect-preserving decode sizing, preview removal, Skip/Save, completion/archive, separate demo reset, duplicate-picker prevention, one/zero/20-image states, invalid-file fallback, 360/430px widths, and 160% text scaling.

No compile or analyzer errors remain. Both release builds emit a non-fatal missing optional CupertinoIcons font warning from the existing dependency graph; this app uses Material icons, which are packaged successfully.
