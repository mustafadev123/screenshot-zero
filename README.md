# Screenshot Zero

A Flutter Android prototype with real multi-image import, on-device analysis, actions, and optional Screenshot Zero Pro monetization. The existing Digital Darkroom theme uses warm paper, ink, thin borders, editorial typography, and one signal accent. The eight handcrafted demo screenshots remain available separately.

The current phone-test APK is `dist/Screenshot-Zero-1.1.0.apk`. See [the image-import phase report](docs/image-import.md) for the complete file inventory, architecture, permissions, and physical Android test steps.

Real imported screenshots are read locally with Google ML Kit Text Recognition. A deterministic heuristic analyzer classifies OCR text as event, place, product, read, task, or reference, extracts only detected fields, and falls back to an unsorted reference when OCR fails or confidence is low. The handcrafted demo collection never goes through OCR.

## Screenshot Zero Pro setup

Screenshot Zero uses RevenueCat with one entitlement: `screenshot_zero_pro`. Free users can process the first 10 real screenshot analyses; demo screenshots do not consume this allowance. Pro unlocks unlimited analysis and larger batches. The counter is stored locally with SharedPreferences, while Pro status is always determined by RevenueCat.

To configure RevenueCat Test Store:

1. Create a RevenueCat project and Android app.
2. Enable RevenueCat Test Store for the project.
3. Create the `screenshot_zero_pro` entitlement.
4. Create a current offering with one or more packages and attach the `pro` entitlement to the products.
5. Copy the public SDK key into a local command invocation. Never commit it:

```sh
flutter run -d <android-device-id> --dart-define=REVENUECAT_API_KEY=your_public_test_store_key
```

The exact compile-time variable is `REVENUECAT_API_KEY`. It is read with `String.fromEnvironment`, so `.env` and `.env.example` are not loaded at runtime. Every APK must receive the key through `--dart-define`; a plain `flutter build apk --release` intentionally creates an unconfigured build.

For a release APK, use the checked-in fail-fast PowerShell wrapper. It requires a Test Store key and cannot silently omit it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_release.ps1 -RevenueCatApiKey "YOUR_TEST_STORE_KEY"
```

Equivalent direct PowerShell command:

```powershell
flutter build apk --release --dart-define=REVENUECAT_API_KEY=YOUR_TEST_STORE_KEY
```

Output: `build/app/outputs/flutter-apk/app-release.apk`.

The app creates one `PurchasesRevenueCatService` through Riverpod. Startup refresh, the customer-info entitlement listener, purchase, restore, and the paywall all use that same provider instance and the `screenshot_zero_pro` entitlement. The paywall reads the current RevenueCat offering and localized package prices. Builds without the define remain usable and show the existing unconfigured message.

## Run on an Android phone

Built using Flutter 3.47.4 / Dart 3.13.3. The generated `sdk: ^3.13.3` constraint is preserved.

1. Install Flutter and the Android SDK; run `flutter doctor`.
2. Enable Developer options and USB debugging on your phone, connect it by USB, and authorize the computer on the phone.
3. From this project directory, run:

```sh
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

Build an installable release-mode test APK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_release.ps1 -RevenueCatApiKey "YOUR_TEST_STORE_KEY"
```

Output: `build/app/outputs/flutter-apk/app-release.apk`. The existing Gradle configuration signs release builds with the local development key, suitable for sideloaded testing rather than store distribution.

## Run in a web browser

```sh
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Keep that terminal running and open `http://127.0.0.1:8080` in a browser on the same computer. The web-server target stays independent of the browser window. This is a local browser preview. The same mock flows and reset menu work on web; state resets on browser refresh. Web scaffolding is in `web/`, with the app title and paper theme configured in `index.html` and `manifest.json`.

## Demo behavior

The app starts with three onboarding pages and eight demo screenshots. Home → Import screenshots opens the system image picker. Up to 20 selected images appear in the existing contact sheet, where individual images can be removed. Process replaces the current session with the selected real images and opens Zero Stack. Cancellation and picker errors leave the current inbox untouched.

- Primary action: mark the screenshot processed, archive its mock action, advance.
- Save: archive the screenshot without assigning its proposed action.
- Skip: move the screenshot to the back of the waiting queue. Skipping the last remaining card keeps it waiting; only processing or saving clears it.
- Completion: stays on Inbox Zero until View archive, Import more, or Home is chosen.
- Archive: filter processed screenshots by intent and tap an entry to inspect its saved details.
- Reset: Home → three-dot Demo options → Reset demo restores the eight handcrafted cards and clears pending real selections. Onboarding → Explore demo does the same. Demo and real collections are not merged.
- Replay onboarding: Home → Demo options → Replay introduction.

