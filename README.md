# GhosttySwiftPermissive

Fresh Swift Package wrapper around upstream [Ghostty](https://github.com/ghostty-org/ghostty),
implemented from permissive sources only, with upstream Ghostty as the
implementation source of truth.

This repo is intentionally separate from the earlier derivative prototype. The
current scope is the first clean milestone:

- package scaffold
- upstream Ghostty build script
- bundled `share/ghostty` resources
- one AppKit surface
- one SwiftUI wrapper
- one sample app that renders a real shell prompt
- keyboard forwarding
- mouse forwarding
- clipboard integration
- one-line SwiftUI and AppKit embedding entry points
- built-in search, secure-input, scrollbar, and child-exit overlays for embedded hosts

Not in scope yet:

- tabs or sessions
- splits
- persistence

## Provenance

- Upstream Ghostty is the only code-level implementation source of truth for this repo.
- Allowed implementation references: upstream Ghostty C API, upstream Ghostty macOS
  sources, upstream Ghostty examples, Ghostling, Apple AppKit/SwiftUI docs, and
  behavior re-derived from first principles.
- Non-reference sources: the earlier local `GhosttySwift` repo and local `supacode`.
- The current provenance ledger and rewrite queue live in [PROVENANCE.md](PROVENANCE.md).

## Build

From the repo root:

```sh
Scripts/build-ghostty.sh
swift build
Scripts/run-sample.sh
```

`Scripts/build-ghostty.sh` compiles upstream Ghostty into
`Frameworks/GhosttyKit.xcframework` and copies Ghostty's `share/ghostty`
resources into the SwiftPM target bundle.

`Scripts/run-sample.sh` wraps the sample executable in a `.app` bundle so it
activates as a regular macOS app.

## Third-Party Code

- `ThirdParty/ghostty/` is upstream Ghostty under the MIT license and tracked as a git submodule.
- `GhosttyKit.xcframework` is built locally from that upstream source and is
  intentionally ignored by git.
- Adapted upstream MIT wrapper files and the preserved Ghostty license notice
  are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Embed In SwiftUI

```swift
import GhosttySwiftPermissive
import SwiftUI

struct ContentView: View {
  var body: some View {
    GhosttyTerminalView(
      configuration: GhosttySurfaceConfiguration(
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
      )
    )
  }
}
```

If you need to share one runtime across multiple surfaces, create a
`GhosttyRuntime` yourself and pass it into `GhosttyTerminalView(runtime:...)`.

## Embed In AppKit

```swift
import AppKit
import GhosttySwiftPermissive

let terminalView = try GhosttyTerminalContainerView(
  configuration: GhosttySurfaceConfiguration(
    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
  )
)
```

`GhosttyTerminalContainerView` owns the runtime, surface, and scroll wrapper
for a single terminal host. Call `focusTerminal()` after inserting it into a
window if you want to claim first responder immediately.

## Observe Terminal State

If an embedding app wants title, working-directory, search, or close state
without reaching into the low-level bridge directly, create a
`GhosttyTerminalController` and pass it into the view:

```swift
import GhosttySwiftPermissive
import SwiftUI

struct ContentView: View {
  @State private var controller: GhosttyTerminalController?
  @State private var windowTitle = "Ghostty"

  var body: some View {
    Group {
      if let controller {
        GhosttyTerminalView(controller: controller)
      } else {
        ProgressView()
      }
    }
    .navigationTitle(windowTitle)
    .task {
      guard controller == nil else { return }
      let controller = try? GhosttyTerminalController(
        configuration: GhosttySurfaceConfiguration(
          workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
      )
      controller?.onStateChange = { controller in
        windowTitle = controller.title
      }
      windowTitle = controller?.title ?? windowTitle
      self.controller = controller
    }
  }
}
```
