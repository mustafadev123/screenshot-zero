# Screenshot Zero visual backend

Small FastAPI service; no accounts, database, screenshot archive, Firebase or
background processing. The app continues local ML Kit OCR and classification
first. Only weak results with active Pro, saved consent and a configured URL can
reach this service. Client gating is not server authentication or proof of purchase.

## Local setup (PowerShell)

From the project root:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
notepad .env
```

Do not overwrite an existing .env. Set OPENAI_API_KEY to your server API key and
OPENAI_MULTIMODAL_MODEL to an image/structured-output capable model. The development
default is gpt-4.1-mini. Both values are backend-only; environment variables override
.env. No Flutter define should contain the OpenAI key. .env and virtual environments
are ignored. Python 3.14 and the installed SDK were used for verification.

```powershell
python check_key.py
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --no-access-log --no-proxy-headers
```

In another terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health
```

Health reports only {"status":"ok"}; it does not certify OpenAI credentials or
available billing. Restart the backend after changing .env. Startup reads settings
once. Key validation makes only a model lookup, not a billable image inference.

## Phone connection and APK

The produced debug APK uses **http://127.0.0.1:8000 via USB port forwarding**.
Localhost on the phone otherwise refers to the phone, not the PC. Connect your
Android phone by USB, enable USB debugging and accept the PC authorization prompt:

```powershell
& C:\Android\platform-tools\adb.exe devices
& C:\Android\platform-tools\adb.exe reverse tcp:8000 tcp:8000
& C:\Android\platform-tools\adb.exe install -r ..\dist\Screenshot-Zero-1.5.0-debug.apk
```

Keep the backend and USB connection active; reapply reverse after reconnecting.
The running backend is loopback-only. No Windows firewall rules were changed.

To build the same configuration from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\build_debug.ps1 `
  -RevenueCatApiKey "YOUR_TEST_STORE_KEY" `
  -MultimodalApiBaseUrl "http://127.0.0.1:8000"
```

Standard output: build/app/outputs/flutter-apk/app-debug.apk.

For a deliberately enabled **trusted LAN** development session, the requested
alternate startup command is:

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload --no-access-log --no-proxy-headers
```

This accepts requests from reachable LAN clients. Do not expose it to the public
internet. The automated all-interface launch was rejected by approval review, so
this session used loopback/USB instead. On a private trusted Wi-Fi network, permit
only the needed private-network firewall access if you choose LAN testing; use
ipconfig to find your PC address (10.0.0.70 during this session). From the root:

```powershell
flutter run `
  --dart-define=REVENUECAT_API_KEY=YOUR_TEST_STORE_KEY `
  --dart-define=MULTIMODAL_API_BASE_URL=http://YOUR_PC_LAN_IP:8000
```

Build a LAN-targeting debug APK with the same --dart-define or the helper's
-MultimodalApiBaseUrl argument. LAN IPs can change, and guest Wi-Fi may isolate
devices. This URL is configuration, not hardcoded application source. HTTP is
allowed only by the Android debug manifest and debug adapter. Release accepts only
HTTPS. Missing/invalid URL keeps fallback unavailable. No wildcard CORS is enabled;
native Android does not need CORS. Browser deployment is not configured here.

## Endpoint and model contract

- GET /health: {"status":"ok"}, no configuration/secrets.
- POST /v1/analyze: multipart/form-data, required image, ocr_text (can be empty),
  local_category and local_confidence. Optional local_title/local_metadata_json.
- Metadata must be a JSON object of at most 30 string values (500 characters each,
  keys <=100). OCR <=12,000 characters, local title <=300, confidence finite [0,1].
- Response matches Flutter MultimodalResult: category/title/confidence/reason,
  evidence tags and supported metadata. Backend due_date/due_time become
  dueDate/dueTime; nulls are omitted because the existing Flutter parser expects
  absent unsupported fields. No new category or second client schema.
- Required model fields are category, title, confidence, reason, evidence and all
  nullable metadata: date, time, venue, address, price, variant, size, author,
  publication, url, due_date, due_time. Unknown fields/types/categories, invalid
  bounds or unsafe URLs fail validation. Categories are exactly event/place/
  product/read/task/reference. Evidence uses the existing client vocabulary.

