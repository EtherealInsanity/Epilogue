#!/usr/bin/env bash
set -e

echo "=== Epilogue: Building Linux Desktop Release ==="
flutter pub get
flutter build linux --release

mkdir -p release_assets

echo "Packaging Epilogue-v2.0.3-linux-x86_64.tar.gz..."
tar -czf release_assets/Epilogue-v2.0.3-linux-x86_64.tar.gz -C build/linux/x64/release/bundle .

echo "Packaging Epilogue-v2.0.3-linux-x86_64.zip..."
python3 -c "
import zipfile, os
bundle = 'build/linux/x64/release/bundle'
with zipfile.ZipFile('release_assets/Epilogue-v2.0.3-linux-x86_64.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(bundle):
        for f in files:
            path = os.path.join(root, f)
            arcname = os.path.relpath(path, bundle)
            z.write(path, arcname)
"

echo "Linux release successfully packaged in release_assets/"
