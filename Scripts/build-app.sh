#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="${1:?Indica la ruta del paquete .app}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

for arch in arm64 x86_64; do
    swiftc -O -target "$arch-apple-macosx15.0" -parse-as-library "$project_dir"/App/*.swift -o "$build_dir/FolderSize-$arch"
done
lipo -create "$build_dir/FolderSize-arm64" "$build_dir/FolderSize-x86_64" -output "$app_dir/Contents/MacOS/FolderSize"
cp "$project_dir/Assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Folder Size</string>
<key>CFBundleExecutable</key><string>FolderSize</string>
<key>CFBundleIdentifier</key><string>com.zumi.foldersize</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
