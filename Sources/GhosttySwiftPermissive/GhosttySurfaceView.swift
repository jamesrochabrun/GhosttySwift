import AppKit
import GhosttyKit
import QuartzCore

@MainActor
public final class GhosttySurfaceView: NSView {
  public enum SurfaceError: LocalizedError {
    case surfaceCreationFailed

    public var errorDescription: String? {
      switch self {
      case .surfaceCreationFailed:
        return "ghostty_surface_new returned nil."
      }
    }
  }

  public let bridge: GhosttySurfaceBridge
  public var activeCursor: NSCursor = .iBeam

  private let runtime: GhosttyRuntime
  private let configuration: GhosttySurfaceConfiguration
  var surfaceHandle: ghostty_surface_t?
  private var windowObservers: [NSObjectProtocol] = []

  public override var acceptsFirstResponder: Bool { true }

  public init(
    runtime: GhosttyRuntime,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) throws {
    GhosttyTrace.write("surface view init start")
    self.runtime = runtime
    self.configuration = configuration
    self.bridge = bridge
    super.init(frame: .zero)

    wantsLayer = true

    bridge.attach(to: self)
    bridge.onClose = { [weak self] _ in
      GhosttyTrace.write("surface view bridge onClose")
      self?.window?.performClose(nil)
    }

    try createSurface()
    GhosttyTrace.write("surface view init complete")
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  isolated deinit {
    GhosttyTrace.write("surface view deinit")
    windowObservers.forEach(NotificationCenter.default.removeObserver(_:))

    if let surfaceHandle {
      ghostty_surface_free(surfaceHandle)
    }
  }

  public override func layout() {
    super.layout()
    updateSurfaceMetrics()
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    GhosttyTrace.write("surface view didMoveToWindow window=\(window != nil)")
    installTrackingAreaIfNeeded()
    installWindowObservers()
    updateSurfaceMetrics()
    claimFirstResponder()
  }

  public override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    updateSurfaceMetrics()
  }

  public override func resetCursorRects() {
    discardCursorRects()
    addCursorRect(bounds, cursor: activeCursor)
  }

  func claimFirstResponder() {
    window?.makeFirstResponder(self)
    syncFocus()
  }

  private func installWindowObservers() {
    windowObservers.forEach(NotificationCenter.default.removeObserver(_:))
    windowObservers.removeAll()

    guard let window else { return }
    let center = NotificationCenter.default

    windowObservers.append(
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.syncFocus()
        }
      }
    )

    windowObservers.append(
      center.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor in
          self?.syncFocus()
        }
      }
    )
  }

  private func createSurface() throws {
    GhosttyTrace.write("surface view createSurface start")
    let initialScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0

    let surface = withSurfaceConfig(scaleFactor: initialScale) { config in
      ghostty_surface_new(runtime.appHandle, &config)
    }

    guard let surface else {
      GhosttyTrace.write("surface view createSurface failed")
      throw SurfaceError.surfaceCreationFailed
    }

    self.surfaceHandle = surface
    GhosttyTrace.write("surface view createSurface success")
    updateSurfaceMetrics()
  }

  private func withSurfaceConfig<T>(
    scaleFactor: Double,
    body: (inout ghostty_surface_config_s) -> T
  ) -> T {
    withOptionalCString(configuration.workingDirectory) { workingDirectoryPointer in
      withOptionalCString(configuration.command) { commandPointer in
        withOptionalCString(configuration.initialInput) { initialInputPointer in
          var config = ghostty_surface_config_new()
          config.platform_tag = GHOSTTY_PLATFORM_MACOS
          config.platform.macos.nsview = Unmanaged.passUnretained(self).toOpaque()
          config.userdata = Unmanaged.passUnretained(bridge).toOpaque()
          config.scale_factor = scaleFactor
          config.font_size = configuration.fontSize
          config.working_directory = workingDirectoryPointer
          config.command = commandPointer
          config.initial_input = initialInputPointer
          config.wait_after_command = false
          config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW
          return body(&config)
        }
      }
    }
  }

  private func withOptionalCString<T>(
    _ value: String?,
    _ body: (UnsafePointer<CChar>?) -> T
  ) -> T {
    guard let value else {
      return body(nil)
    }

    return value.withCString { pointer in
      body(pointer)
    }
  }

  private func updateSurfaceMetrics() {
    guard let surfaceHandle else { return }

    if let window {
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      layer?.contentsScale = window.backingScaleFactor
      CATransaction.commit()
    }

    let backingBounds = convertToBacking(bounds)
    let xScale = bounds.width > 0 ? backingBounds.width / bounds.width : 1
    let yScale = bounds.height > 0 ? backingBounds.height / bounds.height : 1

    ghostty_surface_set_content_scale(surfaceHandle, xScale, yScale)
    ghostty_surface_set_size(surfaceHandle, UInt32(backingBounds.width), UInt32(backingBounds.height))

    syncFocus()
  }

  private func syncFocus() {
    guard let surfaceHandle else { return }
    let hasFocus = window?.isKeyWindow == true && window?.firstResponder === self
    ghostty_surface_set_focus(surfaceHandle, hasFocus)
  }
}

@MainActor
final class GhosttySurfaceScrollView: NSView {
  let surfaceView: GhosttySurfaceView

  init(surfaceView: GhosttySurfaceView) {
    self.surfaceView = surfaceView
    super.init(frame: .zero)

    addSubview(surfaceView)
    surfaceView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
      surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
      surfaceView.topAnchor.constraint(equalTo: topAnchor),
      surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }
}
