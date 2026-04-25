import AppKit
import GhosttyKit
import QuartzCore

// Surface lifecycle is re-authored against upstream Ghostty MIT sources,
// primarily macos/Sources/Ghostty/Surface View/SurfaceView_AppKit.swift.
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
  private var contentSizeBacking: NSSize?
  private var isObservingWindowNotifications = false
  private var titleChangeTimer: Timer?
  var markedText = NSMutableAttributedString()
  var keyTextAccumulator: [String]?

  public override var acceptsFirstResponder: Bool { true }

  private var contentSize: NSSize {
    get { contentSizeBacking ?? bounds.size }
    set { contentSizeBacking = newValue }
  }

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
    bridge.internalOnClose = { [weak self] _ in
      GhosttyTrace.write("surface view bridge onClose")
      self?.window?.performClose(nil)
    }
    bridge.internalOnCloseWindow = { [weak self] in
      GhosttyTrace.write("surface view bridge onCloseWindow")
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
    if isObservingWindowNotifications {
      NotificationCenter.default.removeObserver(self)
    }
    titleChangeTimer?.invalidate()

    if let surfaceHandle {
      ghostty_surface_free(surfaceHandle)
    }
  }

  public override func layout() {
    super.layout()
    contentSize = bounds.size
    let scaledSize = convertToBacking(contentSize)
    setSurfaceSize(width: UInt32(scaledSize.width), height: UInt32(scaledSize.height))
    syncFocus()
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    GhosttyTrace.write("surface view didMoveToWindow window=\(window != nil)")
    installTrackingAreaIfNeeded()
    installWindowObservers()
    updateDisplayID()
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

  override public func becomeFirstResponder() -> Bool {
    let accepted = super.becomeFirstResponder()
    if accepted {
      syncFocus()
    }
    return accepted
  }

  override public func resignFirstResponder() -> Bool {
    let accepted = super.resignFirstResponder()
    if accepted {
      syncFocus()
    }
    return accepted
  }

  func claimFirstResponder() {
    if window?.firstResponder !== self {
      window?.makeFirstResponder(self)
    }
    syncFocus()
  }

  @discardableResult
  func performBindingAction(_ action: String) -> Bool {
    guard let surfaceHandle else { return false }
    return ghostty_surface_binding_action(
      surfaceHandle,
      action,
      UInt(action.lengthOfBytes(using: .utf8))
    )
  }

  private func installWindowObservers() {
    guard !isObservingWindowNotifications else { return }
    let center = NotificationCenter.default

    center.addObserver(
      self,
      selector: #selector(windowDidBecomeKey(_:)),
      name: NSWindow.didBecomeKeyNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(windowDidResignKey(_:)),
      name: NSWindow.didResignKeyNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(windowDidChangeScreen(_:)),
      name: NSWindow.didChangeScreenNotification,
      object: nil
    )

    isObservingWindowNotifications = true
  }

  @objc
  private func windowDidBecomeKey(_ notification: Notification) {
    guard let window, notification.object as? NSWindow === window else { return }
    syncFocus()
  }

  @objc
  private func windowDidResignKey(_ notification: Notification) {
    guard let window, notification.object as? NSWindow === window else { return }
    syncFocus()
  }

  @objc
  private func windowDidChangeScreen(_ notification: Notification) {
    guard let window, notification.object as? NSWindow === window else { return }
    updateDisplayID()
    DispatchQueue.main.async { [weak self] in
      self?.viewDidChangeBackingProperties()
    }
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

    let framebufferFrame = convertToBacking(frame)
    let xScale = frame.width > 0 ? framebufferFrame.width / frame.width : 1
    let yScale = frame.height > 0 ? framebufferFrame.height / frame.height : 1

    ghostty_surface_set_content_scale(surfaceHandle, xScale, yScale)
    let scaledSize = convertToBacking(contentSize)
    setSurfaceSize(width: UInt32(scaledSize.width), height: UInt32(scaledSize.height))

    syncFocus()
  }

  private func setSurfaceSize(width: UInt32, height: UInt32) {
    guard let surfaceHandle else { return }
    ghostty_surface_set_size(surfaceHandle, width, height)
  }

  func sendText(_ text: String) {
    guard let surfaceHandle else { return }
    let utf8Count = text.utf8CString.count
    guard utf8Count > 1 else { return }
    text.withCString { pointer in
      ghostty_surface_text(surfaceHandle, pointer, UInt(utf8Count - 1))
    }
  }

  func syncPreedit(clearIfNeeded: Bool = true) {
    guard let surfaceHandle else { return }

    if markedText.length > 0 {
      let string = markedText.string
      let utf8Count = string.utf8CString.count
      guard utf8Count > 1 else { return }
      string.withCString { pointer in
        ghostty_surface_preedit(surfaceHandle, pointer, UInt(utf8Count - 1))
      }
    } else if clearIfNeeded {
      ghostty_surface_preedit(surfaceHandle, nil, 0)
    }
  }

  private func updateDisplayID() {
    guard
      let surfaceHandle,
      let displayID = window?.screen?.displayID
    else {
      return
    }

    ghostty_surface_set_display_id(surfaceHandle, displayID)
  }

  private func syncFocus() {
    guard let surfaceHandle else { return }
    let hasFocus = window?.isKeyWindow == true && window?.firstResponder === self
    ghostty_surface_set_focus(surfaceHandle, hasFocus)
  }

  func setCursorShape(_ shape: ghostty_action_mouse_shape_e) {
    guard let cursor = cursor(for: shape) else { return }
    activeCursor = cursor
    window?.invalidateCursorRects(for: self)
  }

  func setTitle(_ title: String) {
    titleChangeTimer?.invalidate()
    titleChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.075, repeats: false) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.window?.title = title
      }
    }
  }

  private func cursor(for shape: ghostty_action_mouse_shape_e) -> NSCursor? {
    switch shape {
    case GHOSTTY_MOUSE_SHAPE_DEFAULT:
      return .arrow
    case GHOSTTY_MOUSE_SHAPE_TEXT:
      return .iBeam
    case GHOSTTY_MOUSE_SHAPE_VERTICAL_TEXT:
      return .iBeamCursorForVerticalLayout
    case GHOSTTY_MOUSE_SHAPE_GRAB:
      return .openHand
    case GHOSTTY_MOUSE_SHAPE_GRABBING:
      return .closedHand
    case GHOSTTY_MOUSE_SHAPE_POINTER:
      return .pointingHand
    case GHOSTTY_MOUSE_SHAPE_CONTEXT_MENU:
      return .contextualMenu
    case GHOSTTY_MOUSE_SHAPE_CROSSHAIR:
      return .crosshair
    case GHOSTTY_MOUSE_SHAPE_NOT_ALLOWED:
      return .operationNotAllowed
    case GHOSTTY_MOUSE_SHAPE_W_RESIZE:
      return .resizeLeft
    case GHOSTTY_MOUSE_SHAPE_E_RESIZE:
      return .resizeRight
    case GHOSTTY_MOUSE_SHAPE_N_RESIZE:
      return .resizeUp
    case GHOSTTY_MOUSE_SHAPE_S_RESIZE:
      return .resizeDown
    case GHOSTTY_MOUSE_SHAPE_NS_RESIZE:
      return .resizeUpDown
    case GHOSTTY_MOUSE_SHAPE_EW_RESIZE:
      return .resizeLeftRight
    default:
      return nil
    }
  }
}