Screenshot item state is in memory only and resets when the process restarts, apart from recovery of an interrupted Android picker result. The local free-analysis counter persists with SharedPreferences; Pro entitlement comes from RevenueCat. Today/This week reflect this single session. Calendar, Maps, wishlist, reminder, and reading actions remain as implemented in Prompt 4. No broad gallery/storage permissions, cloud AI, authentication, database, or business API integration is implemented.

## Navigation

| Route | Screen |
| --- | --- |
| `/` | Redirect to Home |
| `/onboarding` | Three-page introduction |
| `/home` | Inbox count, import, archive, reset |
| `/home/import` | Real selected images, removal, and Process |
| `/home/stack` | One-card-at-a-time decisions |
| `/home/zero` | Completion; redirects to Stack if items remain |
| `/home/archive` | Filters and saved entries |

Home is the parent of the four working routes, so Android back navigation returns there. Archive detail is a dismissible modal sheet.

## Files

The workspace was empty. Flutter generated the Android project and supporting SDK configuration; the application implementation is separated as follows:

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
      app_colors.dart
      app_spacing.dart
      app_theme.dart
  domain/models/
    screenshot_intent.dart
    screenshot_item.dart
  features/
    onboarding/
      onboarding_screen.dart
      onboarding_visuals.dart
    home/home_screen.dart
    import_preview/import_preview_screen.dart
    zero_stack/
      inbox_provider.dart
      zero_stack_screen.dart
      screenshot_deck.dart
      inbox_zero_screen.dart
    archive/
      archive_screen.dart
      archive_detail.dart
  mock/mock_screenshots.dart
  shared/widgets/
    page_frame.dart
    screenshot_art.dart
    screenshot_illustration.dart
```

Also created or updated: `pubspec.yaml`, `pubspec.lock`, Android scaffolding and the application label in `android/app/src/main/AndroidManifest.xml`, `test/widget_test.dart`, `test/support/test_fonts.dart`, `tool/capture_previews.dart`, and this README.

**Packages:** `go_router: ^18.0.1`, `flutter_riverpod: ^3.4.3`, `image_picker: ^1.2.3`, `image_picker_android: ^0.8.13+23`, `image_picker_platform_interface: ^2.11.1`, `google_mlkit_text_recognition: ^0.15.0`, `android_intent_plus: ^5.3.1`, `url_launcher: ^6.3.2`, `flutter_local_notifications: ^19.4.2`, `timezone: ^0.10.1`, `purchases_flutter: ^9.10.0`, and `shared_preferences: ^2.5.3`. The image-picker packages explicitly opt into the Android system Photo Picker. ML Kit runs on-device on Android and iOS; non-mobile targets use the safe reference fallback. RevenueCat uses anonymous Test Store/App Store/Play Store client configuration. Development dependencies are the Flutter SDK's `flutter_test`, `integration_test`, and `flutter_lints`.

**Mock data:** `lib/mock/mock_screenshots.dart` contains exactly eight immutable seed items. Riverpod state lives in `lib/features/zero_stack/inbox_provider.dart`. All screenshot artwork is implemented in the shared screenshot widgets.

## Verification

```sh
flutter analyze
flutter test
flutter build web
```

Use `tool/build_release.ps1` for Android release builds so RevenueCat configuration cannot be omitted accidentally.

Widget tests exercise onboarding through all eight actions, completion, archive filters/details, reset, Skip/Save semantics, empty archive, reduced motion, widths of 360 and 430 logical pixels, and 160% text scaling on the smaller phone. Screenshot art behaves like a fixed image while surrounding interface text scales normally.

Optional local previews:

```sh
flutter test tool/capture_previews.dart
```

PNG files are written under `build/previews/`. Test previews load Roboto and Material icons from the installed Flutter SDK; serif artwork uses a Roboto substitute in tests. Android uses its platform serif font. Previews do not replace testing on a physical phone.

The import phase adds service and widget tests for cancellation, errors, selection limits, real file rendering, removal, Skip/Save, archive retention, and picker recovery. See the phase report for final verification results. Physical Android picker behavior must still be tested on a phone.
