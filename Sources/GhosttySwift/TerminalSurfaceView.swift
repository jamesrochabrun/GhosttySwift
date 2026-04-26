import SwiftUI

@MainActor
public struct TerminalSurfaceView: View {
  private let session: TerminalSession
  private let showsPaneLabels: Bool
  private let showsTabBar: Bool
  private let allowsClosingPanels: Bool
  private let allowsClosingTabs: Bool

  public init(
    session: TerminalSession,
    showsPaneLabels: Bool = false,
    showsTabBar: Bool = true,
    allowsClosingPanels: Bool = true,
    allowsClosingTabs: Bool = true
  ) {
    self.session = session
    self.showsPaneLabels = showsPaneLabels
    self.showsTabBar = showsTabBar
    self.allowsClosingPanels = allowsClosingPanels
    self.allowsClosingTabs = allowsClosingTabs
  }

  public var body: some View {
    if let splitLayout = session.splitLayout, session.visiblePanels.count > 1 {
      switch splitLayout.axis {
      case .horizontal:
        HSplitView {
          ForEach(session.visiblePanels) { panel in
            paneView(for: panel)
          }
        }
      case .vertical:
        VSplitView {
          ForEach(session.visiblePanels) { panel in
            paneView(for: panel)
          }
        }
      }
    } else if let panel = session.visiblePanels.first {
      paneView(for: panel)
    } else {
      Text("No terminal available")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func paneView(for panel: TerminalPanel) -> some View {
    TerminalSurfacePaneView(
      panel: panel,
      isActive: panel.id == session.activePanelID && session.visiblePanels.count > 1,
      showsPaneLabel: showsPaneLabels,
      showsTabBar: showsTabBar && (panel.tabs.count > 1 || session.visiblePanels.count > 1),
      canClosePanel: canClosePanel(panel),
      canCloseTab: { tab in canCloseTab(tab, in: panel) },
      onActivate: { session.focusPanel(panel.id) },
      onClosePanel: { closePanel(panel) },
      onSelectTab: { tab in session.selectTab(tab.id, in: panel.id) },
      onCloseTab: { tab in session.closeTab(tab.id, in: panel.id) }
    )
  }

  private func canClosePanel(_ panel: TerminalPanel) -> Bool {
    allowsClosingPanels && panel.id != session.primaryPanelID
  }

  private func canCloseTab(
    _ tab: TerminalTab,
    in panel: TerminalPanel
  ) -> Bool {
    allowsClosingTabs && TerminalPanel.canCloseTab(
      panelRole: panel.role,
      tabCount: panel.tabs.count
    )
  }

  private func closePanel(_ panel: TerminalPanel) {
    _ = session.closePanel(panel.id)
  }
}
