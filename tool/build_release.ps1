param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^test_.+')]
    [string]$RevenueCatApiKey
)

$ErrorActionPreference = 'Stop'

if ($RevenueCatApiKey -eq 'YOUR_TEST_STORE_KEY') {
    throw 'Replace YOUR_TEST_STORE_KEY with the RevenueCat Test Store public SDK key.'
}

& flutter build apk --release "--dart-define=REVENUECAT_API_KEY=$RevenueCatApiKey"
if ($LASTEXITCODE -ne 0) {
    throw "Flutter release build failed with exit code $LASTEXITCODE."
}

Write-Output 'Built build/app/outputs/flutter-apk/app-release.apk with RevenueCat Test Store configuration.'
