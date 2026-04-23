import AppKit
import SwiftUI

@MainActor
public struct GhosttyTerminalView: NSViewRepresentable {
  public typealias NSViewType = NSView

  private let runtime: GhosttyRuntime
  private let configuration: GhosttySurfaceConfiguration
  private let bridge: GhosttySurfaceBridge

  public init(
    runtime: GhosttyRuntime,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) {
    self.runtime = runtime
    self.configuration = configuration
    self.bridge = bridge
  }

  public func makeNSView(context: Context) -> NSView {
    GhosttyTrace.write("terminal view makeNSView start")
    do {
      let surfaceView = try GhosttySurfaceView(
        runtime: runtime,
        configuration: configuration,
        bridge: bridge
      )
      let view = GhosttySurfaceScrollView(surfaceView: surfaceView)
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
