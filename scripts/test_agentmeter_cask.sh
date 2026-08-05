#!/bin/bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAP_NAME="dothinkerlab/tap"
CASK_NAME="$TAP_NAME/agentmeter"
APP_PATH="/Applications/AgentMeter.app"

cleanup() {
  brew uninstall --cask --force agentmeter >/dev/null 2>&1 || true
  brew untap "$TAP_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

brew untap "$TAP_NAME" >/dev/null 2>&1 || true
brew tap "$TAP_NAME" "$REPO_ROOT"
brew style --cask "$CASK_NAME"
brew audit --strict --online --cask "$CASK_NAME"

EXPECTED_VERSION="$(brew info --json=v2 --cask "$CASK_NAME" | ruby -rjson -e 'puts JSON.parse(STDIN.read).fetch("casks").fetch(0).fetch("version")')"

brew install --cask "$CASK_NAME"
brew install --cask "$CASK_NAME"
brew upgrade --cask "$CASK_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Homebrew did not install AgentMeter.app" >&2
  exit 1
fi

INSTALLED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ "$INSTALLED_VERSION" != "$EXPECTED_VERSION" ]]; then
  echo "Installed version mismatch: $INSTALLED_VERSION != $EXPECTED_VERSION" >&2
  exit 1
fi

ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/AgentMeter")"
if [[ " $ARCHITECTURES " != *" arm64 "* || " $ARCHITECTURES " != *" x86_64 "* ]]; then
  echo "Installed app is not universal: $ARCHITECTURES" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
xcrun stapler validate "$APP_PATH"

brew uninstall --cask "$CASK_NAME"
brew install --cask "$CASK_NAME"
brew uninstall --zap --cask "$CASK_NAME"

echo "AgentMeter Cask validation passed for $EXPECTED_VERSION on $(uname -m)."
