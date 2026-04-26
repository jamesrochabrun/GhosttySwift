import Observation

@MainActor
@Observable
public final class TerminalPanel: Identifiable {
  public let id: TerminalPanelID
  public let role: TerminalPanelRole
  public var name: String?
  public private(set) var tabs: [TerminalTab]
  public private(set) var activeTabID: TerminalTabID

  init(
    id: TerminalPanelID = TerminalPanelID(),
    role: TerminalPanelRole,
    name: String?,
    tabs: [TerminalTab],
    activeTabID: TerminalTabID
  ) {
    self.id = id
    self.role = role
    self.name = name
    self.tabs = tabs
    self.activeTabID = activeTabID
  }

  public var activeTab: TerminalTab? {
    tab(for: activeTabID) ?? tabs.first
  }

  public var displayName: String {
    if let name, !name.isEmpty {
      return name
    }

    switch role {
    case .primary:
      return "Main"
    case .auxiliary:
      return "Panel"
    }
  }

  public var canCloseActiveTab: Bool {
    Self.canCloseTab(panelRole: role, tabCount: tabs.count)
  }

  public func tab(for id: TerminalTabID) -> TerminalTab? {
    tabs.first { $0.id == id }
  }

  func appendTab(_ tab: TerminalTab) {
    tabs.append(tab)
    activeTabID = tab.id
  }

  @discardableResult
  func selectTab(_ id: TerminalTabID) -> Bool {
    guard tab(for: id) != nil else { return false }
    activeTabID = id
    return true
  }

  @discardableResult
  func removeTab(_ id: TerminalTabID) -> Bool {
    guard Self.canCloseTab(panelRole: role, tabCount: tabs.count) else {
      return false
    }

    let tabIDs = tabs.map(\.id)
    guard tabIDs.contains(id) else { return false }
    guard let nextActiveTabID = Self.activeTabIDAfterClosing(
      id,
      tabIDs: tabIDs,
      activeTabID: activeTabID
    ) else {
      return false
    }

    tabs.removeAll { $0.id == id }
    activeTabID = nextActiveTabID
    return true
  }

  nonisolated static func canCloseTab(
    panelRole: TerminalPanelRole,
    tabCount: Int
  ) -> Bool {
    tabCount > 1 || panelRole != .primary
  }

  nonisolated static func activeTabIDAfterClosing(
    _ closingID: TerminalTabID,
    tabIDs: [TerminalTabID],
    activeTabID: TerminalTabID
  ) -> TerminalTabID? {
    guard let closingIndex = tabIDs.firstIndex(of: closingID) else {
      return activeTabID
    }

    var remainingIDs = tabIDs
    remainingIDs.remove(at: closingIndex)

    guard activeTabID == closingID else {
      return remainingIDs.contains(activeTabID) ? activeTabID : remainingIDs.first
    }

    if closingIndex < remainingIDs.count {
      return remainingIDs[closingIndex]
    }

    return remainingIDs.last
  }
}
