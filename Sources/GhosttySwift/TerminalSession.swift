import Observation

@MainActor
@Observable
public final class TerminalSession {
  public let runtime: GhosttyRuntime
  public private(set) var terminals: [TerminalSessionTerminal]
  public private(set) var primaryTerminalID: TerminalID
  public private(set) var splitLayout: TerminalSplitLayout?

  public init(
    runtime: GhosttyRuntime? = nil,
    configPath: String? = nil,
    primaryConfiguration: GhosttySurfaceConfiguration = .init(),
    primaryName: String? = nil
  ) throws {
    self.runtime = try runtime ?? GhosttyRuntime(configPath: configPath)

    let primaryTerminal = try TerminalSession.makeTerminal(
      runtime: self.runtime,
      role: .primary,
      name: primaryName,
      configuration: primaryConfiguration
    )

    self.terminals = [primaryTerminal]
    self.primaryTerminalID = primaryTerminal.id
    self.splitLayout = nil
  }

  public var primaryTerminal: TerminalSessionTerminal {
    terminal(for: primaryTerminalID)!
  }

  public var auxiliaryTerminals: [TerminalSessionTerminal] {
    terminals.filter { $0.role == .auxiliary }
  }

  public var visibleTerminals: [TerminalSessionTerminal] {
    let visibleIDs = splitLayout?.terminalIDs ?? [primaryTerminalID]
    return visibleIDs.compactMap { terminal(for: $0) }
  }

  public var defaultPanelConfiguration: GhosttySurfaceConfiguration {
    let primaryController = primaryTerminal.controller
    return GhosttySurfaceConfiguration(
      workingDirectory: primaryController.workingDirectory ?? primaryController.configuration.workingDirectory,
      fontSize: primaryController.configuration.fontSize
    )
  }

  @discardableResult
  public func addAuxiliaryTerminal(
    named name: String? = nil,
    configuration: GhosttySurfaceConfiguration = .init()
  ) throws -> TerminalSessionTerminal {
    let terminal = try TerminalSession.makeTerminal(
      runtime: runtime,
      role: .auxiliary,
      name: name,
      configuration: configuration
    )
    terminals.append(terminal)
    return terminal
  }

  @discardableResult
  public func openPanel(
    named name: String? = nil,
    configuration: GhosttySurfaceConfiguration? = nil,
    axis: TerminalSplitAxis = .horizontal
  ) throws -> TerminalSessionTerminal {
    let terminal = try addAuxiliaryTerminal(
      named: name,
      configuration: configuration ?? defaultPanelConfiguration
    )
    let visibleIDs = splitLayout?.terminalIDs ?? [primaryTerminalID]
    showSplit(axis: axis, terminalIDs: visibleIDs + [terminal.id])
    return terminal
  }

  @discardableResult
  public func removeTerminal(_ id: TerminalID) -> Bool {
    guard id != primaryTerminalID else { return false }
    guard let index = terminals.firstIndex(where: { $0.id == id }) else { return false }

    terminals.remove(at: index)

    if let splitLayout {
      self.splitLayout = TerminalSplitLayout.normalized(
        axis: splitLayout.axis,
        terminalIDs: splitLayout.terminalIDs.filter { $0 != id },
        availableTerminalIDs: terminals.map(\.id),
        primaryTerminalID: primaryTerminalID
      )
    }

    return true
  }

  @discardableResult
  public func closePanel(_ id: TerminalID) -> Bool {
    removeTerminal(id)
  }

  @discardableResult
  public func closeLastPanel() -> Bool {
    let visibleAuxiliaryID = visibleTerminals.reversed().first { $0.id != primaryTerminalID }?.id
    let fallbackAuxiliaryID = auxiliaryTerminals.last?.id

    guard let panelID = visibleAuxiliaryID ?? fallbackAuxiliaryID else {
      return false
    }

    return closePanel(panelID)
  }

  public func renameTerminal(_ id: TerminalID, to name: String?) {
    terminal(for: id)?.name = name
  }

  public func showPrimaryOnly() {
    splitLayout = nil
  }

  public func showPrimaryAndFirstAuxiliary(axis: TerminalSplitAxis = .horizontal) {
    guard let firstAuxiliary = auxiliaryTerminals.first else {
      showPrimaryOnly()
      return
    }

    showPrimaryAndAuxiliary(firstAuxiliary.id, axis: axis)
  }

  public func showPrimaryAndAuxiliary(
    _ auxiliaryID: TerminalID,
    axis: TerminalSplitAxis = .horizontal
  ) {
    showSplit(axis: axis, terminalIDs: [primaryTerminalID, auxiliaryID])
  }

  public func showPrimaryAndAuxiliaries(axis: TerminalSplitAxis = .horizontal) {
    let terminalIDs = [primaryTerminalID] + auxiliaryTerminals.map(\.id)
    showSplit(axis: axis, terminalIDs: terminalIDs)
  }

  public func showSplit(
    axis: TerminalSplitAxis = .horizontal,
    terminalIDs: [TerminalID]
  ) {
    splitLayout = TerminalSplitLayout.normalized(
      axis: axis,
      terminalIDs: terminalIDs,
      availableTerminalIDs: terminals.map(\.id),
      primaryTerminalID: primaryTerminalID
    )
  }

  @discardableResult
  public func focusTerminal(_ id: TerminalID) -> Bool {
    guard let terminal = terminal(for: id) else { return false }
    terminal.focus()
    return true
  }

  public func terminal(for id: TerminalID) -> TerminalSessionTerminal? {
    terminals.first { $0.id == id }
  }

  public func controller(for id: TerminalID) -> GhosttyTerminalController? {
    terminal(for: id)?.controller
  }

  public func containerView(for id: TerminalID) -> GhosttyTerminalContainerView? {
    terminal(for: id)?.containerView
  }

  private static func makeTerminal(
    runtime: GhosttyRuntime,
    role: TerminalRole,
    name: String?,
    configuration: GhosttySurfaceConfiguration
  ) throws -> TerminalSessionTerminal {
    let controller = try GhosttyTerminalController(
      runtime: runtime,
      configuration: configuration
    )
    let containerView = try GhosttyTerminalContainerView(controller: controller)
    return TerminalSessionTerminal(
      role: role,
      name: name,
      controller: controller,
      containerView: containerView
    )
  }
}
