# Build Windows Release and Package Zip
Write-Host "=== Epilogue: Building Windows Desktop Release ===" -ForegroundColor Cyan

flutter pub get
flutter build windows --release

$buildDir = "build\windows\x64\runner\Release"
$outDir = "release_assets"

if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

$zipName = "$outDir\Epilogue-v2.0.3-windows-x64.zip"
if (Test-Path $zipName) {
    Remove-Item $zipName -Force
}

Write-Host "Packaging $zipName..." -ForegroundColor Cyan
Compress-Archive -Path "$buildDir\*" -DestinationPath $zipName -Force

Write-Host "Windows release successfully packaged: $zipName" -ForegroundColor Green
