#!/usr/bin/env bash
#
# Builds and launches the debug app, optionally rebuilding the web UI first.
#
# Debug builds use io.github.cozykim.toneka.debug so they never share
# UserDefaults, TCC grants or the unpacked UI cache with an installed release.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_VERSION="24.18.1"
BUNDLE_ID="io.github.cozykim.toneka.debug"
UI_CACHE="$HOME/Library/Application Support/$BUNDLE_ID"

usage () {
  cat <<'USAGE'
Usage: scripts/run-debug.sh [options]

  --ui        Rebuild the web UI and clear its cache before launching.
              Needed after changing anything under ui/.
  --clean-ui  Clear the unpacked UI cache without rebuilding it.
  --build     Build only; do not launch.
  -h, --help  Show this message.

Logs go to stdout, so run this in a terminal you can watch. Ctrl-C quits.
USAGE
}

build_ui=false
clean_ui=false
launch=true

while [ $# -gt 0 ]; do
  case "$1" in
    --ui) build_ui=true; clean_ui=true ;;
    --clean-ui) clean_ui=true ;;
    --build) launch=false ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if $build_ui; then
  echo "==> Building UI"
  if ! command -v mise >/dev/null 2>&1; then
    echo "mise is not installed. Install it, or put Node $NODE_VERSION on PATH yourself." >&2
    exit 1
  fi
  # Angular's toolchain pins the Node major; keep this in step with .mise.toml.
  PATH="$(mise where "node@$NODE_VERSION")/bin:$PATH"
  export PATH
  ( cd "$ROOT/ui" && yarn build )
fi

if $clean_ui; then
  # UI.unarchiveZip caches the unpacked UI per app version, so a freshly built
  # ui.zip is ignored until this is gone.
  echo "==> Clearing unpacked UI cache"
  rm -rf "$UI_CACHE"
fi

echo "==> Building app"
xcodebuild \
  -workspace "$ROOT/native/Toneka.xcworkspace" \
  -scheme Toneka \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -quiet \
  build

# Ask xcodebuild where it put the app. Picking the newest match under
# DerivedData looks equivalent but is not: a worktree gets its own derived
# directory, and the bundle's timestamp does not always move when the binary
# inside it does, so the guess can hand back a stale build.
products="$(xcodebuild \
  -workspace "$ROOT/native/Toneka.xcworkspace" \
  -scheme Toneka \
  -configuration Debug \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')"

app="$products/Toneka.app"
if [ ! -d "$app" ]; then
  echo "Could not find the built app at $app" >&2
  exit 1
fi

if ! $launch; then
  echo "==> Built: $app"
  exit 0
fi

echo "==> Running $app"
pkill -f "Debug/Toneka.app" 2>/dev/null || true
exec "$app/Contents/MacOS/Toneka"
