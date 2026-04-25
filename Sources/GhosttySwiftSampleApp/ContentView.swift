import AppKit
import GhosttySwift
import SwiftUI

struct ContentView: View {
  @State private var session: TerminalSession?

  var body: some View {
    let _ = SampleTrace.write("content view body")
    return Group {
      if let session {
        TerminalSurfaceView(session: session, showsPaneLabels: session.splitLayout != nil)
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
          _ = session?.closeLastPanel()
        } label: {
          Label("Close Panel", systemImage: "xmark")
        }
        .keyboardShortcut("w", modifiers: .command)
        .disabled(session?.auxiliaryTerminals.isEmpty != false)
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
        ),
        primaryName: "Main"
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
      let panelIndex = session.auxiliaryTerminals.count + 1
      let panel = try session.openPanel(
        named: "Panel \(panelIndex)",
        axis: axis
      )
      panel.focus()
    } catch {
      SampleTrace.write("failed to open panel: \(error.localizedDescription)")
    }
  }
}
