# Provenance

This repository exists to provide an embeddable Swift wrapper around upstream
[Ghostty](https://github.com/ghostty-org/ghostty) without carrying forward code
provenance risk from earlier derivative work.

## Source Of Truth

The implementation source of truth for this repository is upstream Ghostty under
the MIT license:

- `ThirdParty/ghostty/`
- upstream `include/ghostty.h`
- upstream `macos/Sources/...`
- upstream build artifacts and examples produced from that source tree

When behavior is unclear, the order of reference is:

1. Upstream Ghostty C API and headers
2. Upstream Ghostty macOS implementation
3. Upstream Ghostty examples and Ghostling
4. Apple platform documentation
5. Fresh implementation derived from observed behavior

## Non-Reference Inputs

The following are not approved implementation references for this repository:

- the earlier local `GhosttySwift` repository
- local `supacode`
- diffs, snippets, or notes copied from either of those repositories

Those repositories may be used only as behavioral checklists at a product level.
They are not valid code-level references for implementation or debugging.

## File Ledger

Status meanings:

- `upstream-vendored`: imported directly from upstream as a third-party dependency
- `fresh-wrapper`: authored in this repo, intended to wrap upstream APIs
- `rewrite-queued`: fresh wrapper that should be re-authored or re-validated
  directly from upstream MIT sources because it sits in a high-risk area
- `non-product`: local debugging or sample-only support code

| Path | Status | Primary MIT reference |
| --- | --- | --- |
| `ThirdParty/ghostty/` | upstream-vendored | Upstream Ghostty repo |
| `Scripts/build-ghostty.sh` | fresh-wrapper | `build.zig`, `src/build/GhosttyXCFramework.zig` |
| `Package.swift` | fresh-wrapper | upstream xcframework build shape and `example/swift-vt-xcframework/Package.swift` |
| `THIRD_PARTY_NOTICES.md` | fresh-wrapper | upstream Ghostty LICENSE |
| `Sources/GhosttySwiftPermissive/GhosttyRuntime.swift` | fresh-wrapper | `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwiftPermissive/GhosttySurfaceView.swift` | fresh-wrapper | `macos/Sources/Ghostty/Surface View/SurfaceView.swift`, `SurfaceView_AppKit.swift` |
| `Sources/GhosttySwiftPermissive/GhosttySurfaceView+Input.swift` | fresh-wrapper | `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift`, `NSEvent+Extension.swift` |
| `Sources/GhosttySwiftPermissive/GhosttyKeyMap.swift` | fresh-wrapper | `macos/Sources/Ghostty/Ghostty.Input.swift`, `NSEvent+Extension.swift` |
| `Sources/GhosttySwiftPermissive/NSEvent+Ghostty.swift` | fresh-wrapper | `macos/Sources/Ghostty/NSEvent+Extension.swift` |
| `Sources/GhosttySwiftPermissive/GhosttyMouseMap.swift` | fresh-wrapper | upstream surface input handling |
| `Sources/GhosttySwiftPermissive/GhosttyPasteboard.swift` | fresh-wrapper | `macos/Sources/Helpers/Extensions/NSPasteboard+Extension.swift`, `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwiftPermissive/GhosttySurfaceBridge.swift` | fresh-wrapper | `ghostty.h`, `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwiftPermissive/GhosttySurfaceConfiguration.swift` | fresh-wrapper | `ghostty.h` surface config API |
| `Sources/GhosttySwiftPermissive/GhosttyTerminalController.swift` | fresh-wrapper | Apple Observation patterns, upstream Ghostty bridge/runtime behavior |
| `Sources/GhosttySwiftPermissive/GhosttyTerminalContainerView.swift` | fresh-wrapper | Apple AppKit container patterns, upstream Ghostty surface host shape |
| `Sources/GhosttySwiftPermissive/GhosttyTerminalView.swift` | fresh-wrapper | Apple AppKit/SwiftUI bridging patterns |
| `Sources/GhosttySwiftPermissive/GhosttyTrace.swift` | non-product | local debug support |
| `Sources/GhosttySwiftPermissiveSampleApp/*` | fresh-wrapper | local sample app only |
| `Tests/GhosttySwiftPermissiveTests/*` | fresh-wrapper | local verification only |

## Immediate Rewrite Queue

These files should be treated as the first provenance-hardening targets:

1. sample-app level session and tab APIs once they exist
2. deeper regression tests for key, mouse, clipboard, and action handling

The goal is not to copy upstream app-shell code wholesale. The goal is to
re-author each wrapper directly from upstream MIT runtime and surface behavior.

## Editing Rule

For any future change in a `rewrite-queued` file:

- consult only approved upstream MIT sources
- mention the upstream source file in the commit message or PR description
- avoid opening the old derivative repo during implementation

If a file is substantially re-authored from upstream MIT sources, update its
status in the ledger.
