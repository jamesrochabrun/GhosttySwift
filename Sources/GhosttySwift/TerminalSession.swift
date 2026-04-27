import Observation

@MainActor
@Observable
public final class TerminalSession {
  public let runtime: GhosttyRuntime
  public private(set) var panels: [TerminalPanel]
  public private(set) var primaryPanelID: TerminalPanelID
  public private(set) var activePanelID: TerminalPanelID
  public private(set) var splitLayout: TerminalSplitLayout?

  public init(
    runtime: GhosttyRuntime? = nil,
    configPath: String? = nil,
    primaryConfiguration: GhosttySurfaceConfiguration = .init(),
    primaryName: String? = nil
  ) throws {
    self.runtime = try runtime ?? GhosttyRuntime(configPath: configPath)

    let primaryTab = try TerminalSession.makeTab(
      runtime: self.runtime,
      name: primaryName,
      configuration: primaryConfiguration
    )
    let primaryPanel = TerminalPanel(
      role: .primary,
      name: primaryName,
      tabs: [primaryTab],
      activeTabID: primaryTab.id
    )

    self.panels = [primaryPanel]
    self.primaryPanelID = primaryPanel.id
    self.activePanelID = primaryPanel.id
    self.splitLayout = nil
  }

  public var primaryPanel: TerminalPanel {
    panel(for: primaryPanelID)!
  }

  public var activePanel: TerminalPanel {
    panel(for: activePanelID) ?? primaryPanel
  }

  public var auxiliaryPanels: [TerminalPanel] {
    panels.filter { $0.role == .auxiliary }
  }

  public var visiblePanels: [TerminalPanel] {
    let visibleIDs = splitLayout?.panelIDs ?? [primaryPanelID]
    return visibleIDs.compactMap { panel(for: $0) }
  }

  public var activeTab: TerminalTab? {
    activePanel.activeTab
  }

  public var defaultPanelConfiguration: GhosttySurfaceConfiguration {
    defaultTabConfiguration(for: primaryPanel)
  }

  public var canCloseActiveTab: Bool {
    activePanel.canCloseActiveTab
  }

  public var canOpenPanel: Bool {
    visiblePanels.count < 4
  }

  @discardableResult
  public func openPanel(
    named name: String? = nil,
    configuration: GhosttySurfaceConfiguration? = nil,
    axis: TerminalSplitAxis = .horizontal
  ) throws -> TerminalPanel {
    let tab = try TerminalSession.makeTab(
      runtime: runtime,
      name: name,
      configuration: configuration ?? defaultPanelConfiguration
    )
    let panel = TerminalPanel(
      role: .auxiliary,
      name: name,
      tabs: [tab],
      activeTabID: tab.id
    )

    panels.append(panel)

    let visibleIDs = splitLayout?.panelIDs ?? [primaryPanelID]
    self.splitLayout = TerminalSplitLayout.normalized(
      axis: axis,
      panelIDs: visibleIDs + [panel.id],
      availablePanelIDs: panels.map(\.id),
      primaryPanelID: primaryPanelID
    )

    activePanelID = panel.id
    panel.activeTab?.focus()
    return panel
  }

  @discardableResult
  public func closePanel(_ id: TerminalPanelID) -> Bool {
    guard id != primaryPanelID else { return false }
    guard let index = panels.firstIndex(where: { $0.id == id }) else { return false }

    panels.remove(at: index)

    if let splitLayout {
      self.splitLayout = splitLayout.removingPanel(
        id,
        availablePanelIDs: panels.map(\.id),
        primaryPanelID: primaryPanelID
      )
    }

    if activePanelID == id {
      activePanelID = primaryPanelID
      primaryPanel.activeTab?.focus()
    }

    return true
  }

  @discardableResult
  public func closeLastPanel() -> Bool {
    let visibleAuxiliaryID = visiblePanels.reversed().first { $0.id != primaryPanelID }?.id
    let fallbackAuxiliaryID = auxiliaryPanels.last?.id

    guard let panelID = visibleAuxiliaryID ?? fallbackAuxiliaryID else {
      return false
    }

    return closePanel(panelID)
  }

  @discardableResult
  public func openTab(
    in panelID: TerminalPanelID? = nil,
    named name: String? = nil,
    configuration: GhosttySurfaceConfiguration? = nil
  ) throws -> TerminalTab {
    let targetPanelID = panelID ?? activePanelID
    guard let panel = panel(for: targetPanelID) else {
      throw TerminalSessionError.panelNotFound
    }

    let tab = try TerminalSession.makeTab(
      runtime: runtime,
      name: name,
      configuration: configuration ?? defaultTabConfiguration(for: panel)
    )
    panel.appendTab(tab)
    activePanelID = panel.id
    tab.focus()
    return tab
  }

