#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: scripts/update_agentmeter_cask.sh v<version>" >&2
  exit 2
fi

TAG="$1"
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid AgentMeter release tag: $TAG" >&2
  exit 1
fi

VERSION="${TAG#v}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASK_PATH="$REPO_ROOT/Casks/agentmeter.rb"
TASK_TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/private/tmp}}"
TEMP_DIR="$(mktemp -d "$TASK_TEMP_ROOT/agentmeter-cask-update.XXXXXX")"
MOUNT_POINT="$TEMP_DIR/mount"
DMG_PATH="$TEMP_DIR/AgentMeter.dmg"
VERSIONED_DMG_PATH=""
DMG_ATTACHED=0

cleanup() {
  if [[ "$DMG_ATTACHED" -eq 1 ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ ! -f "$CASK_PATH" ]]; then
  echo "Cask not found: $CASK_PATH" >&2
  exit 1
fi

CURRENT_VERSION="$(ruby -e 'text = File.read(ARGV.fetch(0)); abort("missing version") unless text =~ /^  version "([^"]+)"$/; puts Regexp.last_match(1)' "$CASK_PATH")"
CURRENT_SHA256="$(ruby -e 'text = File.read(ARGV.fetch(0)); abort("missing sha256") unless text =~ /^  sha256 "([0-9a-f]{64})"$/; puts Regexp.last_match(1)' "$CASK_PATH")"

ruby -rrubygems -e '
  current = Gem::Version.new(ARGV.fetch(0))
  incoming = Gem::Version.new(ARGV.fetch(1))
  abort("release downgrade refused: #{incoming} < #{current}") if incoming < current
' "$CURRENT_VERSION" "$VERSION"

DOWNLOAD_BASE="https://github.com/dothinkerlab/AgentMeter/releases/download/$TAG"
curl --fail --location --retry 3 --output "$DMG_PATH" "$DOWNLOAD_BASE/AgentMeter.dmg"

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

mkdir -p "$MOUNT_POINT"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_POINT" "$DMG_PATH" -quiet
DMG_ATTACHED=1

APP_PATH="$MOUNT_POINT/AgentMeter.app"
if [[ ! -d "$APP_PATH" || ! -L "$MOUNT_POINT/Applications" ]]; then
  echo "Release DMG does not contain AgentMeter.app and the Applications link" >&2
  exit 1
fi

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/AgentMeter"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
APP_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
APP_MINIMUM_MACOS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$INFO_PLIST")"

if [[ "$APP_VERSION" != "$VERSION" ]]; then
  echo "Tag/app version mismatch: $VERSION != $APP_VERSION" >&2
  exit 1
fi
if [[ ! "$APP_BUILD" =~ ^[0-9]+$ ]]; then
  echo "Invalid app build number: $APP_BUILD" >&2
  exit 1
fi
if [[ "$APP_BUNDLE_ID" != "com.dothinker.app.agentmeter.mac" ]]; then
  echo "Unexpected app bundle identifier: $APP_BUNDLE_ID" >&2
  exit 1
fi
if [[ "$APP_MINIMUM_MACOS" != "13.0" ]]; then
  echo "Unexpected minimum macOS version: $APP_MINIMUM_MACOS" >&2
  exit 1
fi

ARCHITECTURES="$(lipo -archs "$EXECUTABLE")"
if [[ " $ARCHITECTURES " != *" arm64 "* || " $ARCHITECTURES " != *" x86_64 "* ]]; then
  echo "AgentMeter executable is not universal: $ARCHITECTURES" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign -dvvv "$APP_PATH" 2> "$TEMP_DIR/codesign-details.txt"
grep -q 'Authority=Developer ID Application:' "$TEMP_DIR/codesign-details.txt"
grep -Eq '^flags=.*\(runtime\)' "$TEMP_DIR/codesign-details.txt"

codesign -d --entitlements :- "$APP_PATH" > "$TEMP_DIR/entitlements.plist"
CLOUDKIT_ENVIRONMENT="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.icloud-container-environment' "$TEMP_DIR/entitlements.plist")"
if [[ "$CLOUDKIT_ENVIRONMENT" != "Production" ]]; then
  echo "AgentMeter app does not use Production CloudKit" >&2
  exit 1
fi

xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"
hdiutil detach "$MOUNT_POINT" -quiet
DMG_ATTACHED=0
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

VERSIONED_DMG_NAME="AgentMeter-$VERSION-$APP_BUILD.dmg"
VERSIONED_DMG_PATH="$TEMP_DIR/$VERSIONED_DMG_NAME"
curl --fail --location --retry 3 --output "$VERSIONED_DMG_PATH" "$DOWNLOAD_BASE/$VERSIONED_DMG_NAME"
if ! cmp -s "$DMG_PATH" "$VERSIONED_DMG_PATH"; then
  echo "AgentMeter.dmg and $VERSIONED_DMG_NAME are not byte-identical" >&2
  exit 1
fi

curl --fail --location --retry 3 --output "$TEMP_DIR/SHA256SUMS.txt" "$DOWNLOAD_BASE/SHA256SUMS.txt"
if ! (cd "$TEMP_DIR" && shasum -a 256 --check SHA256SUMS.txt); then
  echo "Published SHA256SUMS.txt does not match the release assets" >&2
  exit 1
fi

if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
  if [[ "$SHA256" == "$CURRENT_SHA256" ]]; then
    echo "AgentMeter $VERSION is already current ($SHA256)."
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
      {
        echo "version=$VERSION"
        echo "build=$APP_BUILD"
        echo "sha256=$SHA256"
        echo "changed=false"
      } >> "$GITHUB_OUTPUT"
    fi
    exit 0
  fi

  echo "Published asset changed without a version bump: $CURRENT_SHA256 != $SHA256" >&2
  exit 1
fi

RELEASE_VERSION="$VERSION" RELEASE_SHA256="$SHA256" ruby -e '
  path = ARGV.fetch(0)
  text = File.read(path)
  version_count = text.scan(/^  version "[^"]+"$/).length
  sha_count = text.scan(/^  sha256 "[0-9a-f]{64}"$/).length
  abort("unexpected version stanza count: #{version_count}") unless version_count == 1
  abort("unexpected sha256 stanza count: #{sha_count}") unless sha_count == 1
  text.sub!(/^  version "[^"]+"$/, %(  version "#{ENV.fetch("RELEASE_VERSION")}"))
  text.sub!(/^  sha256 "[0-9a-f]{64}"$/, %(  sha256 "#{ENV.fetch("RELEASE_SHA256")}"))
  File.write(path, text)
' "$CASK_PATH"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$VERSION"
    echo "build=$APP_BUILD"
    echo "sha256=$SHA256"
    echo "changed=true"
  } >> "$GITHUB_OUTPUT"
fi

echo "Updated AgentMeter Cask to $VERSION ($APP_BUILD), SHA-256 $SHA256."