@MainActor
final class GhosttySurfaceScrollView: NSView {
  let surfaceView: GhosttySurfaceView
  private let controller: GhosttyTerminalController
  private let scrollView = NSScrollView()
  private let documentView = NSView()
  private var isLiveScrolling = false
  private var lastSentRow: Int?

  init(surfaceView: GhosttySurfaceView, controller: GhosttyTerminalController) {
    self.surfaceView = surfaceView
    self.controller = controller
    super.init(frame: .zero)

    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = false
    scrollView.usesPredominantAxisScrolling = true
    scrollView.scrollerStyle = .overlay
    scrollView.drawsBackground = false
    scrollView.contentView.clipsToBounds = false

    documentView.frame = .zero
    scrollView.documentView = documentView
    documentView.addSubview(surfaceView)

    addSubview(scrollView)

    scrollView.contentView.postsBoundsChangedNotifications = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScrollChangeNotification(_:)),
      name: NSView.boundsDidChangeNotification,
      object: scrollView.contentView
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillStartLiveScroll(_:)),
      name: NSScrollView.willStartLiveScrollNotification,
      object: scrollView
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidEndLiveScroll(_:)),
      name: NSScrollView.didEndLiveScrollNotification,
      object: scrollView
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidLiveScroll(_:)),
      name: NSScrollView.didLiveScrollNotification,
      object: scrollView
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleScrollerStyleChangeNotification(_:)),
      name: NSScroller.preferredScrollerStyleDidChangeNotification,
      object: nil
    )

    synchronizeAppearance()
    synchronizeScrollView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  isolated deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func layout() {
    super.layout()

    scrollView.frame = bounds
    documentView.frame.size.width = scrollView.bounds.width
    synchronizeSurfaceView()
    synchronizeScrollView()
  }

  override func mouseMoved(with event: NSEvent) {
    guard NSScroller.preferredScrollerStyle == .legacy else { return }
    scrollView.flashScrollers()
  }

  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    super.updateTrackingAreas()

    guard let scroller = scrollView.verticalScroller, !scroller.isHidden else { return }
    addTrackingArea(NSTrackingArea(
      rect: convert(scroller.bounds, from: scroller),
      options: [.mouseMoved, .activeInKeyWindow],
      owner: self,
      userInfo: nil
    ))
  }

  func syncFromController() {
    synchronizeAppearance()
    synchronizeScrollView()
  }

  private func synchronizeAppearance() {
    let hasScrollableContent = controller.scrollbar.map { $0.total > $0.length } ?? false
    scrollView.hasVerticalScroller = hasScrollableContent
    updateTrackingAreas()
  }

  private func synchronizeSurfaceView() {
    let visibleRect = scrollView.contentView.documentVisibleRect
    var frame = surfaceView.frame
    frame.origin = visibleRect.origin
    frame.size = scrollView.bounds.size
    guard frame != surfaceView.frame else { return }
    surfaceView.frame = frame
    surfaceView.layoutSubtreeIfNeeded()
  }

  private func synchronizeScrollView() {
    documentView.frame.size.height = Self.documentHeight(
      contentHeight: scrollView.contentSize.height,
      cellHeight: controller.cellSize.height,
      scrollbar: controller.scrollbar
    )

    if
      !isLiveScrolling,
      let offsetY = Self.offsetY(
        for: controller.scrollbar,
        cellHeight: controller.cellSize.height
      )
    {
      scrollView.contentView.scroll(to: CGPoint(x: 0, y: offsetY))
      if let scrollbar = controller.scrollbar {
        lastSentRow = Int(scrollbar.offset)
      }
    }

    scrollView.reflectScrolledClipView(scrollView.contentView)
    synchronizeSurfaceView()
  }

  private func handleScrollChange() {
    synchronizeSurfaceView()
  }

  private func handleScrollerStyleChange() {
    scrollView.scrollerStyle = .overlay
  }

  private func handleLiveScroll() {
    guard
      let row = Self.rowForLiveScroll(
        documentHeight: documentView.frame.height,
        visibleOriginY: scrollView.contentView.documentVisibleRect.origin.y,
        visibleHeight: scrollView.contentView.documentVisibleRect.height,
        cellHeight: controller.cellSize.height
      ),
      row != lastSentRow
    else {
      return
    }

    lastSentRow = row
    _ = controller.scrollToRow(row)
  }

  static func documentHeight(
    contentHeight: CGFloat,
    cellHeight: CGFloat,
    scrollbar: GhosttySurfaceScrollbarState?
  ) -> CGFloat {
    guard
      cellHeight > 0,
      let scrollbar
    else {
      return contentHeight
    }

    let documentGridHeight = CGFloat(scrollbar.total) * cellHeight
    let padding = contentHeight - (CGFloat(scrollbar.length) * cellHeight)
    return max(contentHeight, documentGridHeight + padding)
  }

  static func offsetY(
    for scrollbar: GhosttySurfaceScrollbarState?,
    cellHeight: CGFloat
  ) -> CGFloat? {
    guard
      cellHeight > 0,
      let scrollbar
    else {
      return nil
    }

    return CGFloat(scrollbar.total - scrollbar.offset - scrollbar.length) * cellHeight
  }

  static func rowForLiveScroll(
    documentHeight: CGFloat,
    visibleOriginY: CGFloat,
    visibleHeight: CGFloat,
    cellHeight: CGFloat
  ) -> Int? {
    guard cellHeight > 0 else { return nil }
    let scrollOffset = max(0, documentHeight - visibleOriginY - visibleHeight)
    return Int(scrollOffset / cellHeight)
  }

  @objc
  private func handleScrollChangeNotification(_ notification: Notification) {
    handleScrollChange()
  }

  @objc
  private func handleWillStartLiveScroll(_ notification: Notification) {
    isLiveScrolling = true
  }

  @objc
  private func handleDidEndLiveScroll(_ notification: Notification) {
    isLiveScrolling = false
  }

  @objc
  private func handleDidLiveScroll(_ notification: Notification) {
    handleLiveScroll()
  }

  @objc
  private func handleScrollerStyleChangeNotification(_ notification: Notification) {
    handleScrollerStyleChange()
  }
}

private extension NSScreen {
  var displayID: UInt32? {
    deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32
  }
}
