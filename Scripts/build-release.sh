#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
identity="${FOLDER_SIZE_SIGNING_IDENTITY:?Indica la identidad Developer ID Application en FOLDER_SIZE_SIGNING_IDENTITY}"
profile="${FOLDER_SIZE_NOTARY_PROFILE:?Indica el perfil de notarytool en FOLDER_SIZE_NOTARY_PROFILE}"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/folder-size-release.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
app_dir="$build_dir/Folder Size.app"
dmg="$project_dir/dist/Folder-Size-0.2.0.dmg"

bash "$project_dir/Scripts/build-app.sh" "$app_dir"
codesign --force --options runtime --timestamp --sign "$identity" "$app_dir"
codesign --verify --strict --verbose=2 "$app_dir"
ln -s /Applications "$build_dir/Applications"
mkdir -p "$project_dir/dist"
hdiutil create -volname 'Folder Size' -srcfolder "$build_dir" -ov -format UDZO "$dmg"
codesign --force --timestamp --sign "$identity" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
spctl --assess --type open --context context:primary-signature --verbose "$dmg"
hdiutil verify "$dmg"
echo "DMG firmado y notarizado: $dmg"
