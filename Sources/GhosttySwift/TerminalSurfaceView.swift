import SwiftUI

@MainActor
public struct TerminalSurfaceView: View {
  private let session: TerminalSession
  private let showsPaneLabels: Bool
  private let allowsClosingPanels: Bool

  public init(
    session: TerminalSession,
    showsPaneLabels: Bool = false,
    allowsClosingPanels: Bool = true
  ) {
    self.session = session
    self.showsPaneLabels = showsPaneLabels
    self.allowsClosingPanels = allowsClosingPanels
  }

  public var body: some View {
    if let splitLayout = session.splitLayout, session.visibleTerminals.count > 1 {
      switch splitLayout.axis {
      case .horizontal:
        HSplitView {
          ForEach(session.visibleTerminals) { terminal in
            TerminalSurfacePaneView(
              terminal: terminal,
              showsPaneLabel: showsPaneLabels,
              canClose: canClose(terminal),
              onClose: { close(terminal) }
            )
          }
        }
      case .vertical:
        VSplitView {
          ForEach(session.visibleTerminals) { terminal in
            TerminalSurfacePaneView(
              terminal: terminal,
              showsPaneLabel: showsPaneLabels,
              canClose: canClose(terminal),
              onClose: { close(terminal) }
            )
          }
        }
      }
    } else if let terminal = session.visibleTerminals.first {
      TerminalSurfacePaneView(
        terminal: terminal,
        showsPaneLabel: showsPaneLabels,
        canClose: canClose(terminal),
        onClose: { close(terminal) }
      )
    } else {
      Text("No terminal available")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func canClose(_ terminal: TerminalSessionTerminal) -> Bool {
    allowsClosingPanels && terminal.id != session.primaryTerminalID
  }

  private func close(_ terminal: TerminalSessionTerminal) {
    _ = session.closePanel(terminal.id)
  }
}
