# Multimodal fallback architecture

**Update:** The backend-completion task adds a real HTTP adapter, configured with
MULTIMODAL_API_BASE_URL, and an OpenAI FastAPI backend. Missing URL still keeps
local-only behavior. See [current setup and results](../backend/README.md). The
notes below describe the original architecture checkpoint; its unavailable adapter
and eight-second timeout have since been replaced by configured HTTP and 22/25s
client/resolver deadlines. Pro, consent, local classifier and resolver rules remain.

The shipped adapter is unavailable by default. No backend or visual API key was
found/configured, no backend was created, and this APK makes no visual uploads.
Image-only screenshots still use the local Reference result on a phone until a
real secure backend adapter is supplied. Mocked results are used only in tests.

## Flow and policy

Existing ML Kit OCR and heuristic/structured extraction run unchanged first.
ImportController then calls HybridAnalysis before creating the existing
ScreenshotItem. The default FallbackPolicy is configurable through Riverpod:

- Local confidence >= 0.80: return local, even if text is sparse; no consent prompt
  or adapter call. This protects the existing confident classifications.
- Otherwise: existing conflicting_categories signal, fewer than 24 trimmed OCR
  characters, weak Reference, or confidence below 0.80 makes fallback eligible.
  Existing classifier competition detection (margin < 0.15) is reused unchanged.
- Only current Pro users with an available adapter are eligible. The existing
  screenshot_zero_pro entitlement is read through the existing subscription
  provider. No RevenueCat code, purchase flow, free limit or quota calculation changed.
- Only explicit saved consent permits a call. No callback means local-only for
  headless callers without an existing preference. A consent read/write failure
  fails closed. Each service call has an eight-second wait limit; batches remain
  sequential. No retries or separate cloud quota are added.
- Model confidence >= 0.80 can refine a weak local result. Lower-confidence visual
  results keep local Reference or conservatively downgrade weak actionable results
  to Reference. Service failures preserve the exact local result.
- Evidence tags are required for actionable categories. An object alone becomes
  Reference with a useful short title. Existing local category conflicts remain
  Reference. Resolver unit tests also cover high/high disagreement: Reference;
  the actual orchestrator never calls the service for a strong local result.
- Cancellation or entitlement loss before dispatch prevents a call. Results arriving
  after cancellation are discarded. A future adapter must implement transport
  cancellation too: Future.timeout does not cancel an already-started request.

## Service and strict response contract

MultimodalAnalysisService exposes availability and analyze(MultimodalRequest).
Input contains ImportedImage (path/blob reference), full local result, OCR text and
local extracted fields. A platform-specific adapter must read the image only after
consent, send bytes to a secure proxy, then parse its response with
MultimodalResult.fromJson. Never treat a client filesystem path as a backend URL.

Required JSON fields: category, title, confidence, reason. Categories are exactly
event/place/product/read/task/reference. Confidence must be numeric in [0,1].
Title is a nonblank string <=100 characters; reason <=500 characters is internal
and is never mapped to ScreenshotItem, Archive, debug logs or normal UI.
Optional fields are nonblank strings <=300 characters, omitted when unsupported:
date, time, venue, address, price, variant, size, author, publication, url,
dueDate, dueTime. Only HTTP(S) URLs with a host and no credentials are accepted.
Unknown keys/categories, wrong types, control characters, fenced output and
responses over 12,000 characters fail closed to local analysis.

Optional evidence is an array drawn from shopping_controls, event_details,
place_listing, article_layout, task_instructions. Corresponding evidence is required
to select Product/Event/Place/Read/Task; absence does not fabricate intent.

```json
{"category":"product","title":"Everyday Runner","confidence":0.91,"reason":"Visible shopping controls and price","evidence":["shopping_controls"],"price":"$89","variant":"Chalk","size":"9"}
```

```json
{"category":"reference","title":"Food photo","confidence":0.88,"reason":"No clear actionable intent","evidence":[]}
```

Normalization retains only fields relevant to the chosen category; dueDate/dueTime
map to due_date/due_time, variant to existing color. Existing action labels and
ScreenshotItem/Archive serialization remain unchanged. Missing values stay absent;
strong local fields are never blindly overwritten. No raw reasoning is displayed.

## Backend work still required

