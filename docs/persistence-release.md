# Persistence and release cleanup — 1.4.0+5

Historical implementation checkpoint. Commands, artifacts and verification notes
below describe 1.4.0; current setup is in ../README.md and final-polish.md.

## Storage and startup

The existing quota already used SharedPreferences. Real Archive records were only
in the inbox provider, so replacing a collection or restarting lost them.
The implementation adds a separate Riverpod Archive controller and a small file
repository, without a database.

Mobile records live in the app support directory under screenshot_zero_archive:
one version-1 JSON file per unique random archive ID, plus images/<SHA256>.image.
JSON records are flushed to a temporary file and renamed only after the persistent
image copy succeeds. Saves are serialized. Content hashing streams the source file;
copying does not recompress images. Original picker/user files are never deleted.
Matching image bytes reuse an existing copy, including across separate imports.
Relative image filenames avoid persisting temporary picker or installation paths.

Each record retains category, title, subtitle, display metadata, useful extracted
fields, source filename, Save-only flag, completion status, creation/processing
times, reminder date/time and notification ID. Wishlist/read-later are represented
by their existing category and completion status. Raw OCR, confidence, matched
signals, diagnostic errors and detected_text dumps are excluded from JSON.
ScreenshotItem adds optional archiveId/createdAt/processedAt fields. Existing
constructors remain compatible. Unknown/malformed record versions are skipped
individually with debug-only messages; files are retained. Missing optional older
fields use safe defaults. Missing image files preserve metadata and use the
existing image-unavailable placeholder.

Startup loads Archive independently of inbox/demo defaults. Archive shows loading
until records arrive. New imports and demo reset never write over real storage.
The eight demo items remain session-only and never enter the persistent repository.
Demo completion may be displayed in Archive during that demo session; reset removes
those demo results while retaining real saved records.

On disk failure, the completed action and screenshot remain in memory. Archive
shows a short failure message and a storage Retry button. Retry uses the same
archive identity and does not execute Calendar/Maps/reminder actions again.
Users must retry before terminating the app; failed writes cannot survive a crash.

## Quota, reminders and RevenueCat

The 10-analysis quota, SharedPreferences key, Pro bypass and debug-only reset remain
unchanged. Tests recreate the quota store to confirm usage remains. Existing quota
tests cover Pro bypass and cancelled/removed selections; demo never enters OCR.

Reminder status/time/notification ID persist. Loading Archive does not reschedule
notifications or imply they were delivered. Existing ScheduledNotificationReceiver
and boot receiver remain in place. Android controls delivery timing and reboot
restoration; uninstall, clearing app data, force-stop and battery restrictions can
affect scheduled notifications. Reinstall cannot reconstruct previous reminders.

REVENUECAT_API_KEY remains a String.fromEnvironment compile-time setting.
screenshot_zero_pro remains the shared entitlement used by initialization,
customer-info listener, purchase, restore and paywall.
The release helper now rejects test_ keys and accepts an Android goog_ public key
or an explicitly empty key. Debug helper accepts the developer's Test Store key.
Outside debug mode the app will not configure the SDK with a test_ key; missing
or disallowed configuration leaves purchases unavailable without crashing.
RevenueCat's own release safety check is not bypassed.