  @discardableResult
  public func closeTab(
    _ tabID: TerminalTabID,
    in panelID: TerminalPanelID
  ) -> Bool {
    guard let panel = panel(for: panelID) else { return false }

    if panel.tabs.count == 1 {
      return closePanel(panelID)
    }

    let didClose = panel.removeTab(tabID)
    if didClose {
      activePanelID = panelID
      panel.activeTab?.focus()
    }
    return didClose
  }

  @discardableResult
  public func closeActiveTab() -> Bool {
    guard let tabID = activePanel.activeTab?.id else { return false }
    return closeTab(tabID, in: activePanel.id)
  }

  @discardableResult
  public func selectTab(
    _ tabID: TerminalTabID,
    in panelID: TerminalPanelID
  ) -> Bool {
    guard let panel = panel(for: panelID), panel.selectTab(tabID) else {
      return false
    }

    activePanelID = panel.id
    panel.activeTab?.focus()
    return true
  }

  public func renamePanel(_ id: TerminalPanelID, to name: String?) {
    panel(for: id)?.name = name
  }

  public func renameTab(
    _ tabID: TerminalTabID,
    in panelID: TerminalPanelID,
    to name: String?
  ) {
    panel(for: panelID)?.tab(for: tabID)?.name = name
  }

  public func showPrimaryOnly() {
    splitLayout = nil
    activePanelID = primaryPanelID
  }

  public func showPrimaryAndFirstAuxiliary(axis: TerminalSplitAxis = .horizontal) {
    guard let firstAuxiliary = auxiliaryPanels.first else {
      showPrimaryOnly()
      return
    }

    showPrimaryAndAuxiliary(firstAuxiliary.id, axis: axis)
  }

  public func showPrimaryAndAuxiliary(
    _ auxiliaryID: TerminalPanelID,
    axis: TerminalSplitAxis = .horizontal
  ) {
    showSplit(axis: axis, panelIDs: [primaryPanelID, auxiliaryID])
  }

  public func showPrimaryAndAuxiliaries(axis: TerminalSplitAxis = .horizontal) {
    let panelIDs = [primaryPanelID] + auxiliaryPanels.map(\.id)
    showSplit(axis: axis, panelIDs: panelIDs)
  }

  public func showSplit(
    axis: TerminalSplitAxis = .horizontal,
    panelIDs: [TerminalPanelID]
  ) {
    splitLayout = TerminalSplitLayout.normalized(
      axis: axis,
      panelIDs: panelIDs,
      availablePanelIDs: panels.map(\.id),
      primaryPanelID: primaryPanelID
    )
  }

  public func requestCloseAll() {
    for panel in panels {
      for tab in panel.tabs {
        tab.controller.requestClose()
      }
    }
  }

  @discardableResult
  public func focusPanel(_ id: TerminalPanelID) -> Bool {
    guard let panel = panel(for: id) else { return false }
    activePanelID = panel.id
    panel.activeTab?.focus()
    return true
  }

  @discardableResult
  public func focusPanel(direction: TerminalPanelNavigationDirection) -> Bool {
    let visibleIDs = splitLayout?.panelIDs ?? [primaryPanelID]
    guard let targetID = Self.panelID(
      from: activePanelID,
      direction: direction,
      visibleIDs: visibleIDs
    ) else {
      return false
    }

    return focusPanel(targetID)
  }

  @discardableResult
  public func selectTab(direction: TerminalTabNavigationDirection) -> Bool {
    let panel = activePanel
    guard let targetTabID = Self.tabID(
      from: panel.activeTabID,
      direction: direction,
      tabIDs: panel.tabs.map(\.id)
    ) else {
      return false
    }

    return selectTab(targetTabID, in: panel.id)
  }

  public func panel(for id: TerminalPanelID) -> TerminalPanel? {
    panels.first { $0.id == id }
  }

  public func tab(
    for tabID: TerminalTabID,
    in panelID: TerminalPanelID
  ) -> TerminalTab? {
    panel(for: panelID)?.tab(for: tabID)
  }

  public func controller(
    for tabID: TerminalTabID,
    in panelID: TerminalPanelID
  ) -> GhosttyTerminalController? {
    tab(for: tabID, in: panelID)?.controller
  }

  public func containerView(
    for tabID: TerminalTabID,
    in panelID: TerminalPanelID
  ) -> GhosttyTerminalContainerView? {
    tab(for: tabID, in: panelID)?.containerView
  }

