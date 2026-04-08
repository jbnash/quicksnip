#!/bin/bash
# QuickSnip build script
# Run this from the project folder: bash build.sh
set -e

APP="QuickSnip"
APP_BUNDLE="${APP}.app"

echo "==> Building ${APP}..."
swift build -c release

echo "==> Creating ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp ".build/release/${APP}"       "${APP_BUNDLE}/Contents/MacOS/"
cp "Info.plist"                  "${APP_BUNDLE}/Contents/"
cp "StarterSnippets.textexpbackup" "${APP_BUNDLE}/Contents/Resources/"

echo ""
echo "✓ Done! ${APP_BUNDLE} is ready."
echo ""
echo "To run:"
echo "  open ${APP_BUNDLE}"
echo ""
echo "If macOS blocks it (unsigned app):"
echo "  Right-click → Open → Open"
echo "  (you only need to do this once)"
echo ""
echo "To install permanently:"
echo "  cp -r ${APP_BUNDLE} /Applications/"
