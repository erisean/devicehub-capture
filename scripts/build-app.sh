#!/bin/zsh
# Builds DeviceHub Capture.app into ./build. Pass --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "${0:A:h}/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/DeviceHubCapture"
APP="build/DeviceHub Capture.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  pkill -x DeviceHubCapture 2>/dev/null || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/"DeviceHub Capture.app"
  cp -R "$APP" ~/Applications/
  open ~/Applications/"DeviceHub Capture.app"
  echo "Installed to ~/Applications"
fi
