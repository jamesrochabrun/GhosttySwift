#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY_DIR="$ROOT/ThirdParty/ghostty"
FRAMEWORKS_DIR="$ROOT/Frameworks"
RESOURCES_DIR="$ROOT/Sources/GhosttySwiftPermissive/Resources"

if command -v zig >/dev/null 2>&1; then
  ZIG=(zig)
elif command -v mise >/dev/null 2>&1; then
  ZIG=(mise exec -- zig)
else
  echo "Missing zig on PATH and mise is unavailable." >&2
  exit 1
fi

if [[ ! -d "$GHOSTTY_DIR" ]]; then
  echo "Missing upstream Ghostty checkout at $GHOSTTY_DIR" >&2
  exit 1
fi

pushd "$GHOSTTY_DIR" >/dev/null
"${ZIG[@]}" build -Demit-macos-app=false -Demit-xcframework=true
popd >/dev/null

mkdir -p "$FRAMEWORKS_DIR"
rm -rf "$FRAMEWORKS_DIR/GhosttyKit.xcframework"
cp -R "$GHOSTTY_DIR/macos/GhosttyKit.xcframework" "$FRAMEWORKS_DIR/"

MACOS_SLICE="$FRAMEWORKS_DIR/GhosttyKit.xcframework/macos-arm64_x86_64"
INFO_PLIST="$FRAMEWORKS_DIR/GhosttyKit.xcframework/Info.plist"
if [[ -f "$MACOS_SLICE/ghostty-internal.a" ]]; then
  mv "$MACOS_SLICE/ghostty-internal.a" "$MACOS_SLICE/libghostty-internal.a"
  plutil -replace AvailableLibraries.2.BinaryPath -string libghostty-internal.a "$INFO_PLIST"
  plutil -replace AvailableLibraries.2.LibraryPath -string libghostty-internal.a "$INFO_PLIST"
fi

mkdir -p "$RESOURCES_DIR"
rm -rf "$RESOURCES_DIR/share"
cp -R "$GHOSTTY_DIR/zig-out/share" "$RESOURCES_DIR/"

echo "Built GhosttyKit.xcframework and refreshed bundled Ghostty resources."
