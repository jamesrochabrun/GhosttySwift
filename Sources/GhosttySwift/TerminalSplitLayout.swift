public struct TerminalSplitLayout: Codable, Equatable, Sendable {
  public var axis: TerminalSplitAxis
  public var terminalIDs: [TerminalID]

  public init(axis: TerminalSplitAxis, terminalIDs: [TerminalID]) {
    self.axis = axis
    self.terminalIDs = terminalIDs
  }

  public static func normalized(
    axis: TerminalSplitAxis,
    terminalIDs: [TerminalID],
    availableTerminalIDs: [TerminalID],
    primaryTerminalID: TerminalID
  ) -> TerminalSplitLayout? {
    let availableIDs = Set(availableTerminalIDs)
    var normalizedIDs: [TerminalID] = []

    for terminalID in terminalIDs where availableIDs.contains(terminalID) {
      if !normalizedIDs.contains(terminalID) {
        normalizedIDs.append(terminalID)
      }
    }

    normalizedIDs.removeAll { $0 == primaryTerminalID }
    if availableIDs.contains(primaryTerminalID) {
      normalizedIDs.insert(primaryTerminalID, at: 0)
    }

    guard normalizedIDs.count > 1 else { return nil }
    return TerminalSplitLayout(axis: axis, terminalIDs: normalizedIDs)
  }
}
