import AppKit
import Darwin
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
  public var closesHostWindowOnClose = true

  private let runtime: GhosttyRuntime
  private let configuration: GhosttySurfaceConfiguration
  var surfaceHandle: ghostty_surface_t?
  private var contentSizeBacking: NSSize?
  private var isObservingWindowNotifications = false
  private var titleChangeTimer: Timer?
  private var lastSentSurfaceSize: (width: UInt32, height: UInt32)?
  private var createdScaleFactor: CGFloat?
  private static let fallbackMinimumSurfacePixelSize = (width: UInt32(80), height: UInt32(68))
  var markedText = NSMutableAttributedString()
  var keyTextAccumulator: [String]?

  public override var acceptsFirstResponder: Bool { true }
  public override var isOpaque: Bool { false }

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

    let initialFrame = configuration.initialSize.flatMap { size -> NSRect? in
      guard size.width > 0, size.height > 0 else { return nil }
      return NSRect(x: 0, y: 0, width: size.width, height: size.height)
    } ?? .zero
    super.init(frame: initialFrame)
    if initialFrame.size != .zero {
      contentSizeBacking = initialFrame.size
    }

    wantsLayer = true
    // Ghostty drives its own Metal rendering, so AppKit should not interpolate or
    // implicitly animate layer contents while pane sizes are changing.
    layerContentsRedrawPolicy = .never
    layerContentsPlacement = .topLeft
    layer?.backgroundColor = NSColor.clear.cgColor
    layer?.isOpaque = false
    layer?.contentsGravity = .topLeft
    layer?.actions = GhosttyLayerActions.disabled

    bridge.attach(to: self)
    bridge.internalOnClose = { [weak self] _ in
      GhosttyTrace.write("surface view bridge onClose")
      guard self?.closesHostWindowOnClose == true else { return }
      self?.window?.performClose(nil)
    }
    bridge.internalOnCloseWindow = { [weak self] in
      GhosttyTrace.write("surface view bridge onCloseWindow")
      guard self?.closesHostWindowOnClose == true else { return }
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
    if let scaledSize = backingPixelSize(for: contentSize) {
      setSurfaceSize(width: scaledSize.width, height: scaledSize.height)
    }
    syncFocus()
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    GhosttyTrace.write("surface view didMoveToWindow window=\(window != nil)")
    installTrackingAreaIfNeeded()
    installWindowObservers()
    updateDisplayID()
    configureSublayersForCleanResize()
    updateSurfaceMetrics()
    claimFirstResponder()
  }

  func prepareForHostResize(to size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    contentSize = NSSize(width: size.width, height: size.height)
    if let scaledSize = backingPixelSize(for: size) {
      setSurfaceSize(width: scaledSize.width, height: scaledSize.height)
    }
  }

  public override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    configureSublayersForCleanResize()
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
    // Prefer the caller-provided scale (e.g. an existing pane's window scale) so the new
    // surface starts at the right scale and ghostty doesn't have to rebuild the font atlas
    // and re-render after viewDidMoveToWindow flips from a screen guess to the window scale.
    let initialScale = configuration.initialScaleFactor
      ?? window?.backingScaleFactor
      ?? NSScreen.main?.backingScaleFactor
      ?? 2.0
    let initialScaleCGFloat = CGFloat(initialScale)
    createdScaleFactor = initialScaleCGFloat

    let surface = withSurfaceConfig(scaleFactor: initialScale) { config in
      ghostty_surface_new(runtime.appHandle, &config)
    }

    guard let surface else {
      GhosttyTrace.write("surface view createSurface failed")
      throw SurfaceError.surfaceCreationFailed
    }

    self.surfaceHandle = surface
    GhosttyTrace.write("surface view createSurface success")
    configureSublayersForCleanResize()
    if let initialSize = configuration.initialSize,
       initialSize.width > 0,
       initialSize.height > 0 {
      if let scaledSize = Self.pixelSize(for: initialSize, scale: initialScaleCGFloat),
         isValidSurfacePixelSize(scaledSize) {
        setSurfaceSize(width: scaledSize.width, height: scaledSize.height)
      }
    }
    updateSurfaceMetrics()
  }

  private func configureSublayersForCleanResize() {
    func configure(_ target: CALayer) {
      target.actions = GhosttyLayerActions.disabled
      target.contentsGravity = .topLeft
      for sublayer in target.sublayers ?? [] {
        configure(sublayer)
      }
    }
    if let layer { configure(layer) }
  }

  private func withSurfaceConfig<T>(
    scaleFactor: Double,
    body: (inout ghostty_surface_config_s) -> T
  ) -> T {
    withOptionalCString(configuration.workingDirectory) { workingDirectoryPointer in
      withOptionalCString(configuration.command) { commandPointer in
        withOptionalCString(configuration.initialInput) { initialInputPointer in
          withEnvironmentVariables(configuration.environment) { environmentPointer, environmentCount in
            var config = ghostty_surface_config_new()
            config.platform_tag = GHOSTTY_PLATFORM_MACOS
            config.platform.macos.nsview = Unmanaged.passUnretained(self).toOpaque()
            config.userdata = Unmanaged.passUnretained(bridge).toOpaque()
            config.scale_factor = scaleFactor
            config.font_size = configuration.fontSize
            config.working_directory = workingDirectoryPointer
            config.command = commandPointer
            config.env_vars = environmentPointer
            config.env_var_count = environmentCount
            config.initial_input = initialInputPointer
            config.wait_after_command = false
            config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW
            return body(&config)
          }
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

  private func withEnvironmentVariables<T>(
    _ environment: [String: String],
    _ body: (UnsafeMutablePointer<ghostty_env_var_s>?, Int) -> T
  ) -> T {
    guard !environment.isEmpty else {
      return body(nil, 0)
    }

    var allocatedPointers: [UnsafeMutablePointer<CChar>] = []
    allocatedPointers.reserveCapacity(environment.count * 2)
    defer {
      for pointer in allocatedPointers {
        free(pointer)
      }
    }

    var envVars: [ghostty_env_var_s] = environment
      .sorted { $0.key < $1.key }
      .compactMap { key, value in
        guard let keyPointer = strdup(key), let valuePointer = strdup(value) else {
          return nil
        }
        allocatedPointers.append(keyPointer)
        allocatedPointers.append(valuePointer)
        return ghostty_env_var_s(
          key: UnsafePointer(keyPointer),
          value: UnsafePointer(valuePointer)
        )
      }

    return envVars.withUnsafeMutableBufferPointer { buffer in
      body(buffer.baseAddress, buffer.count)
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

    let scale = contentScaleForSurface()

    ghostty_surface_set_content_scale(surfaceHandle, scale.x, scale.y)
    if let scaledSize = backingPixelSize(for: contentSize) {
      setSurfaceSize(width: scaledSize.width, height: scaledSize.height)
    }

    syncFocus()
  }

  private func backingPixelSize(for size: CGSize) -> (width: UInt32, height: UInt32)? {
    guard size.width > 0, size.height > 0 else { return nil }

    let pixelSize: (width: UInt32, height: UInt32)?
    if window == nil, let scale = createdScaleFactor {
      pixelSize = Self.pixelSize(
        width: size.width,
        height: size.height,
        scale: scale
      )
    } else {
      let backingSize = convertToBacking(NSRect(origin: .zero, size: size)).size
      pixelSize = Self.pixelSize(width: backingSize.width, height: backingSize.height, scale: 1)
    }

    guard let pixelSize, isValidSurfacePixelSize(pixelSize) else { return nil }
    return pixelSize
  }

  private func contentScaleForSurface() -> (x: CGFloat, y: CGFloat) {
    if let window {
      return (window.backingScaleFactor, window.backingScaleFactor)
    }

    if let createdScaleFactor {
      return (createdScaleFactor, createdScaleFactor)
    }

    let localUnit = NSRect(x: 0, y: 0, width: 1, height: 1)
    let backingUnit = convertToBacking(localUnit)
    return (
      x: backingUnit.width > 0 ? backingUnit.width : 1,
      y: backingUnit.height > 0 ? backingUnit.height : 1
    )
  }

  private static func pixelSize(
    for size: GhosttySurfaceInitialSize,
    scale: CGFloat
  ) -> (width: UInt32, height: UInt32)? {
    pixelSize(width: CGFloat(size.width), height: CGFloat(size.height), scale: scale)
  }

  private static func pixelSize(
    width: CGFloat,
    height: CGFloat,
    scale: CGFloat
  ) -> (width: UInt32, height: UInt32)? {
    guard
      width > 0,
      height > 0,
      scale > 0,
      let pixelWidth = pixelDimension(width * scale),
      let pixelHeight = pixelDimension(height * scale)
    else {
      return nil
    }

    return (width: pixelWidth, height: pixelHeight)
  }

  private static func pixelDimension(_ value: CGFloat) -> UInt32? {
    let rounded = value.rounded(.toNearestOrAwayFromZero)
    guard rounded > 0, rounded <= CGFloat(UInt32.max) else { return nil }
    return UInt32(rounded)
  }

  private var minimumSurfacePixelSize: (width: UInt32, height: UInt32) {
    guard
      let sizeLimit = bridge.sizeLimit,
      sizeLimit.minWidth > 0,
      sizeLimit.minHeight > 0
    else {
      return Self.fallbackMinimumSurfacePixelSize
    }

    return (width: sizeLimit.minWidth, height: sizeLimit.minHeight)
  }

  private func isValidSurfacePixelSize(_ size: (width: UInt32, height: UInt32)) -> Bool {
    let minimumSize = minimumSurfacePixelSize
    return size.width >= minimumSize.width && size.height >= minimumSize.height
  }

  private func setSurfaceSize(width: UInt32, height: UInt32) {
    guard let surfaceHandle else { return }
    // Drop 0x0 calls: the surface has no real frame yet (pre-layout), and forwarding
    // them produces "very small terminal grid" warnings, redundant io_thread resizes,
    // and an early renderer pass that the IOSurfaceLayer later discards.
    guard width > 0, height > 0 else { return }
    if let last = lastSentSurfaceSize, last.width == width, last.height == height {
      return
    }
    lastSentSurfaceSize = (width, height)
    ghostty_surface_set_size(surfaceHandle, width, height)
  }

  public func sendText(_ text: String) {
    guard let surfaceHandle else { return }
    let utf8Count = text.utf8CString.count
    guard utf8Count > 1 else { return }
    text.withCString { pointer in
      ghostty_surface_text(surfaceHandle, pointer, UInt(utf8Count - 1))
    }
  }

  public func sendKeyPress(
    keyCode: UInt32,
    text: String? = nil,
    modifiers: NSEvent.ModifierFlags = []
  ) {
    guard let surfaceHandle else { return }
    var keyEvent = ghostty_input_key_s()
    keyEvent.action = GHOSTTY_ACTION_PRESS
    keyEvent.mods = GhosttyKeyMap.mods(from: modifiers)
    keyEvent.consumed_mods = GhosttyKeyMap.mods(from: modifiers.subtracting([.control, .command]))
    keyEvent.keycode = keyCode
    keyEvent.text = nil
    keyEvent.unshifted_codepoint = text?.unicodeScalars.first?.value ?? 0
    keyEvent.composing = false

    if let text, !text.isEmpty {
      text.withCString { pointer in
        keyEvent.text = pointer
        _ = ghostty_surface_key(surfaceHandle, keyEvent)
      }
    } else {
      _ = ghostty_surface_key(surfaceHandle, keyEvent)
    }
  }

  public func requestClose() {
    guard let surfaceHandle else { return }
    ghostty_surface_request_close(surfaceHandle)
  }

  public var foregroundProcessID: pid_t? {
    guard let surfaceHandle else { return nil }
    let pid = ghostty_surface_foreground_pid(surfaceHandle)
    guard pid > 0 else { return nil }
    return pid_t(pid)
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

  override var isOpaque: Bool { false }

  init(surfaceView: GhosttySurfaceView, controller: GhosttyTerminalController) {
    self.surfaceView = surfaceView
    self.controller = controller
    super.init(frame: .zero)

    wantsLayer = true
    layerContentsRedrawPolicy = .never
    layerContentsPlacement = .topLeft
    layer?.backgroundColor = NSColor.clear.cgColor
    layer?.isOpaque = false
    layer?.contentsGravity = .topLeft
    layer?.actions = GhosttyLayerActions.disabled

    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = false
    scrollView.usesPredominantAxisScrolling = true
    scrollView.scrollerStyle = .overlay
    scrollView.drawsBackground = false
    scrollView.contentView.clipsToBounds = false

    documentView.frame = .zero
    documentView.wantsLayer = true
    documentView.layerContentsRedrawPolicy = .never
    documentView.layerContentsPlacement = .topLeft
    documentView.layer?.backgroundColor = NSColor.clear.cgColor
    documentView.layer?.isOpaque = false
    documentView.layer?.contentsGravity = .topLeft
    documentView.layer?.actions = GhosttyLayerActions.disabled
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

  func prepareForHostResize(to size: CGSize) {
    surfaceView.prepareForHostResize(to: size)
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
