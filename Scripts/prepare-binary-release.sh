#!/usr/bin/env bash
set -euo pipefail

ASSET_NAME="GhosttyKit.xcframework.zip"
REPO_OWNER="jamesrochabrun"
REPO_NAME="GhosttySwift"

usage() {
  cat <<'USAGE'
Usage:
  Scripts/prepare-binary-release.sh --version VERSION (--source-release TAG | --artifact PATH | --build)

Prepares a SwiftPM binary release for GhosttySwift:
  - creates or downloads GhosttyKit.xcframework.zip
  - computes the SwiftPM checksum
  - updates Package.swift to point at the release asset URL for VERSION

Modes:
  --source-release TAG  Carry forward GhosttyKit.xcframework.zip from an existing release.
  --artifact PATH       Use a local .zip or GhosttyKit.xcframework directory.
  --build               Run Scripts/build-ghostty.sh, then package Frameworks/GhosttyKit.xcframework.

If --source-release is passed as "latest", the latest non-draft, non-prerelease
GitHub release is used.
USAGE
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=""
SOURCE_RELEASE=""
ARTIFACT_PATH=""
BUILD_FRAMEWORK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --source-release)
      [[ $# -ge 2 ]] || die "--source-release requires a value"
      SOURCE_RELEASE="$2"
      shift 2
      ;;
    --artifact)
      [[ $# -ge 2 ]] || die "--artifact requires a value"
      ARTIFACT_PATH="$2"
      shift 2
      ;;
    --build)
      BUILD_FRAMEWORK=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $1"
      ;;
  esac
done

[[ -n "$VERSION" ]] || die "--version is required"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || die "version must look like 1.0.4"

MODE_COUNT=0
[[ -n "$SOURCE_RELEASE" ]] && MODE_COUNT=$((MODE_COUNT + 1))
[[ -n "$ARTIFACT_PATH" ]] && MODE_COUNT=$((MODE_COUNT + 1))
[[ "$BUILD_FRAMEWORK" == true ]] && MODE_COUNT=$((MODE_COUNT + 1))
[[ "$MODE_COUNT" -eq 1 ]] || die "choose exactly one of --source-release, --artifact, or --build"

require_tool swift
require_tool zip
require_tool unzip
require_tool perl

DIST_DIR="$ROOT/.build/release-artifacts/$VERSION"
ZIP_PATH="$DIST_DIR/$ASSET_NAME"

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

if [[ -n "$SOURCE_RELEASE" ]]; then
  require_tool gh

  if [[ "$SOURCE_RELEASE" == "latest" ]]; then
    SOURCE_RELEASE="$(gh release list \
      --repo "$REPO_OWNER/$REPO_NAME" \
      --exclude-drafts \
      --exclude-pre-releases \
      --limit 1 \
      --json tagName \
      --jq '.[0].tagName')"
    [[ -n "$SOURCE_RELEASE" ]] || die "could not determine latest release"
  fi

  echo "Downloading $ASSET_NAME from release $SOURCE_RELEASE..."
  gh release download "$SOURCE_RELEASE" \
    --repo "$REPO_OWNER/$REPO_NAME" \
    --pattern "$ASSET_NAME" \
    --dir "$DIST_DIR" \
    --clobber
elif [[ -n "$ARTIFACT_PATH" ]]; then
  if [[ "$ARTIFACT_PATH" = /* ]]; then
    RESOLVED_ARTIFACT="$ARTIFACT_PATH"
  else
    RESOLVED_ARTIFACT="$PWD/$ARTIFACT_PATH"
  fi

  if [[ -d "$RESOLVED_ARTIFACT" ]]; then
    [[ "$(basename "$RESOLVED_ARTIFACT")" == "GhosttyKit.xcframework" ]] || die "directory artifact must be GhosttyKit.xcframework"
    echo "Zipping local GhosttyKit.xcframework..."
    (cd "$(dirname "$RESOLVED_ARTIFACT")" && zip -r -X -q "$ZIP_PATH" "GhosttyKit.xcframework")
  elif [[ -f "$RESOLVED_ARTIFACT" ]]; then
    [[ "$(basename "$RESOLVED_ARTIFACT")" == "$ASSET_NAME" ]] || die "zip artifact must be named $ASSET_NAME"
    cp "$RESOLVED_ARTIFACT" "$ZIP_PATH"
  else
    die "artifact not found: $ARTIFACT_PATH"
  fi
else
  "$ROOT/Scripts/build-ghostty.sh"
  FRAMEWORK_PATH="$ROOT/Frameworks/GhosttyKit.xcframework"
  [[ -d "$FRAMEWORK_PATH" ]] || die "build did not produce $FRAMEWORK_PATH"
  echo "Zipping built GhosttyKit.xcframework..."
  (cd "$ROOT/Frameworks" && zip -r -X -q "$ZIP_PATH" "GhosttyKit.xcframework")
fi

[[ -f "$ZIP_PATH" ]] || die "missing prepared artifact: $ZIP_PATH"
ZIP_LIST="$(unzip -l "$ZIP_PATH")"
grep -q 'GhosttyKit\.xcframework/' <<< "$ZIP_LIST" || die "$ASSET_NAME must contain GhosttyKit.xcframework at the archive root"

CHECKSUM="$(swift package --package-path "$ROOT" compute-checksum "$ZIP_PATH")"
ARTIFACT_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/$ASSET_NAME"

PACKAGE_FILE="$ROOT/Package.swift"
ARTIFACT_URL="$ARTIFACT_URL" CHECKSUM="$CHECKSUM" perl -0pi -e '
  my $url = $ENV{"ARTIFACT_URL"};
  my $checksum = $ENV{"CHECKSUM"};
  s#url: "https://github\.com/jamesrochabrun/GhosttySwift/releases/download/[^"]+/GhosttyKit\.xcframework\.zip",\n\s+checksum: "[0-9a-fA-F]+"#url: "$url",\n      checksum: "$checksum"#s
    or die "failed to update GhosttyKit binary target in Package.swift\n";
' "$PACKAGE_FILE"

swift package --package-path "$ROOT" dump-package >/dev/null

echo "Prepared GhosttySwift $VERSION binary release."
echo "Asset: $ZIP_PATH"
echo "URL: $ARTIFACT_URL"
echo "Checksum: $CHECKSUM"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "version=$VERSION"
    echo "asset_name=$ASSET_NAME"
    echo "zip_path=$ZIP_PATH"
    echo "artifact_url=$ARTIFACT_URL"
    echo "checksum=$CHECKSUM"
  } >> "$GITHUB_OUTPUT"
fi
