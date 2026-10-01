#!/bin/sh
# Hand-assembles Bay.app from already-built binaries, replacing the tauri-cli bundling step
# in build-scripts/build.py (build_macos_desktop_app). No signing, no dmg.
set -eu
cd "$(dirname "$0")/.."

APP=build/Bay.app
VERSION=$(./target/release/q_cli --version | awk '{print $2}')
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"

cp target/release/fig_desktop "$APP/Contents/MacOS/bay-desktop"
cp target/release/q_cli "$APP/Contents/MacOS/bay"
cp target/release/figterm "$APP/Contents/MacOS/bayterm"

cp crates/fig_desktop/icons/icon.icns "$APP/Contents/Resources/icon.icns"
cp -R packages/dashboard-app/dist "$APP/Contents/Resources/dashboard"
cp -R packages/autocomplete-app/dist "$APP/Contents/Resources/autocomplete"

cat > "$APP/Contents/Resources/manifest.json" <<EOF
{"managed_by":"dmg","packaged_at":"$(date -u +%Y-%m-%dT%H:%M:%S)","packaged_by":"local","variant":"full","version":"$VERSION","kind":"dmg","default_channel":"stable"}
EOF

if [ ! -d build/themes ]; then
  git clone --depth 1 https://github.com/withfig/themes.git build/themes
fi
cp -R build/themes/themes "$APP/Contents/Resources/themes"

IME=$APP/Contents/Helpers/CodeWhispererInputMethod.app
mkdir -p "$IME/Contents/MacOS"
cp target/release/fig_input_method "$IME/Contents/MacOS/fig_input_method"
cp crates/fig_input_method/Info.plist "$IME/Contents/Info.plist"
cp -R crates/fig_input_method/resources "$IME/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleDisplayName</key><string>Bay</string>
  <key>CFBundleName</key><string>Bay</string>
  <key>CFBundleExecutable</key><string>bay-desktop</string>
  <key>CFBundleIconFile</key><string>icon.icns</string>
  <key>CFBundleIdentifier</key><string>org.siriuscrain.bay</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key><string>10.13</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>org.siriuscrain.bay</string>
      <key>CFBundleURLSchemes</key><array><string>bay</string></array>
    </dict>
  </array>
</dict>
</plist>
EOF

# Ad-hoc signature only (no Apple identity) so macOS will launch the local build.
codesign --force --deep --sign - --entitlements crates/fig_desktop/entitlements.plist "$APP"
echo "Built $APP ($VERSION)"
