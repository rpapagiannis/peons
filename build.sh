#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
destination="$PWD/build/Peons.app"
mkdir -p build
staging="$(mktemp -d "$PWD/build/.peons-build.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app="$staging/Peons.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 -module-cache-path "$staging/module-cache" \
    Sources/*.swift \
    -o "$app/Contents/MacOS/Peons" -framework AppKit -framework SwiftUI -framework AVFAudio
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>Peons</string>
    <key>CFBundleIdentifier</key><string>local.rafail.pickle-rick-pet</string>
    <key>CFBundleName</key><string>Peons</string>
    <key>CFBundleDisplayName</key><string>Peons</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>4.2.2</string>
    <key>CFBundleVersion</key><string>13</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
cp assets/rat-suit-pickle-rick-atlas.png "$app/Contents/Resources/"
cp assets/ATTRIBUTION.md "$app/Contents/Resources/"
# Copy only manifest-referenced voices/effects; original recordings stay in the source tree.
python3 - "$app/Contents/Resources" <<'PYASSETS'
from pathlib import Path, PurePosixPath
import json, shutil, sys
source = Path("assets/sounds")
destination = Path(sys.argv[1]) / "sounds"
for directory, manifest in [("rick", "lines.json"), ("effects", "effects.json")]:
    pack = source / directory
    for metadata in pack.glob("*.json"):
        target = destination / directory / metadata.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(metadata, target)
    for clip in json.loads((pack / manifest).read_text()):
        relative = PurePosixPath(clip["audioAsset"])
        if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != directory:
            raise ValueError(f"Unexpected sound asset: {relative}")
        target = destination / str(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / str(relative), target)
PYASSETS
# Render Rick from the bundled atlas so the app icon stays reproducible from source.
icon_png="$staging/Peons.png"
iconset="$staging/Peons.iconset"
"$app/Contents/MacOS/Peons" --render-icon "$icon_png"
mkdir "$iconset"
for icon_size in 16 32 128 256 512; do
    /usr/bin/sips -z "$icon_size" "$icon_size" "$icon_png" --out "$iconset/icon_${icon_size}x${icon_size}.png" > /dev/null
    retina_size=$((icon_size * 2))
    /usr/bin/sips -z "$retina_size" "$retina_size" "$icon_png" --out "$iconset/icon_${icon_size}x${icon_size}@2x.png" > /dev/null
done
/usr/bin/iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$app"
# Publish a fresh bundle so retired characters and voice packs cannot survive a rebuild.
if [[ -e "$destination" ]]; then mv "$destination" "$staging/previous.app"; fi
mv "$app" "$destination"
print "Built: $destination"
