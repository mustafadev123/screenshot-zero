param([string]$RevenueCatApiKey = '')
$ErrorActionPreference = 'Stop'
if ($RevenueCatApiKey -and $RevenueCatApiKey -notmatch '^goog_[A-Za-z0-9]+$') {
    throw 'Release requires the Android RevenueCat public SDK key (goog_). Test Store keys are debug-only.'
}
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & flutter build apk --release "--dart-define=REVENUECAT_API_KEY=$RevenueCatApiKey" '--dart-define=MULTIMODAL_API_BASE_URL='
    if ($LASTEXITCODE -ne 0) { throw 'Release build failed.' }
} finally { Pop-Location }
