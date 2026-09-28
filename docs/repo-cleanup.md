# Repository / submission cleanup

Documentation and repository metadata only; no app or backend behavior changed.

- Added one root MIT LICENSE, Copyright (c) 2026 Muhammad Mustufa.
- README now leads with the Flutter Android product, a short flow and a product
  tour placeholder table. No broken image links or fabricated screenshots. The
  six-intent table and Mermaid architecture remain.
- README, backend README and final-polish report now reflect owner-confirmed
  Android multimodal connectivity/live inference using debug APK, USB debugging,
  adb reverse and 127.0.0.1:8000, including semantic Reference results. This does
  not assert exhaustive production security, device coverage or perfect model output.
- Current backend install/artifact references use Screenshot-Zero-1.5.0-debug.apk.
  The 1.2.0 OCR and 1.4.0 persistence/multimodal reports are explicitly historical.
- RevenueCat documentation specifies screenshot_zero_pro, 10 real free analyses,
  Pro's app-quota bypass/premium fallback with backend limits, dynamic prices,
  debug Test Store and the prohibition on release test_ keys.
- Submission checklist includes a 1024×1024 icon, at least one clean frameless
  phone screenshot, Home, Import Preview, Zero Stack, Archive, Inbox Zero, Pro
  paywall and a video link. MIT is marked complete; asset-rights review remains.
- Added android/build/ to .gitignore to exclude generated Android output.

## Security and validation

Tracked credential-pattern scan found no real credential matches. Neither .env
nor backend/.env is tracked; both are ignored. Both .env.example files contain
placeholder credentials only (model names and numeric limits are configuration).
No credential values were printed. This is a targeted scan, not proof against
every possible secret encoding.

| Check | Result |
| --- | --- |
| flutter analyze | Passed; no issues |
| flutter test | 114 passed |
| backend pytest | 22 passed; existing TestClient/httpx deprecation warning |
| git diff --check | Passed |

No APK rebuild was needed or requested for this documentation-only change.

## Files

Created: LICENSE, docs/images/README.md, docs/repo-cleanup.md.

Modified: README.md, backend/README.md, docs/final-polish.md,
docs/submission-checklist.md, OCR_IMPLEMENTATION.md, docs/persistence-release.md,
docs/multimodal-fallback.md, .gitignore.

## Owner follow-up

Add real controlled captures to docs/images/, then replace the README placeholder
table with relative image links. Supply the 1024×1024 app icon and public demo video
link. Confirm asset redistribution rights and complete the remaining broad device,
model-quality and production deployment/security checks. No repository push or
public deployment was performed by this cleanup.
