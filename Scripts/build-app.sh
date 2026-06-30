#!/usr/bin/env bash
#
# Packages Timemenu into a downloadable, code-signed macOS .app (+ a .zip).
# No paid Apple Developer account required.
#
#   Scripts/build-app.sh
#
# Signing:
#   - If CODESIGN_IDENTITY is set (or a "Timemenu Self-Signed" identity exists),
#     signs with it — a *stable* signature so the Keychain "Always Allow" sticks
#     across rebuilds. Create one once with Scripts/make-signing-cert.sh.
#   - Otherwise signs ad-hoc (works fine; Keychain re-prompts on each new build).
#
# Either way the app is NOT notarized (needs the $99 account), so downloaders
# must clear quarantine once — see the printed note / README.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Timemenu"
BUNDLE_ID="org.timemenu"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DIST="dist"
APP="$DIST/$APP_NAME.app"

# 1. Ensure the compressed data snapshot exists.
if [ ! -d "Sources/$APP_NAME/Resources/Data/meta" ]; then
  echo "→ generating data snapshot"
  python3 Scripts/build-data-snapshot.py >/dev/null
fi

# 2. Release build — universal (Apple Silicon + Intel).
echo "→ building release (universal arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

# 3. Assemble the .app bundle.
echo "→ assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp -R "$BIN/${APP_NAME}_${APP_NAME}.bundle" "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>Timemenu</string>
</dict>
</plist>
PLIST

# 4. Code sign.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "Timemenu Self-Signed"; then
  IDENTITY="Timemenu Self-Signed"
fi
if [ -n "$IDENTITY" ]; then
  echo "→ signing with stable identity: $IDENTITY"
  codesign --force --deep --sign "$IDENTITY" "$APP"
else
  echo "→ signing ad-hoc (run Scripts/make-signing-cert.sh for a stable identity)"
  codesign --force --deep --sign - "$APP"
fi
codesign --verify --verbose=2 "$APP"

# 5. Zip for distribution (ditto preserves the signature).
echo "→ zipping"
rm -f "$DIST/$APP_NAME.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$APP_NAME.zip"

echo
echo "✓ $APP"
echo "✓ $DIST/$APP_NAME.zip  ($(du -h "$DIST/$APP_NAME.zip" | cut -f1))"
echo
echo "Install: unzip, move Timemenu.app to /Applications. On first launch (not"
echo "notarized) clear quarantine once:  xattr -dr com.apple.quarantine /Applications/Timemenu.app"
echo "or right-click → Open / System Settings → Privacy & Security → Open Anyway."
