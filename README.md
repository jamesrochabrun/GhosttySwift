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

## Ghostty Configuration

GhosttySwift can load a regular Ghostty config file by passing `configPath`
when creating the runtime-backed entry point:

```swift
let terminal = GhosttyTerminalView(
  configPath: "/Users/you/.config/ghostty/config",
  configuration: GhosttySurfaceConfiguration(
    workingDirectory: projectPath
  )
)
```

The same `configPath` parameter is available on `GhosttyTerminalController`,
`TerminalSession`, and `TerminalManager`:

```swift
let session = try TerminalSession(
  configPath: "/Users/you/.config/ghostty/config",
  primaryConfiguration: .init(workingDirectory: projectPath)
)
```

`configPath` is runtime-scoped. It controls Ghostty config values such as theme,
font family, palette, cursor settings, and Ghostty keybinds for every surface
created from that runtime. `GhosttySurfaceConfiguration` remains the
per-surface override layer for host concerns such as working directory, command,
initial input, and explicit font size.

If `configPath` is `nil`, GhosttySwift asks Ghostty to load its default config
files. GhosttySwift also lets Ghostty process recursive config includes before
finalizing the runtime config. Passing config text directly as an in-memory
string is not supported by the public wrapper today; write it to a file and pass
that file path.

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
    try? session?.openPanel(named: "Tests")
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
you add up to four visible panes with `Cmd+D`. Pane layout is count-based: two
panes are side-by-side, three panes keep the first pane full-height on the left
with the other two stacked on the right, and four panes form a 2x2 grid. Use
`Cmd+Arrow` to move between panes, `Cmd+T` to open a tab,
`Cmd+Shift+Left/Right` to move between tabs in the active pane, and
`Cmd+Shift+W` to close an auxiliary panel. The primary panel's last tab is not
closed by these sample commands.

The sample app currently claims `Cmd+W` as an enabled no-op so macOS does not
fall back to the standard Close Window command. If an embedding host wants
`Cmd+W` to close a terminal tab, it should register its own command and leave it
enabled even when the terminal action is a no-op.

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
