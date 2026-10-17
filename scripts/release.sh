#!/bin/bash
# Build, package and sign a Swift86 release for Sparkle.
# Usage: scripts/release.sh <version> <build>   e.g. scripts/release.sh 1.0 1
# Does not publish anything: it prints the gh command for you to run.
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <version> <build>   (e.g. $0 1.0 1)" >&2
    exit 1
fi
VERSION="$1"
BUILD="$2"

# Always work from the repository root
cd "$(dirname "$0")/.."
PBXPROJ="Swift86.xcodeproj/project.pbxproj"
REPO="https://github.com/brunocastello/Swift86"
OUT="build/release"
DIST="$OUT/dist"

# 1. The project versions must already match the arguments
for pair in "MARKETING_VERSION:$VERSION" "CURRENT_PROJECT_VERSION:$BUILD"; do
    key="${pair%%:*}"; want="${pair#*:}"
    # Every occurrence in the project file must equal the requested value
    found="$(grep -E "^[[:space:]]*$key = " "$PBXPROJ" | sed -E 's/.*= "?([^";]*)"?;.*/\1/' | sort -u)"
    if [ "$found" != "$want" ]; then
        echo "error: $key in $PBXPROJ is '$(echo "$found" | tr '\n' ' ')', expected '$want'. Bump it first." >&2
        exit 1
    fi
done

# 2. Build only committed code that is already on GitHub, so the tag matches the binary
if [ -n "$(git status --porcelain --untracked-files=no -- . ':!*xcuserdata*')" ]; then
    echo "error: uncommitted changes. Commit them first." >&2
    exit 1
fi
git fetch -q origin
if ! git merge-base --is-ancestor HEAD origin/main; then
    echo "error: HEAD is not on origin/main. Push it first." >&2
    exit 1
fi

# 3. Build Release
xcodebuild -project Swift86.xcodeproj -scheme Swift86 -configuration Release \
    -derivedDataPath "$OUT" build

APP="$OUT/Build/Products/Release/Swift86.app"
INFO="$APP/Contents/Info.plist"
plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$INFO"; }

# 4. The built app must carry the right versions and a real public key
[ "$(plist CFBundleShortVersionString)" = "$VERSION" ] || { echo "error: built CFBundleShortVersionString is '$(plist CFBundleShortVersionString)'" >&2; exit 1; }
[ "$(plist CFBundleVersion)" = "$BUILD" ] || { echo "error: built CFBundleVersion is '$(plist CFBundleVersion)'" >&2; exit 1; }
KEY="$(plist SUPublicEDKey)"
if [ -z "$KEY" ] || [ "$KEY" = "REPLACE_WITH_PUBLIC_ED_KEY" ]; then
    echo "error: SUPublicEDKey in Swift86/Info.plist is still the placeholder. See docs/UPDATES.md." >&2
    exit 1
fi

# 5. Zip the app (the asset name Swift86.zip is kept from earlier releases)
rm -rf "$DIST"
mkdir -p "$DIST"
(cd "$(dirname "$APP")" && ditto -c -k --sequesterRsrc --keepParent Swift86.app "$OLDPWD/$DIST/Swift86.zip")

# 6. Generate the signed appcast (uses the private key in your login Keychain)
GEN="$OUT/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
[ -x "$GEN" ] || { echo "error: $GEN not found. Build once so Sparkle's tools are fetched." >&2; exit 1; }
"$GEN" "$DIST" \
    --download-url-prefix "$REPO/releases/download/v$VERSION/" \
    --link "$REPO"

# 7. Print the publish command; this script never publishes
echo
echo "Ready. Write release notes to a file (e.g. notes.md), then run:"
echo
echo "  gh release create v$VERSION $DIST/Swift86.zip $DIST/appcast.xml --target $(git rev-parse HEAD) --title \"$VERSION\" --notes-file notes.md"
echo
echo "The release must be the one marked Latest (not a pre-release)."
