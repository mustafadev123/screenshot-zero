param([string]$RevenueCatApiKey = '', [string]$MultimodalApiBaseUrl = '')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
    & flutter build apk --debug "--dart-define=REVENUECAT_API_KEY=$RevenueCatApiKey" "--dart-define=MULTIMODAL_API_BASE_URL=$MultimodalApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'Debug build failed.' }
} finally { Pop-Location }
