import AppKit
import SwiftUI

@MainActor
public struct GhosttyTerminalView: NSViewRepresentable {
  public typealias NSViewType = NSView

  private let controller: GhosttyTerminalController?
  private let runtime: GhosttyRuntime?
  private let configPath: String?
  private let configuration: GhosttySurfaceConfiguration
  private let bridge: GhosttySurfaceBridge

  public init(controller: GhosttyTerminalController) {
    self.controller = controller
    self.runtime = nil
    self.configPath = nil
    self.configuration = controller.configuration
    self.bridge = controller.bridge
  }

  public init(
    runtime: GhosttyRuntime,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) {
    self.controller = nil
    self.runtime = runtime
    self.configPath = nil
    self.configuration = configuration
    self.bridge = bridge
  }

  public init(
    configPath: String? = nil,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) {
    self.controller = nil
    self.runtime = nil
    self.configPath = configPath
    self.configuration = configuration
    self.bridge = bridge
  }

  public func makeNSView(context: Context) -> NSView {
    GhosttyTrace.write("terminal view makeNSView start")
    do {
      let view = if let controller {
        try GhosttyTerminalContainerView(controller: controller)
      } else {
        try GhosttyTerminalContainerView(
          runtime: runtime,
          configPath: configPath,
          configuration: configuration,
          bridge: bridge
        )
      }
      GhosttyTrace.write("terminal view makeNSView success")
      return view
    } catch {
      GhosttyTrace.write("terminal view makeNSView error: \(error.localizedDescription)")
      return SurfaceErrorView(error: error)
    }
  }

  public func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class SurfaceErrorView: NSView {
  init(error: Error) {
    super.init(frame: .zero)

    let label = NSTextField(wrappingLabelWithString: error.localizedDescription)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.alignment = .center
    label.font = .systemFont(ofSize: 14, weight: .medium)
    label.textColor = .secondaryLabelColor
    addSubview(label)

    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: centerXAnchor),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),
      label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
      trailingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 24),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }
}
