#!/usr/bin/env bash
#
# Builds the release configuration and installs it to /Applications.
#
# The build is signed with SIGNING_IDENTITY when the keychain holds it and
# ad-hoc otherwise. Either way it runs on this machine only: Gatekeeper
# refuses both anywhere the app arrives with a quarantine flag -- a download,
# say. The difference is that an ad-hoc signature is a hash of the build, so
# each rebuild is a new app to macOS and its permission grants (the audio
# capture one) start over, whereas a certificate keeps the identity fixed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Toneka.app"
DESTINATION="/Applications/$APP_NAME"

install=true
if [ "${1:-}" = "--no-install" ]; then
  install=false
elif [ $# -gt 0 ]; then
  echo "usage: scripts/build-local.sh [--no-install]" >&2
  exit 1
fi

echo "==> Building UI"
if command -v mise >/dev/null 2>&1; then
  PATH="$(mise where node@24.18.1)/bin:$PATH"
  export PATH
elif [ "$(node --version 2>/dev/null)" != "v24.18.1" ]; then
  echo "mise is not installed and Node 24.18.1 is not on PATH. Install mise, or put Node 24.18.1 on PATH yourself." >&2
  exit 1
fi
( cd "$ROOT/ui" && yarn build )

# `security find-identity -v` lists only certificates the keychain trusts,
# and a self-signed one is not, so this looks through the unfiltered list.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-TypelessLike Local Dev}"
if security find-identity 2>/dev/null | grep -q "\"$SIGNING_IDENTITY\""; then
  echo "==> Signing as $SIGNING_IDENTITY"
else
  echo "==> No '$SIGNING_IDENTITY' in the keychain, signing ad-hoc"
  SIGNING_IDENTITY="-"
fi

echo "==> Building app"
xcodebuild \
  -workspace "$ROOT/native/Toneka.xcworkspace" \
  -scheme Toneka \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -quiet \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  build

# See the note in run-debug.sh: the newest match under DerivedData can be a
# stale build, so ask xcodebuild instead of guessing.
products="$(xcodebuild \
  -workspace "$ROOT/native/Toneka.xcworkspace" \
  -scheme Toneka \
  -configuration Release \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')"

built="$products/$APP_NAME"
if [ ! -d "$built" ]; then
  echo "Could not find the built app at $built" >&2
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
