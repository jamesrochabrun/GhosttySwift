import AppKit

@MainActor
public final class GhosttyTerminalContainerView: NSView {
  public let controller: GhosttyTerminalController
  public let bridge: GhosttySurfaceBridge
  public let runtime: GhosttyRuntime
  public let surfaceView: GhosttySurfaceView

  private let scrollView: GhosttySurfaceScrollView

  public init(controller: GhosttyTerminalController) throws {
    self.controller = controller
    self.bridge = controller.bridge
    self.runtime = controller.runtime
    self.surfaceView = try GhosttySurfaceView(
      runtime: controller.runtime,
      configuration: controller.configuration,
      bridge: controller.bridge
    )
    self.scrollView = GhosttySurfaceScrollView(surfaceView: surfaceView)
    super.init(frame: .zero)

    addSubview(scrollView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  public convenience init(
    runtime: GhosttyRuntime? = nil,
    configPath: String? = nil,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) throws {
    let controller = try GhosttyTerminalController(
      runtime: runtime,
      configPath: configPath,
      configuration: configuration,
      bridge: bridge
    )
    try self.init(controller: controller)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  public func focusTerminal() {
    surfaceView.claimFirstResponder()
  }
}