  nonisolated static func panelID(
    from activePanelID: TerminalPanelID,
    direction: TerminalPanelNavigationDirection,
    visibleIDs: [TerminalPanelID]
  ) -> TerminalPanelID? {
    guard let activeIndex = visibleIDs.firstIndex(of: activePanelID) else {
      return nil
    }

    switch visibleIDs.count {
    case 2:
      return twoPanePanelID(
        from: activeIndex,
        direction: direction,
        visibleIDs: visibleIDs
      )
    case 3:
      return threePanePanelID(
        from: activeIndex,
        direction: direction,
        visibleIDs: visibleIDs
      )
    case 4:
      return fourPanePanelID(
        from: activeIndex,
        direction: direction,
        visibleIDs: visibleIDs
      )
    default:
      return linearPanelID(
        from: activeIndex,
        direction: direction,
        visibleIDs: visibleIDs
      )
    }
  }

  nonisolated static func tabID(
    from activeTabID: TerminalTabID,
    direction: TerminalTabNavigationDirection,
    tabIDs: [TerminalTabID]
  ) -> TerminalTabID? {
    guard let activeIndex = tabIDs.firstIndex(of: activeTabID) else {
      return nil
    }

    switch direction {
    case .previous:
      guard activeIndex > tabIDs.startIndex else { return nil }
      return tabIDs[tabIDs.index(before: activeIndex)]
    case .next:
      let nextIndex = tabIDs.index(after: activeIndex)
      guard nextIndex < tabIDs.endIndex else { return nil }
      return tabIDs[nextIndex]
    }
  }

  private nonisolated static func twoPanePanelID(
    from activeIndex: Int,
    direction: TerminalPanelNavigationDirection,
    visibleIDs: [TerminalPanelID]
  ) -> TerminalPanelID? {
    switch (activeIndex, direction) {
    case (0, .right):
      return visibleIDs[1]
    case (1, .left):
      return visibleIDs[0]
    default:
      return nil
    }
  }

  private nonisolated static func threePanePanelID(
    from activeIndex: Int,
    direction: TerminalPanelNavigationDirection,
    visibleIDs: [TerminalPanelID]
  ) -> TerminalPanelID? {
    switch (activeIndex, direction) {
    case (0, .right):
      return visibleIDs[1]
    case (1, .left), (2, .left):
      return visibleIDs[0]
    case (1, .down):
      return visibleIDs[2]
    case (2, .up):
      return visibleIDs[1]
    default:
      return nil
    }
  }

  private nonisolated static func fourPanePanelID(
    from activeIndex: Int,
    direction: TerminalPanelNavigationDirection,
    visibleIDs: [TerminalPanelID]
  ) -> TerminalPanelID? {
    switch (activeIndex, direction) {
    case (0, .right):
      return visibleIDs[1]
    case (0, .down):
      return visibleIDs[2]
    case (1, .left):
      return visibleIDs[0]
    case (1, .down):
      return visibleIDs[3]
    case (2, .up):
      return visibleIDs[0]
    case (2, .right):
      return visibleIDs[3]
    case (3, .left):
      return visibleIDs[2]
    case (3, .up):
      return visibleIDs[1]
    default:
      return nil
    }
  }

  private nonisolated static func linearPanelID(
    from activeIndex: Int,
    direction: TerminalPanelNavigationDirection,
    visibleIDs: [TerminalPanelID]
  ) -> TerminalPanelID? {
    switch direction {
    case .left:
      guard activeIndex > visibleIDs.startIndex else { return nil }
      return visibleIDs[visibleIDs.index(before: activeIndex)]
    case .right:
      let nextIndex = visibleIDs.index(after: activeIndex)
      guard nextIndex < visibleIDs.endIndex else { return nil }
      return visibleIDs[nextIndex]
    case .up, .down:
      return nil
    }
  }

  private func defaultTabConfiguration(for panel: TerminalPanel) -> GhosttySurfaceConfiguration {
    guard let tab = panel.activeTab else {
      return .init()
    }

    return GhosttySurfaceConfiguration(
      workingDirectory: tab.controller.workingDirectory ?? tab.controller.configuration.workingDirectory,
      fontSize: tab.controller.configuration.fontSize
    )
  }

  private static func makeTab(
    runtime: GhosttyRuntime,
    name: String?,
    configuration: GhosttySurfaceConfiguration
  ) throws -> TerminalTab {
    let controller = try GhosttyTerminalController(
      runtime: runtime,
      configuration: configuration
    )
    let containerView = try GhosttyTerminalContainerView(controller: controller)
    return TerminalTab(
      name: name,
      controller: controller,
      containerView: containerView
    )
  }
}

public enum TerminalSessionError: Error {
  case panelNotFound
}
