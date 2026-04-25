# Provenance

This ledger records the approved implementation references and attribution
boundaries for [Ghostty](https://github.com/ghostty-org/ghostty)-based code in
GhosttySwift.

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

The following are not approved code-level implementation references for this repository:

- unpublished local experiments
- private derivative wrappers
- copied diffs, snippets, or notes from either of those sources

Those sources may be used only as behavioral checklists at a product level.
They are not valid implementation or debugging references.

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
| `Sources/GhosttySwift/GhosttyRuntime.swift` | fresh-wrapper | `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwift/GhosttySurfaceView.swift` | fresh-wrapper | `macos/Sources/Ghostty/Surface View/SurfaceView.swift`, `SurfaceView_AppKit.swift`, `SurfaceScrollView.swift` |
| `Sources/GhosttySwift/GhosttySurfaceView+Input.swift` | fresh-wrapper | `macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift`, `NSEvent+Extension.swift` |
| `Sources/GhosttySwift/GhosttyKeyMap.swift` | fresh-wrapper | `macos/Sources/Ghostty/Ghostty.Input.swift`, `NSEvent+Extension.swift` |
| `Sources/GhosttySwift/NSEvent+Ghostty.swift` | fresh-wrapper | `macos/Sources/Ghostty/NSEvent+Extension.swift` |
| `Sources/GhosttySwift/GhosttyMouseMap.swift` | fresh-wrapper | upstream surface input handling |
| `Sources/GhosttySwift/GhosttyPasteboard.swift` | fresh-wrapper | `macos/Sources/Helpers/Extensions/NSPasteboard+Extension.swift`, `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwift/GhosttySurfaceBridge.swift` | fresh-wrapper | `ghostty.h`, `macos/Sources/Ghostty/Ghostty.App.swift` |
| `Sources/GhosttySwift/GhosttySurfaceConfiguration.swift` | fresh-wrapper | `ghostty.h` surface config API |
| `Sources/GhosttySwift/GhosttyTerminalController.swift` | fresh-wrapper | Apple Observation patterns, upstream Ghostty bridge/runtime behavior |
| `Sources/GhosttySwift/GhosttyTerminalContainerView.swift` | fresh-wrapper | Apple AppKit container patterns, upstream Ghostty surface host shape, `SurfaceScrollView.swift` |
| `Sources/GhosttySwift/GhosttyTerminalOverlayModel.swift` | fresh-wrapper | upstream search/secure-input/child-exit interaction patterns |
| `Sources/GhosttySwift/GhosttyTerminalOverlayView.swift` | fresh-wrapper | `macos/Sources/Ghostty/Surface View/SurfaceView.swift`, `SurfaceScrollView.swift`, `ChildExitedMessageBar.swift`, `Features/Secure Input/SecureInputOverlay.swift` |
| `Sources/GhosttySwift/GhosttyTerminalView.swift` | fresh-wrapper | Apple AppKit/SwiftUI bridging patterns |
| `Sources/GhosttySwift/GhosttyTrace.swift` | non-product | local debug support |
| `Sources/GhosttySwiftSampleApp/*` | fresh-wrapper | local sample app only |
| `Tests/GhosttySwiftTests/*` | fresh-wrapper | local verification only |

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
