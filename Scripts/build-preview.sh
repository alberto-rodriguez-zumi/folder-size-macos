#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
app_dir="$build_dir/Folder Size.app"
bash "$project_dir/Scripts/build-app.sh" "$app_dir"
ln -s /Applications "$build_dir/Applications"
codesign --force --deep --sign - "$app_dir"
hdiutil create -volname 'Folder Size' -srcfolder "$build_dir" -ov -format UDZO "$project_dir/Folder-Size-preview.dmg"
