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
