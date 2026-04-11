#!/bin/bash
# QuickSnip build script
# Run this from the project folder: bash build.sh
set -e

APP="QuickSnip"
APP_BUNDLE="${APP}.app"
ZIP="${APP}.zip"
TEAM_ID="C898MY5UA5"
SIGN_ID="Developer ID Application: JOHN BEUHRING NASH (C898MY5UA5)"
KEYCHAIN_PROFILE="QuickSnip-Notarization"
BUNDLE_ID="com.johnnash.quicksnip"

cd "Text Expander Clone"

echo "==> Building ${APP}..."
swift build -c release

echo "==> Creating ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP}"           "${APP_BUNDLE}/Contents/MacOS/"
cp "Info.plist"                      "${APP_BUNDLE}/Contents/"
cp "StarterSnippets.textexpbackup"   "${APP_BUNDLE}/Contents/Resources/"

echo "==> Signing ${APP_BUNDLE}..."
codesign --deep --force --options runtime \
  --sign "${SIGN_ID}" \
  --identifier "${BUNDLE_ID}" \
  --timestamp \
  "${APP_BUNDLE}"

echo "==> Verifying signature..."
codesign --verify --deep --strict "${APP_BUNDLE}"
spctl --assess --type exec "${APP_BUNDLE}" 2>/dev/null || true

echo "==> Zipping for notarization..."
cd ..
rm -f "${ZIP}"
ditto -c -k --keepParent "Text Expander Clone/${APP_BUNDLE}" "${ZIP}"

echo "==> Submitting to Apple for notarization (this takes ~1-2 min)..."
xcrun notarytool submit "${ZIP}" \
  --keychain-profile "${KEYCHAIN_PROFILE}" \
  --wait

echo "==> Stapling notarization ticket..."
xcrun stapler staple "Text Expander Clone/${APP_BUNDLE}"

echo "==> Re-zipping with stapled app..."
rm -f "${ZIP}"
ditto -c -k --keepParent "Text Expander Clone/${APP_BUNDLE}" "${ZIP}"

echo ""
echo "✓ Done! ${APP_BUNDLE} is signed, notarized, and ready."
echo "  Users can now open it directly — no xattr command needed."
echo ""
echo "To install locally:"
echo "  cp -r Text\ Expander\ Clone/${APP_BUNDLE} /Applications/"
