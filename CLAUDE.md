# GhosttySwift Claude Guide

Follow `AGENTS.md` as the source of truth for repository architecture,
embedding patterns, shortcut policy, configuration, and development rules. This
file exists so Claude-based tools can find the same project guidance from the
repo root.

## What This Package Is

GhosttySwift embeds upstream Ghostty in SwiftUI/AppKit apps. The package wraps
Ghostty's runtime and surface APIs, then layers Swift-friendly controllers,
single-terminal views, session-based panes/tabs, and a sample host app on top.

## Key Boundaries

- Library code in `Sources/GhosttySwift` should expose reusable terminal
  primitives.
- `Sources/GhosttySwiftSampleApp` owns demo host behavior such as keyboard
  shortcuts.
- Host apps should wire shortcuts themselves using public APIs like
  `openPanel()`, `focusPanel(direction:)`, `openTab()`, and
  `selectTab(direction:)`.
- Ghostty config is supplied as a file path through `configPath`; generated
  config should be written to disk first.
- `GhosttySurfaceConfiguration` is not a full Ghostty config replacement. It is
  only for per-surface host overrides such as working directory, command,
  initial input, and font size.
- For embedded resize work, preserve the safety rules in `AGENTS.md`: keep
  AppKit layer size and Ghostty surface size aligned, disable implicit layer
  actions, and do not forward zero or sub-minimum transient sizes.

## Embedding Quick Reference

Single terminal:

```swift
GhosttyTerminalView(
  configPath: "/Users/you/.config/ghostty/config",
  configuration: .init(workingDirectory: projectPath)
)
```

Observable terminal:

```swift
let controller = try GhosttyTerminalController(
  configPath: configPath,
  configuration: .init(workingDirectory: projectPath)
)
```

Panes and tabs:

```swift
let session = try TerminalSession(
  configPath: configPath,
  primaryConfiguration: .init(workingDirectory: projectPath)
)

try session.openPanel()
try session.openTab()
session.focusPanel(direction: .right)
session.selectTab(direction: .next)
```

## Before Publishing Changes

Run:

```sh
swift test --package-path /Users/jamesrochabrun/Desktop/git/GhosttySwift
git diff --check
```

## Binary Release Notes

Do not commit `Frameworks/GhosttyKit.xcframework` to git. Public package tags
must use a remote SwiftPM binary target that points to the matching GitHub
release asset:

```text
https://github.com/jamesrochabrun/GhosttySwift/releases/download/<version>/GhosttyKit.xcframework.zip
```

For a new release that reuses the same framework binary, run the
`Release GhosttySwift` GitHub Action with `binary_source=carry-forward` and
`source_release=latest` or the previous tag. The action updates `Package.swift`,
commits, tags, creates the release, and uploads the zip asset.

For local preparation, use `Scripts/prepare-binary-release.sh`. It can carry
forward an existing release asset, package a local `GhosttyKit.xcframework`, or
run `Scripts/build-ghostty.sh` before packaging. Package consumers should not
need these steps; they only pin a released GhosttySwift version.
