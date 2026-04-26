public struct TerminalSplitLayout: Codable, Equatable, Sendable {
  public indirect enum Node: Codable, Equatable, Sendable {
    case panel(TerminalPanelID)
    case split(axis: TerminalSplitAxis, children: [Node])

    public var panelIDs: [TerminalPanelID] {
      switch self {
      case .panel(let panelID):
        return [panelID]
      case .split(_, let children):
        return children.flatMap(\.panelIDs)
      }
    }

    fileprivate static func row(_ panelIDs: ArraySlice<TerminalPanelID>) -> Node {
      let panels = panelIDs.map { Node.panel($0) }
      return panels.count == 1 ? panels[0] : .split(axis: .horizontal, children: panels)
    }
  }

  public var axis: TerminalSplitAxis
  public var root: Node

  public var panelIDs: [TerminalPanelID] {
    root.panelIDs
  }

  public init(axis: TerminalSplitAxis, panelIDs: [TerminalPanelID]) {
    self.axis = axis
    self.root = Self.makeCanonicalRoot(panelIDs: panelIDs)
  }

  public init(axis: TerminalSplitAxis, root: Node) {
    self.axis = axis
    self.root = root
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
    return TerminalSplitLayout(
      axis: axis,
      root: makeCanonicalRoot(panelIDs: normalizedIDs)
    )
  }

  func removingPanel(
    _ panelID: TerminalPanelID,
    availablePanelIDs: [TerminalPanelID],
    primaryPanelID: TerminalPanelID
  ) -> TerminalSplitLayout? {
    TerminalSplitLayout.normalized(
      axis: axis,
      panelIDs: panelIDs.filter { $0 != panelID },
      availablePanelIDs: availablePanelIDs,
      primaryPanelID: primaryPanelID
    )
  }

  private static func makeCanonicalRoot(panelIDs: [TerminalPanelID]) -> Node {
    switch panelIDs.count {
    case 0:
      return .split(axis: .horizontal, children: [])
    case 1:
      return .panel(panelIDs[0])
    case 2:
      return .split(
        axis: .horizontal,
        children: [
          .panel(panelIDs[0]),
          .panel(panelIDs[1]),
        ]
      )
    case 3:
      return .split(
        axis: .horizontal,
        children: [
          .panel(panelIDs[0]),
          .split(
            axis: .vertical,
            children: [
              .panel(panelIDs[1]),
              .panel(panelIDs[2]),
            ]
          ),
        ]
      )
    case 4:
      return .split(
        axis: .vertical,
        children: [
          .split(
            axis: .horizontal,
            children: [
              .panel(panelIDs[0]),
              .panel(panelIDs[1]),
            ]
          ),
          .split(
            axis: .horizontal,
            children: [
              .panel(panelIDs[2]),
              .panel(panelIDs[3]),
            ]
          ),
        ]
      )
    default:
      let rows = stride(from: panelIDs.startIndex, to: panelIDs.endIndex, by: 2).map { startIndex in
        let endIndex = panelIDs.index(startIndex, offsetBy: 2, limitedBy: panelIDs.endIndex) ?? panelIDs.endIndex
        return Node.row(panelIDs[startIndex..<endIndex])
      }
      return .split(
        axis: .vertical,
        children: rows
      )
    }
  }
}
