# Build Windows Release and Package Zip
Write-Host "=== Epilogue: Building Windows Desktop Release ===" -ForegroundColor Cyan

flutter pub get
flutter build windows --release

$buildDir = "build\windows\x64\runner\Release"
$outDir = "release_assets"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$zipName = "$outDir\Epilogue-v2.0.3-windows-portable.zip"
if (Test-Path $zipName) {
    Remove-Item $zipName -Force
}

Write-Host "Packaging $zipName..." -ForegroundColor Cyan
Compress-Archive -Path "$buildDir\*" -DestinationPath $zipName -Force
Write-Host "Portable zip packaged: $zipName" -ForegroundColor Green

# Check for Inno Setup compiler
$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
    $possiblePath = "C:\Program Files (x86)\Inno Setup 6\iscc.exe"
    if (Test-Path $possiblePath) {
        $iscc = $possiblePath
    }
}

if ($iscc) {
    Write-Host "Building Windows Setup Installer via Inno Setup..." -ForegroundColor Cyan
    & $iscc /DMyAppVersion="2.0.3" windows\installer\epilogue_setup.iss
    Write-Host "Installer created in dist\ folder." -ForegroundColor Green
} else {
    Write-Host "Inno Setup (iscc.exe) not found; skipping installer exe generation." -ForegroundColor Yellow
}
