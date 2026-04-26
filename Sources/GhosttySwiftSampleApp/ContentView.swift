import AppKit
import GhosttySwift
import SwiftUI

struct ContentView: View {
  @State private var session: TerminalSession?
  @State private var keyMonitor: Any?

  var body: some View {
    let _ = SampleTrace.write("content view body")
    return Group {
      if let session {
        TerminalSurfaceView(session: session)
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 960, minHeight: 600)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button {
          openPanel()
        } label: {
          Label("New Pane", systemImage: "rectangle.split.2x1")
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(session?.canOpenPanel != true)

        Button {
          session?.showPrimaryOnly()
        } label: {
          Label("Single Panel", systemImage: "square")
        }
        .disabled(session?.splitLayout == nil)

        Button {
          openTab()
        } label: {
          Label("New Tab", systemImage: "plus.rectangle.on.rectangle")
        }
        .keyboardShortcut("t", modifiers: .command)
        .disabled(session == nil)

        Button {
          disableCommandW()
        } label: {
          Label("Close Tab", systemImage: "xmark.rectangle")
        }
        .keyboardShortcut("w", modifiers: .command)
        .help("Cmd+W is disabled")

        Button {
          closeLastPanel()
        } label: {
          Label("Close Panel", systemImage: "xmark")
        }
        .keyboardShortcut("w", modifiers: [.command, .shift])
        .help(session?.auxiliaryPanels.isEmpty == false ? "Close Panel" : "No auxiliary panel to close")
      }
    }
    .task {
      loadSessionIfNeeded()
    }
    .onAppear {
      installKeyMonitorIfNeeded()
    }
    .onDisappear {
      removeKeyMonitor()
    }
  }

  @MainActor
  private func loadSessionIfNeeded() {
    guard session == nil else { return }

    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path

    do {
      let session = try TerminalSession(
        primaryConfiguration: GhosttySurfaceConfiguration(
          workingDirectory: homeDirectory
        )
      )
      self.session = session
    } catch {
      SampleTrace.write("failed to create session: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func openPanel() {
    guard let session else { return }

    do {
      let panel = try session.openPanel()
      session.focusPanel(panel.id)
    } catch {
      SampleTrace.write("failed to open panel: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func openTab() {
    guard let session else { return }

    do {
      try session.openTab()
    } catch {
      SampleTrace.write("failed to open tab: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func closeLastPanel() {
    _ = session?.closeLastPanel()
  }

  @MainActor
  private func focusPanel(direction: TerminalPanelNavigationDirection) {
    _ = session?.focusPanel(direction: direction)
  }

  @MainActor
  private func selectTab(direction: TerminalTabNavigationDirection) {
    _ = session?.selectTab(direction: direction)
  }

  @MainActor
  private func disableCommandW() {
    SampleTrace.write("Cmd+W disabled")
  }

  @MainActor
  private func installKeyMonitorIfNeeded() {
    guard keyMonitor == nil else { return }

    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      handleKeyEvent(event) ? nil : event
    }
  }

  @MainActor
  private func removeKeyMonitor() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }
  }

  @MainActor
  private func handleKeyEvent(_ event: NSEvent) -> Bool {
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

    if modifiers == [.command] {
      switch event.keyCode {
      case 123:
        focusPanel(direction: .left)
        return true
      case 124:
        focusPanel(direction: .right)
        return true
      case 125:
        focusPanel(direction: .down)
        return true
      case 126:
        focusPanel(direction: .up)
        return true
      default:
        return false
      }
    }

    if modifiers == [.command, .shift] {
      switch event.keyCode {
      case 123:
        selectTab(direction: .previous)
        return true
      case 124:
        selectTab(direction: .next)
        return true
      default:
        return false
      }
    }

    return false
  }
}
