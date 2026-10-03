# Submission and capture checklist

## Submission media and repository presentation

The author reports that screenshots and the demo video were uploaded to Devpost
for the submission. This documentation update adds the supplied media to GitHub
after the deadline; it does not change the app implementation or certify contest
eligibility. Devpost publication and GitHub documentation are separate.

- [x] Supplied screenshots included in `docs/images/` and embedded in the README.
- [x] [Submitted demo video](https://www.youtube.com/watch?v=rZnx14GW3YI)
  linked in the README.

## Completed development verification and repository preparation

These are results already recorded in the repository, not a new test run.

- [x] MIT LICENSE added with Copyright (c) 2026 Muhammad Mustufa.
- [x] Android development checks covered a physical device, Photo Picker, OCR,
  Calendar and Maps actions, reminders, persistent Archive and RevenueCat Test Store.
- [x] Development Android phone-to-backend connectivity and live multimodal inference
  verified via USB debugging/adb reverse, including semantic Reference results.
- [x] Latest recorded results: 114 Flutter tests and 22 backend tests passing.

## Outstanding publication and distribution prerequisites

- [ ] Confirm redistribution rights/provenance of raster fixtures, portraits, fonts
  and launcher assets. Controlled content alone is not a license.
- [ ] Scan tree/history again immediately before publication. The previously recorded pattern scan
  found no credentials in the non-ignored files or commit it checked; no scan proves the
  absence of every secret format. Deleting a file does not remove Git history.
- [ ] Keep .env, backend/.env, keystores, virtual environments, build/dist and
  private screenshots excluded. Do not publish a ZIP containing ignored files.
- [ ] Rotate credentials shared during development before public deployment.
- [ ] Configure production signing, Android RevenueCat production key and HTTPS/
  rate-limited backend for distribution. Current backend is not authenticated.
- [ ] Continue the regression checks in final-polish.md. This verification does not
  establish broad model quality, TalkBack usability, scrolling performance or
  notification delivery across devices.
- [ ] Review current organizer requirements separately. This is a product checklist,
  not a certification of contest eligibility.

## Capture coverage

Checked items below are supported by the supplied still images. Unchecked
composite items still need the additional capture or confirmation described.

- [ ] 1024×1024 app icon suitable for submission (not supplied in this update)
- [x] At least one phone screenshot without a device frame
- [x] Public demo video link added to the README
- [x] Onboarding hero
- [x] Home with eight waiting demo items
- [x] Import Preview with selected screenshots
- [x] Cloud fallback consent dialog
- [ ] Event Zero Stack with date/venue
- [ ] Product Zero Stack with price/size
- [ ] Task Zero Stack and reminder confirmation
- [ ] Semantic Reference detail
- [ ] Archive and clean detail (Archive list supplied; detail still outstanding)
- [x] Inbox Zero
- [x] Pro paywall with offering prices shown in the supplied capture

Paywall prices reflect the captured configuration. The images do not establish
that production purchases or a production backend are configured.

## Media review requirements

These review items remain open unless separately confirmed for every frame and
the full exported video. Including the supplied media does not certify all checks.



- [ ] No OCR diagnostics, confidence, signals or raw OCR
- [ ] No backend URLs, paths, API errors, stack traces, debug banner or console
- [ ] No notification shade, private contacts, phone numbers or messages
- [ ] No personal transactions, financial balances, nutrition logs or private photos
- [ ] No credentials in terminals, editor tabs, URLs or dialogs
- [ ] No stale private Archive entries; use confirmed debug reset then reset demo
- [ ] Clear orientation, readable titles, dark framing, no clipped important text
- [ ] Explain simulated demo actions and never imply offline cloud analysis

Release preview hides diagnostics but has no purchases/cloud endpoint. Test Store
works in debug only. Capture the two configurations honestly.
