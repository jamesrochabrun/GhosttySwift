import Foundation
import Observation

@MainActor
@Observable
public final class TerminalTab: Identifiable {
  public let id: TerminalTabID
  @ObservationIgnored public let controller: GhosttyTerminalController
  @ObservationIgnored public let containerView: GhosttyTerminalContainerView
  public var name: String?
  private var controllerRevision = 0

  init(
    id: TerminalTabID = TerminalTabID(),
    name: String?,
    controller: GhosttyTerminalController,
    containerView: GhosttyTerminalContainerView
  ) {
    self.id = id
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

  public func displayName(index: Int) -> String {
    _ = controllerRevision
    return Self.displayName(
      name: name,
      workingDirectory: controller.workingDirectory,
      index: index
    )
  }

  static func displayName(name: String?, workingDirectory: String?, index: Int) -> String {
    if let name, !name.isEmpty {
      return name
    }

    if let workingDirectory,
       let directoryName = Self.directoryDisplayName(from: workingDirectory) {
      return directoryName
    }

    return "Tab \(index + 1)"
  }

  public func focus() {
    containerView.focusTerminal()
  }

  private static func directoryDisplayName(from workingDirectory: String) -> String? {
    let trimmedPath = workingDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedPath.isEmpty else {
      return nil
    }

    let lastPathComponent = URL(fileURLWithPath: trimmedPath).lastPathComponent
    guard !lastPathComponent.isEmpty, lastPathComponent != "/" else {
      return trimmedPath
    }

    return lastPathComponent
  }
}
