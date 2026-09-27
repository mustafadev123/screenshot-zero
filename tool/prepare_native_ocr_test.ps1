param([string]$FixtureDirectory = 'test/fixtures/manual')
$ErrorActionPreference = 'Stop'
$expectations = @{
  'event_symposium.png.png' = 'event'
  'place_restaurant.png.png' = 'place'
  'product_runner.png.png' = 'product'
  'read_article.png.png' = 'read'
  'task_assignment.png.png' = 'task'
}
$fixtures = @()
foreach ($name in ($expectations.Keys | Sort-Object)) {
  $path = Join-Path $FixtureDirectory $name
  $fixtures += @{ expected = $expectations[$name]; bytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))) }
}
$defines = @{ OCR_FIXTURES = (ConvertTo-Json -InputObject $fixtures -Compress) }
[IO.File]::WriteAllText((Join-Path (Get-Location) 'build/ocr-test-defines.json'), (ConvertTo-Json -InputObject $defines -Compress))
Write-Output 'Prepared build/ocr-test-defines.json for the device-only test target.'
