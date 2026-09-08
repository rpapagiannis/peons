#!/bin/zsh
# Package an already-built app; signing, notarization, and publishing are separate steps.
set -euo pipefail

root="${0:A:h:h}"
script="${0:t}"
app="$root/build/Peons.app"
output="$root/dist"
usage() {
    print "Usage: $script [--app /path/to/Peons.app] [--output-dir /path/to/dist]"
    print "Build first with ./build.sh. Existing versioned artifacts are never overwritten."
}
while (( $# )); do
    case "$1" in
        --app|--output-dir)
            (( $# >= 2 )) || { usage >&2; exit 2; }
            if [[ "$1" == --app ]]; then app="$2"; else output="$2"; fi
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) print -u2 "Unknown argument: $1"; usage >&2; exit 2 ;;
    esac
done
[[ "$(uname -s)" == Darwin ]] || { print -u2 "Packaging requires macOS."; exit 1; }
app="${app:A}"
output="${output:A}"
plist="$app/Contents/Info.plist"
[[ -f "$plist" ]] || { print -u2 "App not found: $app. Run ./build.sh first."; exit 1; }
read_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }
version="$(read_plist CFBundleShortVersionString)"
build="$(read_plist CFBundleVersion)"
minimum_os="$(read_plist LSMinimumSystemVersion)"
executable="$(read_plist CFBundleExecutable)"
[[ "$executable" != */* && -n "$executable" ]] || { print -u2 "Invalid bundle executable."; exit 1; }
architectures="$(/usr/bin/lipo -archs "$app/Contents/MacOS/$executable")"
/usr/bin/codesign --verify --deep --strict "$app"
signature="$(/usr/bin/codesign --display --verbose=2 "$app" 2>&1)"
suffix=""
if [[ "$signature" == *"Signature=adhoc"* ]]; then
    suffix="-preview"
    print -u2 "PREVIEW: this app has an ad-hoc signature, not a Developer ID signature."
    print -u2 "This is not a notarized production release; recipients may encounter Gatekeeper restrictions."
elif [[ "$signature" != *"Authority=Developer ID Application:"* ]]; then
    suffix="-preview"
    print -u2 "PREVIEW: the app is not signed with a Developer ID Application certificate."
else
    print "Developer ID signature retained. Notarization is not performed by this script."
fi
# Restrict the metadata used in filenames, while retaining the original values in the summary.
safe_version="${version//[^A-Za-z0-9._-]/_}"
safe_build="${build//[^A-Za-z0-9._-]/_}"
safe_architectures="${architectures//[^A-Za-z0-9._-]/_}"
filename="Peons-${safe_version}-${safe_build}-${safe_architectures}${suffix}.dmg"
artifact="$output/$filename"
sidecar="$artifact.sha256"
[[ ! -e "$artifact" && ! -L "$artifact" && ! -e "$sidecar" && ! -L "$sidecar" ]] || {
    print -u2 "Artifact already exists. Choose another --output-dir or increment the app version/build."
    exit 1
}
mkdir -p "$output"
staging="$(mktemp -d "$output/.peons-package.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
mkdir "$staging/content"
/usr/bin/ditto "$app" "$staging/content/Peons.app"
/usr/bin/codesign --verify --deep --strict "$staging/content/Peons.app"
ln -s /Applications "$staging/content/Applications"
# GitHub-hosted macOS runners occasionally fail hdiutil create with "Resource busy"; retry briefly.
for attempt in 1 2 3 4 5; do
    if /usr/bin/hdiutil create -fs HFS+ -format UDZO -volname "Peons" \
        -srcfolder "$staging/content" "$staging/$filename"; then
        break
    fi
    (( attempt < 5 )) || { print -u2 "hdiutil create failed after $attempt attempts."; exit 1; }
    print -u2 "hdiutil create failed (attempt $attempt); retrying."
    rm -f "$staging/$filename"
    sleep 3
done
/usr/bin/hdiutil verify -quiet "$staging/$filename"
(cd "$staging" && /usr/bin/shasum -a 256 "$filename" > "$filename.sha256")
# Hard links publish without replacing an existing artifact, including concurrent invocations.
ln "$staging/$filename" "$artifact"
if ! ln "$staging/$filename.sha256" "$sidecar"; then
    rm "$artifact"
    exit 1
fi
print "Packaged: $artifact"
print "Checksum: $sidecar"
print "Version: $version (build $build); macOS $minimum_os or later; architecture: $architectures"
print "Install: open the disk image and drag Peons.app onto Applications."
