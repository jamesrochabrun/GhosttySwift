public struct TerminalSplitLayout: Codable, Equatable, Sendable {
  public var axis: TerminalSplitAxis
  public var panelIDs: [TerminalPanelID]

  public init(axis: TerminalSplitAxis, panelIDs: [TerminalPanelID]) {
    self.axis = axis
    self.panelIDs = panelIDs
  }

  public static func normalized(
    axis: TerminalSplitAxis,
    panelIDs: [TerminalPanelID],
    availablePanelIDs: [TerminalPanelID],
    primaryPanelID: TerminalPanelID
  ) -> TerminalSplitLayout? {
    let availableIDs = Set(availablePanelIDs)
    var normalizedIDs: [TerminalPanelID] = []

    for panelID in panelIDs where availableIDs.contains(panelID) {
      if !normalizedIDs.contains(panelID) {
        normalizedIDs.append(panelID)
      }
    }

    normalizedIDs.removeAll { $0 == primaryPanelID }
    if availableIDs.contains(primaryPanelID) {
      normalizedIDs.insert(primaryPanelID, at: 0)
    }

    guard normalizedIDs.count > 1 else { return nil }
    return TerminalSplitLayout(axis: axis, panelIDs: normalizedIDs)
  }
}
