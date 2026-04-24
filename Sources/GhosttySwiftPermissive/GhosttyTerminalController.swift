import AppKit

@MainActor
public final class GhosttyTerminalController {
  public let runtime: GhosttyRuntime
  public let bridge: GhosttySurfaceBridge
  public let configuration: GhosttySurfaceConfiguration

  public private(set) var title: String
  public private(set) var workingDirectory: String?
  public private(set) var sizeLimit: GhosttySurfaceSizeLimit?
  public private(set) var cellSize: CGSize
  public private(set) var secureInputEnabled: Bool
  public private(set) var scrollbar: GhosttySurfaceScrollbarState?
  public private(set) var progressReport: GhosttySurfaceProgressReport?
  public private(set) var searchState: GhosttySurfaceSearchState?
  public private(set) var lastDesktopNotification: GhosttySurfaceDesktopNotification?
  public private(set) var childExitInfo: GhosttySurfaceChildExitInfo?
  public private(set) var lastSurfaceCloseProcessAlive: Bool?

  public var onStateChange: ((GhosttyTerminalController) -> Void)?
  public var onClose: ((Bool) -> Void)?
  public var onCloseWindow: (() -> Void)?
  public var onDesktopNotification: ((GhosttySurfaceDesktopNotification) -> Void)?

  public init(
    runtime: GhosttyRuntime? = nil,
    configPath: String? = nil,
    configuration: GhosttySurfaceConfiguration = .init(),
    bridge: GhosttySurfaceBridge = GhosttySurfaceBridge()
  ) throws {
    self.runtime = try runtime ?? GhosttyRuntime(configPath: configPath)
    self.bridge = bridge
    self.configuration = configuration
    self.title = bridge.title
    self.workingDirectory = bridge.workingDirectory
    self.sizeLimit = bridge.sizeLimit
    self.cellSize = bridge.cellSize
    self.secureInputEnabled = bridge.secureInputEnabled
    self.scrollbar = bridge.scrollbar
    self.progressReport = bridge.progressReport
    self.searchState = bridge.searchState
    self.lastDesktopNotification = bridge.lastDesktopNotification
    self.childExitInfo = bridge.childExitInfo

    bridge.onStateChange = { [weak self] in
      self?.syncFromBridge()
    }
    bridge.onClose = { [weak self] processAlive in
      guard let self else { return }
      self.lastSurfaceCloseProcessAlive = processAlive
      self.onStateChange?(self)
      self.onClose?(processAlive)
    }
    bridge.onCloseWindow = { [weak self] in
      guard let self else { return }
      self.onStateChange?(self)
      self.onCloseWindow?()
    }
    bridge.onDesktopNotification = { [weak self] notification in
      guard let self else { return }
      self.lastDesktopNotification = notification
      self.onStateChange?(self)
      self.onDesktopNotification?(notification)
    }

    syncFromBridge()
  }

  private func syncFromBridge() {
    title = bridge.title
    workingDirectory = bridge.workingDirectory
    sizeLimit = bridge.sizeLimit
    cellSize = bridge.cellSize
    secureInputEnabled = bridge.secureInputEnabled
    scrollbar = bridge.scrollbar
    progressReport = bridge.progressReport
    searchState = bridge.searchState
    lastDesktopNotification = bridge.lastDesktopNotification
    childExitInfo = bridge.childExitInfo
    onStateChange?(self)
  }
}
