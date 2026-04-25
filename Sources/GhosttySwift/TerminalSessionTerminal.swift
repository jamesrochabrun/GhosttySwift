import Observation

@MainActor
@Observable
public final class TerminalSessionTerminal: Identifiable {
  public let id: TerminalID
  public let role: TerminalRole
  @ObservationIgnored public let controller: GhosttyTerminalController
  @ObservationIgnored public let containerView: GhosttyTerminalContainerView
  public var name: String?
  private var controllerRevision = 0

  init(
    id: TerminalID = TerminalID(),
    role: TerminalRole,
    name: String?,
    controller: GhosttyTerminalController,
    containerView: GhosttyTerminalContainerView
  ) {
    self.id = id
    self.role = role
    self.name = name
    self.controller = controller
    self.containerView = containerView

    let previousInternalOnStateChange = controller.internalOnStateChange
    controller.internalOnStateChange = { [weak self] controller in
      previousInternalOnStateChange?(controller)
      self?.controllerRevision &+= 1
    }
  }

  public var title: String {
    _ = controllerRevision
    return controller.title
  }

  public var displayName: String {
    _ = controllerRevision
    if let name, !name.isEmpty {
      return name
    }

    if controller.title != "Ghostty" {
      return controller.title
    }

    switch role {
    case .primary:
      return "Main"
    case .auxiliary:
      return "Auxiliary"
    }
  }

  public func focus() {
    containerView.focusTerminal()
  }
}