See [RevenueCat's configuration guidance](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
and [path_provider's supported directories](https://pub.dev/packages/path_provider).

## Cleanup and audit

Removed the visible action-recorded/session implementation copy and obsolete
“actions stay in this app” demo footer. Archive diagnostic views remain behind
kDebugMode; a release-equivalent widget test confirms diagnostics are absent.
RevenueCat exceptions now use short user messages rather than raw error strings.
Dark theme, layouts, routes, picker, six category rules and action logic remain.
Action files received only mechanical braces for existing analyzer findings.
OCR analysis received only a creation timestamp when making the ScreenshotItem.

Display name/Android label remains Screenshot Zero; package ID remains
com.screenshotzero.screenshot_zero. Version is 1.4.0, build 5.
Existing launcher images and notification icon references are retained.
Android min SDK 24, target/compile SDK 36, Java 17 and development signing remain.
No signing credentials or store distribution configuration were added.

No real SDK keys/private keys/service-account secrets were found by the working
tree and tracked-file pattern scans. The corresponding Git history pattern scan
also returned no matches. This is a targeted audit, not a guarantee against every
possible secret format. .env.example contains placeholders only. No local developer
configuration was deleted. .gitignore now covers config/*.local.json, Android
key.properties, keystores and service-account JSON names; build/dist/.env were
already ignored. Debug build artifacts/logs can contain the supplied public Test
Store key and remain ignored. No dashboard configuration was changed.

## Dependencies and changed files

- Added path_provider ^2.1.5 (resolved 2.1.6) for the app support directory.
- Promoted/reused crypto as a direct dependency, ^3.0.6 (resolved 3.0.7), for
  content hashes. Existing SharedPreferences, notification and RevenueCat packages
  are reused; their API behavior is unchanged.
- New: lib/features/archive/archive_provider.dart and data/{archive_repository,
  archive_repository_factory, archive_repository_io, archive_repository_web,
  archive_record}.dart.
- New: test/archive_persistence_test.dart, test/archive_release_ui_test.dart,
  tool/build_debug.ps1, this report.
- Modified: lib/domain/models/screenshot_item.dart, lib/app/app.dart,
  lib/features/zero_stack/{inbox_provider,zero_stack_screen}.dart,
  lib/features/archive/{archive_screen,archive_detail}.dart,
  lib/features/import_preview/import_preview_screen.dart,
  lib/features/subscription/subscription_service.dart,
  lib/features/analysis/screenshot_analyzer.dart (timestamp only).
- Clarified the ImportedImage model comment to include app-owned archived files.
- Mechanical lint fixes: lib/features/actions/{action_date_parser,
  platform_action_services}.dart.
- Modified test harnesses: test/widget_test.dart and test/ocr_batch_test.dart
  inject the memory repository so unrelated flow tests never write real storage.
- Modified: pubspec.yaml, pubspec.lock, README.md, .gitignore,
  tool/build_release.ps1. No native manifest changes.

## Verification

- flutter pub get: passed.
- flutter analyze: passed, no issues.
- flutter test: 65 tests passed, including all previous OCR/title/action/quota/demo
  tests and seven new persistence/release UI cases.
- New tests verify six statuses, owned image bytes after picker deletion,
  deduplication, creation/processing/reminder metadata, diagnostic exclusion,
  corrupt/future records, optional fields, missing images, provider reload,
  new-collection/demo separation, delayed startup merge, retry identity,
  quota store recreation and debug/release RevenueCat key validation.

## APK build results

Both Android builds succeeded for version 1.4.0+5. APK signatures verified.

- Debug with the supplied public RevenueCat Test Store key injected at build time:
  `dist/Screenshot-Zero-1.4.0-debug.apk` (206,161,635 bytes).
  Flutter output: `build/app/outputs/flutter-apk/app-debug.apk`.
  APK manifest confirms it is debuggable.
- Release preview with an explicitly empty RevenueCat key:
  `dist/Screenshot-Zero-1.4.0-release-preview.apk` (88,649,845 bytes).
  Flutter output: `build/app/outputs/flutter-apk/app-release.apk`.
  APK manifest confirms it is not debuggable. An additional scan of the arm64
  compiled Dart binary found no Test Store key pattern. Purchases are unavailable
  gracefully in this preview; use the debug APK for Test Store purchases.

Paths above are relative to `C:\Development\Projects\Hackathon_project_1`.
Build helpers are `tool/build_debug.ps1 -RevenueCatApiKey YOUR_TEST_STORE_KEY`
and `tool/build_release.ps1` for the no-key preview. Production release requires
an Android production public SDK key and proper distribution signing.

SHA-256:

```text
debug:   BC570B10EF88DB875C55C04E8A60EC9F18B1CB91A7FF3DC68DE434F81EC3A247
release: 8D0884D364752D13849972521F26805DB4520D60619AF83A2C10CF6C4E73988D
```

Existing SDK XML/Kotlin compatibility and font-reference build warnings were
nonfatal. No connected Android phone was available for physical verification.

## Permissions audit

The merged manifest and APK audit found the existing permissions below. Persistence
added no permissions, and no existing permissions were removed.

| Permission | Current use |
| --- | --- |
| INTERNET | RevenueCat subscription communication and existing SDK networking |
| ACCESS_NETWORK_STATE | Existing SDK network/transport support |
| POST_NOTIFICATIONS | User-confirmed local reminders |
| RECEIVE_BOOT_COMPLETED | Existing reminder rescheduling receiver |
| VIBRATE | Existing notification plugin/channel support |
| com.android.vending.BILLING | RevenueCat's Android billing integration |
| app-specific DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | AndroidX signature-protected receiver isolation |

No broad storage/gallery, read/write calendar, location, or exact-alarm permissions
were present. App-private file copies need none. No currently unnecessary permission
was identified with enough confidence to remove it. Existing SDK receivers are
unchanged, including notification reboot receivers.

## Physical Android test steps

1. Install the 1.4.0 debug APK over the existing installation so quota remains.
   Do not uninstall or clear app data for the normal-restart test.
2. Import the controlled product, read, task, event, place and reference examples.
   Use primary actions and Save on a separate example. Confirm external actions
   only as intended, and check the resulting Archive status.
3. Verify wishlist/read-later/reference metadata and reminder date/time.
4. Import and process another collection. Older real Archive entries must remain.
5. Wait for processing to finish, then force-stop the app in Android settings.
   Reopen and go directly to Archive: verify image rendering, title/category/status
   and reminder details. Unprocessed inbox cards are not restored.
6. Confirm free-analysis usage was retained. Test Pro purchase/restore using the
   debug APK, then restart and confirm RevenueCat refreshes the entitlement.
7. Reset/complete the eight-card demo. Verify real archived screenshots remain and
   quota is not consumed by demo actions. Restart: demo results should not persist.
8. Test normal device reboot for reminder metadata retention. Notification delivery
   depends on Android; do not equate visible metadata with delivery confirmation.
9. Install the no-key release preview and inspect Archive/Zero Stack: no confidence,
   internal signals or raw OCR panels should appear. Pro purchases should be
   unavailable gracefully. Use the debug APK again for Test Store testing.

## Known limits

Native phone testing for this persistence change is pending. Tests use actual
temporary files and repository reloads, plus mocked subscription/platform flows.
Archive files are app-private but are not independently encrypted. No cloud sync,
database, export/delete UI, storage eviction or migration from lost historical
in-memory data is provided. Orphan image/temp files after interrupted writes are
retained rather than risking deletion. Pending inbox/import state is session-only.
Browser preview uses an in-memory archive because browser blob URLs are transient.
OS-managed app backup behavior is unchanged; this is not an app-managed backup.
The release preview retains the existing development signing certificate and
requires proper signing/assets/production RevenueCat configuration before store
publication. No multimodal intelligence work was started.