The official AsyncOpenAI SDK uses Responses API responses.parse with a strict
Pydantic schema, image data URL, local OCR/context and a separate instruction
prompt. Refusals/incomplete output are rejected. The prompt emphasizes saving
intent, imperfect OCR, no invented facts and treating screenshot instructions as
untrusted data. Objects alone remain Reference. See official documentation for
[structured outputs](https://developers.openai.com/api/docs/guides/structured-outputs),
[image inputs](https://developers.openai.com/api/docs/guides/images-vision) and the
[configured default model](https://developers.openai.com/api/docs/models/gpt-4.1-mini).

## Limits, privacy and deployment

PNG/JPEG/WebP only, actual decoded format checked with Pillow, max 8 MiB and 20M
pixels; no animated images. A pre-parser body cap of 8 MiB + 32 KiB applies even
without Content-Length. At most one file/five text fields, upload read deadline
10 seconds. Framework multipart parsing can briefly spool large uploads to an OS
temporary file; it is closed/deleted by the form context. No persistent copies,
database, request-body logs, OCR logs, keys or authorization-header logs are added.

Default protection: six requests/minute per socket IP, global rolling 100 requests/
24h, two concurrent requests, no SDK retries, max 800 output tokens, upstream 18s,
client 22s, resolver 25s. The default is a non-reasoning model, so no extra reasoning
budget is requested. REQUESTS_PER_MINUTE/MAX_REQUESTS_PER_DAY are configurable.
Invalid requests count toward the conservative request limits too. Failures yield
generic JSON 4xx/5xx without upstream error bodies; Flutter retains the local result.
Closing the per-request HTTP client bounds timed-out transfers. A completed upload
cannot be recalled by navigating away; late results cannot replace a new session.

These limits are single-process, reset on restart, and are not a durable billing
cap. Run one worker for local testing. Before public deployment require TLS, a
reverse proxy with ingress/body/time limits and shared rate limiting, trusted proxy
configuration, network restrictions or real server-side authorization, provider
project spending controls, secret management and retention disclosure. Do not call
an APK token a secret or trust the client's Pro claim. No authentication was added
as requested, so this is a protected local/hackathon service, not a public production
deployment. No deployment or dashboard configuration was changed.

store=False disables saved Responses state; it is not a promise of zero provider
retention. Review [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)
before uploading sensitive screenshots. Local debug HTTP is unencrypted; use USB
loopback or a trusted LAN, and HTTPS for any remote deployment.

## Automated checks and manual phone plan

Automated verification at the backend implementation checkpoint (historical):

- Backend: 22 tests passed. Python compilation and pip check passed; no type-check
  configuration exists. One upstream TestClient/httpx deprecation warning remains.
- Flutter: pub get passed, analyzer reported no issues, 98 tests passed (12 new
  backend-adapter cases). The strengthened no-read/no-network gate tests also pass.
- Debug APK built successfully with RevenueCat Test Store configuration and
  MULTIMODAL_API_BASE_URL=http://127.0.0.1:8000. No OpenAI key in Flutter source.
- Current debug artifact: `dist/Screenshot-Zero-1.5.0-debug.apk` (project root).
- Subsequent physical Android testing verified phone-to-backend connectivity and
  real inference, including semantic Reference results, using a debug APK, USB
  debugging, adb reverse and backend on 127.0.0.1:8000.
- The initial invalid key was replaced. Credential/model lookup and subsequent
  on-device inference succeeded in development; this is not production validation.
- Current safe release preview: `dist/Screenshot-Zero-1.5.0-release-preview.apk`;
  it intentionally has no purchase key or cloud endpoint.

Files created: backend/app/{main,config,models}.py, backend/app/services/
{multimodal_service,openai_multimodal_service}.py and package markers,
backend/tests/test_backend.py, backend/{requirements.txt,.env.example,.gitignore,
README.md,check_key.py}, lib/features/analysis/multimodal/backend_multimodal_service.dart,
test/backend_multimodal_test.dart. Local ignored backend/.env and .venv were created.
Files modified: root .gitignore/.env.example/README.md, pubspec.yaml/pubspec.lock,
hybrid_analysis.dart (adapter provider and timeout only), tool/build_debug.ps1,
android/app/src/debug/AndroidManifest.xml and docs/multimodal-fallback.md.
Earlier persistence/Skip/OCR changes in the working tree were retained.

```powershell
# From backend, with the virtual environment activated:
python -m pytest tests -q -p no:cacheprovider
python -m compileall -q app
# From project root:
flutter pub get
flutter analyze
flutter test
```

Automated tests mock OpenAI/HTTP, require no real key and incur no model calls.
The backend suite includes the real SDK over a mock transport to verify strict
schema serialization and parsing. There is no configured static type checker.

1. Correct backend/.env, run check_key.py, restart backend; /health must respond.
2. Connect USB, authorize debugging, apply adb reverse and install the new APK
   over the existing installation. No Android device was connected during build.
3. Obtain Pro through the existing RevenueCat Test Store paywall/restore. Import
   an image-only screenshot and choose Continue in the existing consent dialog.
   A previously saved Not now still blocks uploads; test consent in a separate
   installation or reset only visual_analysis_consent_v1 in development. No
   preference/UI architecture was changed in this task.
4. Food photo: expect a descriptive Reference, never Product/Place without evidence.
5. Image-heavy shopping page: Product only with visible shopping context. Difficult
   event poster: Event only with visible event evidence. Uncertain results remain
   Reference; titles need not exactly match examples.
6. Strong Assignment: existing Task and no backend request. Strong Product likewise.
7. Stop backend or simulate a timeout: processing completes with local result.
   Decline consent or disable Pro: no upload. Keep the 10-analysis free quota intact.
8. Save/action/Skip a mixed collection, then restart to verify existing Archive and
   Skip behavior. No backend screenshot storage is involved.

Physical Android multimodal connectivity and live backend inference have been
verified in development, including semantic Reference results. The ignored .env
holds server credentials; the key never enters Flutter. New installations require
working credentials/model access/billing. Production deployment/security and broad
model-quality evaluation remain future work; individual outputs can still be wrong.
