<#
    Publish a live update.

    Zips www/ into docs/live/, points the manifest at it, and pushes. GitHub
    Pages serves docs/, her app reads the manifest on its next launch, downloads
    the bundle and starts on it the launch after that. No new APK, no new link.

    Usage:   .\publish-update.ps1
             .\publish-update.ps1 -BundleId 2026-09-01-bigger-buttons
             .\publish-update.ps1 -NoPush          # build the bundle, push it yourself

    -MinVersionCode raises the minimum APK the bundle will run on. Use it only
    when the change needs native code that an older APK does not have: a new
    plugin, or anything under android/. Her app then shows a notice telling her
    to install a new APK, and refuses to apply this bundle until she has - an
    old app running a bundle that expects new native code would just crash.

    It must match the versionCode in android/app/build.gradle of the APK you
    publish alongside it, so bump that first.

             .\publish-update.ps1 -MinVersionCode 2
#>
param(
    [string]$BundleId = (Get-Date -Format 'yyyyMMdd-HHmm'),
    [int]$MinVersionCode = 0,
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

$root     = $PSScriptRoot
$www      = Join-Path $root 'www'
$liveDir  = Join-Path $root 'docs\live'
$zipPath  = Join-Path $liveDir "$BundleId.zip"
$pagesUrl = 'https://websterdr21-dev.github.io/blanket-block-planner'

if ($BundleId -eq 'public') { throw "'public' is reserved by the plugin, pick another bundle id." }
if (-not (Test-Path (Join-Path $www 'index.html'))) { throw "No www\index.html found in $root." }
if (Test-Path $zipPath) { throw "$zipPath already exists. Pass a different -BundleId." }

New-Item -ItemType Directory -Force -Path $liveDir | Out-Null

# index.html must sit at the root of the zip, so archive the contents of www, not www itself.
Compress-Archive -Path (Join-Path $www '*') -DestinationPath $zipPath -CompressionLevel Optimal

$checksum = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()

# Carry the existing floor forward unless this run raises it, so a routine
# publish never accidentally drops the requirement back down.
$manifestPath = Join-Path $liveDir 'manifest.json'
$previousMin = 1
if (Test-Path $manifestPath) {
    try {
        $prev = Get-Content $manifestPath -Raw | ConvertFrom-Json
        if ($prev.minVersionCode) { $previousMin = [int]$prev.minVersionCode }
    } catch { Write-Host "Could not read the previous manifest, assuming minVersionCode 1." -ForegroundColor Yellow }
}
$effectiveMin = if ($MinVersionCode -gt 0) { $MinVersionCode } else { $previousMin }

$manifest = [ordered]@{
    bundleId       = $BundleId
    url            = "$pagesUrl/live/$BundleId.zip"
    checksum       = $checksum
    minVersionCode = $effectiveMin
    appPageUrl     = "$pagesUrl/"
}
# Plain UTF-8, no BOM: JSON.parse chokes on a byte order mark.
[System.IO.File]::WriteAllText(
    $manifestPath,
    ($manifest | ConvertTo-Json),
    (New-Object System.Text.UTF8Encoding($false)))

$sizeKb = [math]::Round((Get-Item $zipPath).Length / 1KB)
Write-Host "Bundle $BundleId  ($sizeKb KB)" -ForegroundColor Green
Write-Host "  sha256 $checksum"
Write-Host "  $($manifest.url)"
Write-Host "  needs APK versionCode $effectiveMin or newer"
if ($MinVersionCode -gt 0) {
    Write-Host "`nThis bundle will NOT run on older APKs. Build and upload the matching APK:" -ForegroundColor Yellow
    Write-Host "  gh release create v$MinVersionCode blanket-block-planner.apk"
}

if ($NoPush) {
    Write-Host "`n-NoPush set. Commit and push docs/live yourself to go live." -ForegroundColor Yellow
    return
}

git -C $root add -- docs/live
git -C $root commit -m "Publish live update $BundleId"
git -C $root push

Write-Host "`nPushed. Give GitHub Pages a minute, then check:" -ForegroundColor Green
Write-Host "  $pagesUrl/live/manifest.json"
Write-Host "Her app picks it up on its next launch, and runs it the launch after that."
