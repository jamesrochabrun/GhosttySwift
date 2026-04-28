import AppKit
import SwiftUI

@MainActor
public final class GhosttyTerminalContainerView: NSView {
  public let controller: GhosttyTerminalController
  public let bridge: GhosttySurfaceBridge
  public let runtime: GhosttyRuntime
  public let surfaceView: GhosttySurfaceView

  private let scrollView: GhosttySurfaceScrollView
  private let overlayModel: GhosttyTerminalOverlayModel
  private let searchOverlayHostingView: NSHostingView<GhosttyTerminalSearchOverlayHostView>
  private let secureInputHostingView: NSHostingView<GhosttyTerminalSecureInputBadgeHostView>
  private let childExitHostingView: NSHostingView<GhosttyTerminalChildExitBannerHostView>
  private var localKeyMonitor: Any?

  public override var isOpaque: Bool { false }

  public init(controller: GhosttyTerminalController) throws {
    self.controller = controller
    self.bridge = controller.bridge
    self.runtime = controller.runtime
    self.surfaceView = try GhosttySurfaceView(
      runtime: controller.runtime,
      configuration: controller.configuration,
      bridge: controller.bridge
    )
    self.scrollView = GhosttySurfaceScrollView(surfaceView: surfaceView, controller: controller)
    self.overlayModel = GhosttyTerminalOverlayModel(controller: controller)
    self.searchOverlayHostingView = NSHostingView(
      rootView: GhosttyTerminalSearchOverlayHostView(model: overlayModel)
    )
    self.secureInputHostingView = NSHostingView(
      rootView: GhosttyTerminalSecureInputBadgeHostView(model: overlayModel)
    )
    self.childExitHostingView = NSHostingView(
      rootView: GhosttyTerminalChildExitBannerHostView(model: overlayModel)
    )
    super.init(frame: .zero)

    wantsLayer = true
    layerContentsRedrawPolicy = .never
    layerContentsPlacement = .topLeft
    layer?.backgroundColor = NSColor.clear.cgColor
    layer?.isOpaque = false
    layer?.contentsGravity = .topLeft
    layer?.actions = GhosttyLayerActions.disabled

    addSubview(scrollView)
    addSubview(searchOverlayHostingView)
    addSubview(secureInputHostingView)
    addSubview(childExitHostingView)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    searchOverlayHostingView.translatesAutoresizingMaskIntoConstraints = false
    secureInputHostingView.translatesAutoresizingMaskIntoConstraints = false
    childExitHostingView.translatesAutoresizingMaskIntoConstraints = false
    searchOverlayHostingView.setContentHuggingPriority(.required, for: .horizontal)
    searchOverlayHostingView.setContentHuggingPriority(.required, for: .vertical)
    secureInputHostingView.setContentHuggingPriority(.required, for: .horizontal)
    secureInputHostingView.setContentHuggingPriority(.required, for: .vertical)
    childExitHostingView.setContentHuggingPriority(.required, for: .horizontal)
    childExitHostingView.setContentHuggingPriority(.required, for: .vertical)
    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      searchOverlayHostingView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      searchOverlayHostingView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      secureInputHostingView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
      secureInputHostingView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
      childExitHostingView.centerXAnchor.constraint(equalTo: centerXAnchor),
      childExitHostingView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
    ])

    controller.internalOnStateChange = { [weak self, weak overlayModel] controller in
      overlayModel?.sync(from: controller)
      self?.scrollView.syncFromController()
    }
    scrollView.syncFromController()
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

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    updateLocalKeyMonitor()
  }

  isolated deinit {
    if let localKeyMonitor {
      NSEvent.removeMonitor(localKeyMonitor)
    }
  }

  public func focusTerminal() {
    surfaceView.claimFirstResponder()
  }

  public func prepareForHostResize(to size: CGSize) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    scrollView.prepareForHostResize(to: size)
    CATransaction.commit()
  }

  private func updateLocalKeyMonitor() {
    if window == nil {
      if let localKeyMonitor {
        NSEvent.removeMonitor(localKeyMonitor)
        self.localKeyMonitor = nil
      }
    } else {
      installKeyMonitor()
    }
  }

  private func installKeyMonitor() {
    guard localKeyMonitor == nil else { return }
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }
      return handleSearchKeyEvent(event) ? nil : event
    }
  }

  private func handleSearchKeyEvent(_ event: NSEvent) -> Bool {
    guard controller.searchState != nil else { return false }

    let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    let key = event.charactersIgnoringModifiers?.lowercased()

    if event.keyCode == 53 {
      controller.endSearch()
      return true
    }

    if mods == [.command], key == "g" {
      controller.navigateSearchNext()
      return true
    }

    if mods == [.command, .shift], key == "g" {
      controller.navigateSearchPrevious()
      return true
    }

    if mods == [.command, .shift], key == "f" {
      controller.endSearch()
      return true
    }

    if mods == [.command], key == "v" {
      if let pastedString = NSPasteboard.general.string(forType: .string) {
        overlayModel.setSearchNeedle(overlayModel.searchNeedle + pastedString)
      }
      return true
    }

    if mods.isSubset(of: [.shift, .option, .capsLock]) {
      if event.keyCode == 36 || event.keyCode == 76 {
        controller.navigateSearchNext()
        return true
      }

      if event.keyCode == 51 || event.keyCode == 117 {
        guard !overlayModel.searchNeedle.isEmpty else { return true }
        overlayModel.setSearchNeedle(String(overlayModel.searchNeedle.dropLast()))
        return true
      }

      if let insertedText = searchText(for: event) {
        overlayModel.setSearchNeedle(overlayModel.searchNeedle + insertedText)
        return true
      }
    }

    return false
  }

  private func searchText(for event: NSEvent) -> String? {
    guard let characters = event.characters, !characters.isEmpty else { return nil }

    for scalar in characters.unicodeScalars {
      if scalar.value < 0x20 {
        return nil
      }

      if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
        return nil
      }
    }

    return characters
  }
}
