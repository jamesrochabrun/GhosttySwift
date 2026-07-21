#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GHOSTTY_DIR="$ROOT/ThirdParty/ghostty"
FRAMEWORKS_DIR="$ROOT/Frameworks"
RESOURCES_DIR="$ROOT/Sources/GhosttySwift/Resources"

if command -v zig >/dev/null 2>&1; then
  ZIG=(zig)
elif command -v mise >/dev/null 2>&1; then
  ZIG=(mise exec -- zig)
else
  echo "Missing zig on PATH and mise is unavailable." >&2
  exit 1
fi

if [[ ! -f "$GHOSTTY_DIR/build.zig" ]]; then
  echo "Missing upstream Ghostty checkout at $GHOSTTY_DIR; initialize the submodule first." >&2
  exit 1
fi

# zig 0.15.2 cannot link native macOS binaries against the macOS 26.x SDK
# (its linker fails to resolve libSystem from that SDK's tbd files), which
# breaks even zig's own build runner. Probe for the failure and, when an
# older Command Line Tools SDK is available, shim `xcrun --show-sdk-path`
# so zig's SDK detection resolves to the older SDK instead.
# The probe must run from inside the repo so mise can resolve zig from
# mise.toml; emit and cache into the temp dir to keep the repo clean.
probe_native_link() {
  local dir
  dir="$(mktemp -d)"
  printf 'pub fn main() void {}\n' > "$dir/probe.zig"
  (cd "$ROOT" && "${ZIG[@]}" build-exe "$dir/probe.zig" -lc \
    -femit-bin="$dir/probe" --cache-dir "$dir/zig-cache" >/dev/null 2>&1)
  local status=$?
  rm -rf "$dir"
  return $status
}

if ! probe_native_link; then
  FALLBACK_SDK=""
  for candidate in /Library/Developer/CommandLineTools/SDKs/MacOSX*.*.sdk; do
    [[ -d "$candidate" && ! -L "$candidate" ]] || continue
    version="$(basename "$candidate" | sed -E 's/MacOSX([0-9.]+)\.sdk/\1/')"
    if [[ "${version%%.*}" -lt 26 ]]; then
      FALLBACK_SDK="$candidate"
    fi
  done
  if [[ -z "$FALLBACK_SDK" ]]; then
    echo "zig cannot link native binaries against the active macOS SDK, and no pre-26 fallback SDK exists under /Library/Developer/CommandLineTools/SDKs." >&2
    exit 1
  fi
  SHIM_DIR="$(mktemp -d)"
  cat > "$SHIM_DIR/xcrun" <<SHIM
#!/bin/bash
if [[ "\$*" == *"--show-sdk-path"* && "\$*" == *macosx* ]]; then
  echo "$FALLBACK_SDK"
  exit 0
fi
exec /usr/bin/xcrun "\$@"
SHIM
  chmod +x "$SHIM_DIR/xcrun"
  export PATH="$SHIM_DIR:$PATH"
  echo "warning: zig cannot link against the active macOS SDK; routing zig SDK detection to $FALLBACK_SDK" >&2
  if ! probe_native_link; then
    echo "zig still cannot link native binaries with fallback SDK $FALLBACK_SDK." >&2
    exit 1
  fi
fi

pushd "$GHOSTTY_DIR" >/dev/null
"${ZIG[@]}" build -Doptimize=ReleaseFast -Demit-macos-app=false -Demit-xcframework=true
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

MACOS_LIBRARY="$MACOS_SLICE/libghostty-internal.a"
if [[ ! -f "$MACOS_LIBRARY" ]]; then
  echo "Missing macOS Ghostty library at $MACOS_LIBRARY" >&2
  exit 1
fi

VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT
xcrun swiftc \
  -I "$MACOS_SLICE/Headers" \
  -L "$MACOS_SLICE" \
  -lghostty-internal \
  -lc++ \
  -framework AppKit \
  -framework Carbon \
  -framework CoreVideo \
  -framework IOSurface \
  -framework Metal \
  -framework QuartzCore \
  "$ROOT/Scripts/verify-ghostty-build-mode.swift" \
  -o "$VERIFY_DIR/verify-ghostty-build-mode"
"$VERIFY_DIR/verify-ghostty-build-mode"

mkdir -p "$RESOURCES_DIR"
rm -rf "$RESOURCES_DIR/share"
cp -R "$GHOSTTY_DIR/zig-out/share" "$RESOURCES_DIR/"

echo "Built GhosttyKit.xcframework and refreshed bundled Ghostty resources."
