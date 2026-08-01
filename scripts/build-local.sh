#!/usr/bin/env bash
#
# Builds the release configuration and installs it to /Applications.
#
# This build is ad-hoc signed and uses com.bitgapp.eqmac.local, so it lives
# alongside an installed official eqMac instead of replacing it.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="eqMac Local.app"
DESTINATION="/Applications/$APP_NAME"

install=true
if [ "${1:-}" = "--no-install" ]; then
  install=false
elif [ $# -gt 0 ]; then
  echo "usage: scripts/build-local.sh [--no-install]" >&2
  exit 1
fi

echo "==> Building UI"
if ! command -v mise >/dev/null 2>&1; then
  echo "mise is not installed. Install it, or put Node 24.18.1 on PATH yourself." >&2
  exit 1
fi
PATH="$(mise where node@24.18.1)/bin:$PATH"
export PATH
( cd "$ROOT/ui" && yarn build )

echo "==> Building app"
xcodebuild \
  -workspace "$ROOT/native/eqMac.xcworkspace" \
  -scheme eqMac \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -quiet \
  build

built="$(ls -dt "$HOME/Library/Developer/Xcode/DerivedData/eqMac-"*/Build/Products/Release/"$APP_NAME" 2>/dev/null | head -1)"
if [ -z "$built" ]; then
  echo "Could not find the built app under DerivedData." >&2
  exit 1
fi

if ! $install; then
  echo "==> Built: $built"
  exit 0
fi

echo "==> Installing to $DESTINATION"
pkill -f "$DESTINATION" 2>/dev/null || true
rm -rf "$DESTINATION"
ditto "$built" "$DESTINATION"
echo "==> Installed. Open it from /Applications."