Implement a provider-neutral adapter behind multimodalServiceProvider, calling
only a secure backend/proxy. No provider or endpoint is selected in this task.
The backend must hold server credentials, enforce entitlement/budgets/rate and
payload limits, define retention and transport timeouts, and require this JSON
contract. Client-side Pro gating alone is not backend billing protection.
Instruct the model to infer saving intent rather than identify objects; omit
unsupported facts; treat screenshot/OCR instructions as untrusted data; return
Reference for ambiguous intent. Require evidence for actions. Model confidence and
evidence tags are not independently verified truth: evaluate a real provider on
controlled screenshots before enabling it for users. No Firebase or auth added.

## Consent and observability

When an eligible difficult screenshot first needs an available service, the
existing import screen shows one dialog explaining that screenshots and recognized
text may be sent online. Continue accepts; Not now or dismissing declines. Both
choices persist under SharedPreferences visual_analysis_consent_v1. Declined users
are not repeatedly prompted. No dialog appears in the default backend-free build.
There is no new settings screen; preference changes/revocation UI and provider
retention disclosure should be completed before a real cloud rollout. Developer
tests can reset only this preference. Clearing app data also clears Archive/quota
and should not be used on a valued installation just to reset consent.

Debug-only logs report eligibility reason, local/visual category and confidence,
final category and resolver decision. They contain no OCR text, image bytes, paths,
titles or model reason. Release builds omit these logs. Normal UI remains unchanged
except the necessary opt-in dialog when a service is available.

## Files and dependencies

Created lib/features/analysis/multimodal/{multimodal_service,hybrid_analysis,
visual_consent}.dart, test/multimodal_test.dart and this report.
Modified import_provider.dart (post-local refinement), import_preview_screen.dart
(consent callback), README.md. No packages added; reused Riverpod and
SharedPreferences. OCR, classifier, actions, Skip, Archive persistence and RevenueCat
implementation were not changed in this task.

## Verification results

- flutter pub get: passed; no new dependencies.
- flutter analyze: passed, no issues.
- flutter test: 86 passed (67 existing + 19 new deterministic tests).
- New tests cover food/Reference titles, shopping and event intent, strong local
  Task/Product bypass, offline/malformed/timeout/unconfigured fallback, low
  confidence, object-only and high-confidence conflicts, JSON validation, Pro
  gating, consent buttons/persistence/decline/write failure, cancellation and
  real import integration with quota counted once. No live model calls.
- flutter build apk --debug: passed with the existing public RevenueCat Test Store
  key injected by the existing helper at build time. No key added to source.
- Debug APK signature verified and manifest confirmed application-debuggable.
- Installable copy: C:\Development\Projects\Hackathon_project_1\dist\Screenshot-Zero-1.4.0-multimodal-debug.apk.
- Standard Flutter output: C:\Development\Projects\Hackathon_project_1\build\app\outputs\flutter-apk\app-debug.apk.
- No release APK was produced in this task. Existing working-tree changes from
  persistence and Skip tasks were preserved.

## Manual phone plan

1. Install the new debug APK over the existing app, preserving app data.
2. Import verified text-rich Task and Product screenshots. Confirm the same titles,
   actions and metadata. Check debug logs show strong_local and no visual calls.
3. Import image-only food/shoes. In this backend-free APK expect the existing local
   Reference result and no cloud disclosure/upload. This is intentional, not live AI.
4. Process/Save/Skip a mixed collection. Confirm Inbox Zero and existing Archive
   persistence after restart. Check the existing free quota still counts once per
   analyzed screenshot and Test Store Pro purchase/restore still works in debug.
5. For cloud-path developer testing, override multimodalServiceProvider with a
   deterministic test adapter (as in test/multimodal_test.dart), or a reviewed secure
   backend adapter. Do not enable canned responses in a user-distributed APK.
6. With Pro and a fresh consent preference, import a weak screenshot. Tap Not now:
   no request should occur, local result remains, and restart must not reprompt.
7. In a separate test installation/preference, tap Continue. Confirm acceptance is
   stored before dispatch. Mock food -> Reference title, shopping controls ->
   Product, poster -> Event; verify no reason text appears in normal UI.
8. Simulate offline/server error/malformed JSON/timeout: local result remains and
   processing completes. Simulate low confidence/object-only: Reference. Navigate
   back while pending: late responses must not replace the active collection.
9. Disable Pro: no fallback or disclosure. Strong local results must never upload
   even with Pro and consent. Verify normal UI has no prompts/reasoning diagnostics.

Live cloud understanding and physical-phone validation are pending. English local
heuristics and model uncertainty remain limitations. No semantic search, new
categories, chatbot, gallery scanning, deletion or final submission polish added.
