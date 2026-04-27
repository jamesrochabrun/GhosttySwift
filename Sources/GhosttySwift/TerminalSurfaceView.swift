import SwiftUI

public typealias TerminalPanelClosePolicy = (TerminalPanel) -> Bool
public typealias TerminalTabClosePolicy = (TerminalPanel, TerminalTab) -> Bool
public typealias TerminalPanelCloseHandler = (TerminalPanel) -> Void
public typealias TerminalTabCloseHandler = (TerminalPanel, TerminalTab) -> Void

@MainActor
public struct TerminalSurfaceView: View {
  private let session: TerminalSession
  private let showsPaneLabels: Bool
  private let showsTabBar: Bool
  private let allowsClosingPanels: Bool
  private let allowsClosingTabs: Bool
  private let panelClosePolicy: TerminalPanelClosePolicy?
  private let tabClosePolicy: TerminalTabClosePolicy?
  private let onClosePanel: TerminalPanelCloseHandler?
  private let onCloseTab: TerminalTabCloseHandler?

  public init(
    session: TerminalSession,
    showsPaneLabels: Bool = false,
    showsTabBar: Bool = true,
    allowsClosingPanels: Bool = true,
    allowsClosingTabs: Bool = true,
    panelClosePolicy: TerminalPanelClosePolicy? = nil,
    tabClosePolicy: TerminalTabClosePolicy? = nil,
    onClosePanel: TerminalPanelCloseHandler? = nil,
    onCloseTab: TerminalTabCloseHandler? = nil
  ) {
    self.session = session
    self.showsPaneLabels = showsPaneLabels
    self.showsTabBar = showsTabBar
    self.allowsClosingPanels = allowsClosingPanels
    self.allowsClosingTabs = allowsClosingTabs
    self.panelClosePolicy = panelClosePolicy
    self.tabClosePolicy = tabClosePolicy
    self.onClosePanel = onClosePanel
    self.onCloseTab = onCloseTab
  }

  public var body: some View {
    if let splitLayout = session.splitLayout, session.visiblePanels.count > 1 {
      layoutView(for: splitLayout.root)
    } else if let panel = session.visiblePanels.first {
      paneView(for: panel)
    } else {
      Text("No terminal available")
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func layoutView(for node: TerminalSplitLayout.Node) -> AnyView {
    switch node {
    case .panel(let panelID):
      if let panel = session.panel(for: panelID) {
        AnyView(paneView(for: panel))
      } else {
        AnyView(EmptyView())
      }
    case .split(let axis, let children):
      AnyView(splitView(axis: axis, children: children))
    }
  }

  private func splitView(
    axis: TerminalSplitAxis,
    children: [TerminalSplitLayout.Node]
  ) -> some View {
    GeometryReader { proxy in
      let dividerSize = 1.0
      let childCount = max(children.count, 1)

      switch axis {
      case .horizontal:
        let totalDividerWidth = dividerSize * Double(max(children.count - 1, 0))
        let childWidth = max(0, proxy.size.width - totalDividerWidth) / Double(childCount)

        HStack(spacing: 0) {
          ForEach(Array(children.enumerated()), id: \.offset) { offset, child in
            if offset > 0 {
              splitDivider(axis: axis)
            }
            layoutView(for: child)
              .frame(width: childWidth, height: proxy.size.height)
          }
        }
      case .vertical:
        let totalDividerHeight = dividerSize * Double(max(children.count - 1, 0))
        let childHeight = max(0, proxy.size.height - totalDividerHeight) / Double(childCount)

        VStack(spacing: 0) {
          ForEach(Array(children.enumerated()), id: \.offset) { offset, child in
            if offset > 0 {
              splitDivider(axis: axis)
            }
            layoutView(for: child)
              .frame(width: proxy.size.width, height: childHeight)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func splitDivider(axis: TerminalSplitAxis) -> some View {
    switch axis {
    case .horizontal:
      Color.primary.opacity(0.35)
        .frame(width: 1)
    case .vertical:
      Color.primary.opacity(0.35)
        .frame(height: 1)
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
      onCloseTab: { tab in closeTab(tab, in: panel) }
    )
  }

  private func canClosePanel(_ panel: TerminalPanel) -> Bool {
    guard allowsClosingPanels && panel.id != session.primaryPanelID else {
      return false
    }

    return panelClosePolicy?(panel) ?? true
  }

  private func canCloseTab(
    _ tab: TerminalTab,
    in panel: TerminalPanel
  ) -> Bool {
    guard allowsClosingTabs && TerminalPanel.canCloseTab(
      panelRole: panel.role,
      tabCount: panel.tabs.count
    ) else {
      return false
    }

    return tabClosePolicy?(panel, tab) ?? true
  }

  private func closePanel(_ panel: TerminalPanel) {
    if let onClosePanel {
      onClosePanel(panel)
    } else {
      _ = session.closePanel(panel.id)
    }
  }

  private func closeTab(_ tab: TerminalTab, in panel: TerminalPanel) {
    if let onCloseTab {
      onCloseTab(panel, tab)
    } else {
      _ = session.closeTab(tab.id, in: panel.id)
    }
  }
}
