#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
app_dir="$build_dir/Folder Size.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"

swiftc -O -target arm64-apple-macosx15.0 -parse-as-library "$project_dir"/App/*.swift -o "$app_dir/Contents/MacOS/FolderSize"
cp "$project_dir/Assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Folder Size</string>
<key>CFBundleExecutable</key><string>FolderSize</string>
<key>CFBundleIdentifier</key><string>com.zumi.foldersize</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
ln -s /Applications "$build_dir/Applications"
codesign --force --deep --sign - "$app_dir"
hdiutil create -volname 'Folder Size' -srcfolder "$build_dir" -ov -format UDZO "$project_dir/Folder-Size-preview.dmg"
