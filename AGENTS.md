# GhosttySwift Agent Guide

## Project Purpose

GhosttySwift is a Swift Package wrapper around upstream Ghostty for embedding a
real macOS terminal surface in SwiftUI or AppKit apps. The package owns the
terminal runtime, surface bridge, rendering host, session model, and sample app.
Embedding apps own product policy such as shortcuts, window behavior, and where
configuration files come from.

## Architecture

- `GhosttyRuntime` wraps one upstream `ghostty_app_t` plus its finalized Ghostty
  config. Create one runtime when multiple terminal surfaces should share config
  and clipboard/runtime state.
- `GhosttySurfaceView` is the low-level AppKit `NSView` that owns a single
  upstream `ghostty_surface_t` and forwards keyboard, mouse, IME, pasteboard,
  sizing, focus, cursor, and preedit events.
- `GhosttyTerminalContainerView` hosts `GhosttySurfaceView` with scroll/search,
  secure-input, and child-exit overlays.
- `GhosttyTerminalView` is the one-line SwiftUI `NSViewRepresentable` wrapper
  for a single terminal.
- `GhosttyTerminalController` exposes host-observable state such as title,
  working directory, size limits, search state, scrollbar state, notifications,
  and close events.
- `TerminalSession` models one primary panel plus auxiliary panels, pane-local
  tabs, active panel focus, and deterministic pane layouts.
- `TerminalSurfaceView` renders a `TerminalSession` in SwiftUI. It does not own
  global app shortcuts.
- `GhosttySwiftSampleApp` is a host-app example. Its shortcuts demonstrate host
  policy and should not be treated as mandatory library behavior.

## Embedding Patterns

Use the simplest SwiftUI surface when one terminal is enough:

```swift
GhosttyTerminalView(
  configPath: "/Users/you/.config/ghostty/config",
  configuration: .init(workingDirectory: projectPath)
)
```

Use a controller when the host needs state callbacks:

```swift
let controller = try GhosttyTerminalController(
  configPath: configPath,
  configuration: .init(workingDirectory: projectPath)
)
controller.onStateChange = { controller in
  windowTitle = controller.title
}
```

Use a session when the host needs panes and tabs:

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

## Configuration

Pass a Ghostty config file path with `configPath` to `GhosttyRuntime`,
`GhosttyTerminalView`, `GhosttyTerminalController`, `TerminalSession`, or
`TerminalManager`. The path is loaded through Ghostty's config loader and applies
to the runtime. If `configPath` is omitted, Ghostty's default config files are
loaded.

Use `GhosttySurfaceConfiguration` for per-surface host overrides only:
`workingDirectory`, `command`, `initialInput`, and explicit `fontSize`.

The wrapper does not currently expose in-memory config strings, config
diagnostics, or live config reload. If a host generates config dynamically, write
it to a file and pass the path.

## Shortcut Policy

Do not add global shortcut ownership to reusable library views. Host apps should
map their shortcuts to public session/controller APIs:

- `Cmd+D`: host may call `session.openPanel()`.
- `Cmd+Arrow`: host may call `session.focusPanel(direction:)`.
- `Cmd+Shift+Left/Right`: host may call `session.selectTab(direction:)`.
- `Cmd+W`: host must decide whether to close a tab, close a pane, no-op, or let
  macOS close the window.

The sample app uses an exact AppKit local key monitor because SwiftUI shortcut
matching can collapse shifted arrow shortcuts into unshifted commands.

## Embedded Resize Safety

`GhosttySurfaceView` is IOSurface-backed, so resize code must keep AppKit layer
dimensions and `ghostty_surface_set_size` in lockstep. Disable implicit layer
actions during resize and skip zero or sub-minimum transient sizes; otherwise
Core Animation can stretch stale frames and Ghostty can receive invalid grids.

## Binary Release Workflow

`GhosttyKit.xcframework` is a generated binary artifact. Do not commit it to git
and do not restore the package manifest to a local `Frameworks/` path for public
tags. Public GhosttySwift versions must be self-contained for SwiftPM consumers:
`Package.swift` at the tag must reference that same version's
`GhosttyKit.xcframework.zip` release asset with the matching checksum.

Consumers should only need to pin a version, for example:

```swift
.package(url: "https://github.com/jamesrochabrun/GhosttySwift", exact: "1.0.4")
```

To publish a release when the framework binary has not changed, run the
`Release GhosttySwift` GitHub Action with:

- `version`: the new version, such as `1.0.4`
- `binary_source`: `carry-forward`
- `source_release`: the previous release, or `latest`

The workflow downloads the previous `GhosttyKit.xcframework.zip`, updates
`Package.swift` to the new release URL/checksum, commits the manifest change,
tags the commit, creates the release, and uploads the binary asset.

For local release preparation or updated framework binaries, use:

```sh
Scripts/prepare-binary-release.sh --version 1.0.4 --source-release 1.0.3
Scripts/prepare-binary-release.sh --version 1.0.4 --artifact Frameworks/GhosttyKit.xcframework
Scripts/prepare-binary-release.sh --version 1.0.4 --build
```

`--build` runs `Scripts/build-ghostty.sh` first, so it requires the upstream
Ghostty build toolchain. After any binary release preparation, verify
`Package.swift` points at `releases/download/<version>/GhosttyKit.xcframework.zip`
and uses the checksum printed by the script.

## Development Rules

- Treat upstream Ghostty and `GhosttyKit` as the source of terminal behavior.
- Do not edit `ThirdParty/ghostty` unless the task explicitly requires upstream
  vendored changes.
- Prefer adding wrapper APIs over reaching into low-level handles from sample or
  host code.
- Keep host policy in the sample app or caller; keep reusable terminal behavior
  in `Sources/GhosttySwift`.
- Run `swift test --package-path /Users/jamesrochabrun/Desktop/git/GhosttySwift`
  for behavior changes and `git diff --check` before publishing.
