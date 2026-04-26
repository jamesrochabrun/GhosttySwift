import AppKit
import GhosttySwift
import SwiftUI

struct ContentView: View {
  @State private var session: TerminalSession?

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
          openPanel(axis: .horizontal)
        } label: {
          Label("Split Right", systemImage: "rectangle.split.2x1")
        }
        .keyboardShortcut("d", modifiers: .command)
        .disabled(session == nil)

        Button {
          openPanel(axis: .vertical)
        } label: {
          Label("Split Down", systemImage: "rectangle.split.1x2")
        }
        .keyboardShortcut("d", modifiers: [.command, .shift])
        .disabled(session == nil)

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
          _ = session?.closeActiveTab()
        } label: {
          Label("Close Tab", systemImage: "xmark.rectangle")
        }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(session?.canCloseActiveTab != true)

        Button {
          _ = session?.closeLastPanel()
        } label: {
          Label("Close Panel", systemImage: "xmark")
        }
        .keyboardShortcut("w", modifiers: [.command, .shift])
        .disabled(session?.auxiliaryPanels.isEmpty != false)
      }
    }
    .task {
      loadSessionIfNeeded()
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
  private func openPanel(axis: TerminalSplitAxis) {
    guard let session else { return }

    do {
      let panel = try session.openPanel(
        axis: axis
      )
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
}
