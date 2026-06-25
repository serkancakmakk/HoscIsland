#!/bin/bash
set -euo pipefail

# Builds HoscIsland with SwiftPM and wraps the executable into a .app bundle
# (no Xcode required). Pass --run to launch the app afterwards.

cd "$(dirname "$0")"

APP_NAME="HoscIsland"
# Bundle id is kept as the original so previously granted TCC permissions
# (Full Disk Access, Automation) carry over without needing to re-grant.
BUNDLE_ID="com.pilot.notch"
CONFIG="release"
BUILD_DIR=".build/${CONFIG}"
APP_BUNDLE="${APP_NAME}.app"

echo "▶︎ Derleniyor (swift build -c ${CONFIG})..."
swift build -c "${CONFIG}"

echo "▶︎ .app paketi oluşturuluyor..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>HoscIsland, çalan müziği göstermek ve kontrol etmek için Music ve Spotify uygulamalarına erişir.</string>
    <key>NSHumanReadableCopyright</key>
    <string>HoscIsland</string>
</dict>
</plist>
PLIST

echo "PLIST" > "${APP_BUNDLE}/Contents/PkgInfo" 2>/dev/null || true
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

# Sign with a STABLE self-signed identity if available, so TCC permissions
# (Full Disk Access, Automation) survive rebuilds. Ad-hoc signing changes the
# code hash every build and makes macOS revoke those grants. Falls back to
# ad-hoc if the identity isn't present.
SIGN_IDENTITY="PilotNotch Self-Signed"
if security find-identity -p codesigning 2>/dev/null | grep -q "${SIGN_IDENTITY}"; then
    echo "▶︎ İmzalanıyor (${SIGN_IDENTITY})..."
    codesign --force --deep --sign "${SIGN_IDENTITY}" --timestamp=none "${APP_BUNDLE}" 2>&1 | sed 's/^/  /' || true
else
    echo "▶︎ Ad-hoc imzalanıyor (sabit kimlik bulunamadı)..."
    codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null 2>&1 || true
fi

echo "✅ Hazır: ${APP_BUNDLE}"

if [[ "${1:-}" == "--run" ]]; then
    echo "▶︎ Başlatılıyor..."
    # Kill a previous instance, then launch.
    pkill -x "${APP_NAME}" 2>/dev/null || true
    sleep 0.3
    open "${APP_BUNDLE}"
fi
