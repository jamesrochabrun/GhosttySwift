# GhosttySwift

Swift Package wrapper around upstream [Ghostty](https://github.com/ghostty-org/ghostty)
for embedding a real macOS terminal surface in SwiftUI or AppKit apps.

Current scope:

- package scaffold
- upstream Ghostty build script
- bundled `share/ghostty` resources
- one AppKit surface
- one SwiftUI wrapper
- session model with primary and auxiliary terminals
- optional split-pane and pane-local tab SwiftUI host
- one sample app that renders a real shell prompt
- keyboard forwarding
- IME and dead-key composition
- mouse forwarding
- clipboard integration
- one-line SwiftUI and AppKit embedding entry points
- built-in search, secure-input, native scrollbar hosting, and child-exit UI for embedded hosts

Not in scope yet:

- tabs
- persistence

## Provenance

- Upstream Ghostty is the code-level implementation source of truth for this repo.
- Allowed implementation references: upstream Ghostty C API, upstream Ghostty macOS
  sources, upstream Ghostty examples, Ghostling, Apple AppKit/SwiftUI docs, and
  behavior re-derived from first principles.
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
import GhosttySwift
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

## Manage A Session

```swift
import GhosttySwift
import SwiftUI

struct ContentView: View {
  @State private var session: TerminalSession?

  var body: some View {
    Group {
      if let session {
        TerminalSurfaceView(session: session, showsPaneLabels: true)
      } else {
        ProgressView()
      }
    }
    .task {
      guard session == nil else { return }

      let session = try? TerminalSession(
        primaryConfiguration: GhosttySurfaceConfiguration(
          workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        ),
        primaryName: "Main"
      )

      self.session = session
    }
  }

  private func openTestPanel() {
    try? session?.openPanel(named: "Tests", axis: .horizontal)
  }

  private func openTestTab() {
    try? session?.openTab(named: "Logs")
  }
}
```

`TerminalSession` keeps one primary panel plus any number of auxiliary panels
alive under a shared `GhosttyRuntime`. Each panel owns one or more tabs and
renders only its active tab. It shows only the primary panel by default. Call
`openPanel(...)`, `openTab(...)`, or `showSplit(...)` when the host app wants
visible split panes or pane-local tab stacks.

The sample app uses this same model: it opens one terminal on launch, then lets
you add split panels with `Cmd+D` or `Cmd+Shift+D`, open a tab with `Cmd+T`,
close the active tab with `Cmd+W`, and close an auxiliary panel with
`Cmd+Shift+W`. The primary panel's last tab is not closed by these sample
commands.

## Embed In AppKit

```swift
import AppKit
import GhosttySwift

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
import GhosttySwift
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
