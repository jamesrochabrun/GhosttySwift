import AppKit
import GhosttyKit

public struct GhosttySurfaceSizeLimit: Equatable, Sendable {
  public let minWidth: UInt32
  public let minHeight: UInt32
  public let maxWidth: UInt32
  public let maxHeight: UInt32
}

public struct GhosttySurfaceScrollbarState: Equatable, Sendable {
  public let total: UInt64
  public let offset: UInt64
  public let length: UInt64
}

public enum GhosttySurfaceProgressState: Equatable, Sendable {
  case remove
  case set
  case error
  case indeterminate
  case pause
  case unknown(UInt32)
}

public struct GhosttySurfaceProgressReport: Equatable, Sendable {
  public let state: GhosttySurfaceProgressState
  public let progress: Int?
}

public struct GhosttySurfaceChildExitInfo: Equatable, Sendable {
  public let exitCode: UInt32
  public let runtimeMilliseconds: UInt64
}

public struct GhosttySurfaceDesktopNotification: Equatable, Sendable {
  public let title: String
  public let body: String
}

public struct GhosttySurfaceSearchState: Equatable, Sendable {
  public var needle: String?
  public var total: Int?
  public var selected: Int?

  public init(needle: String? = nil, total: Int? = nil, selected: Int? = nil) {
    self.needle = needle
    self.total = total
    self.selected = selected
  }
}

// Bridge state is re-authored against upstream Ghostty MIT sources,
// primarily macos/Sources/Ghostty/Ghostty.App.swift.
@MainActor
public final class GhosttySurfaceBridge {
  public private(set) var title: String = "Ghostty"
  public private(set) var workingDirectory: String?
  public private(set) var sizeLimit: GhosttySurfaceSizeLimit?
  public private(set) var cellSize: CGSize = .zero
  public private(set) var secureInputEnabled = false
  public private(set) var scrollbar: GhosttySurfaceScrollbarState?
  public private(set) var progressReport: GhosttySurfaceProgressReport?
  public private(set) var searchState: GhosttySurfaceSearchState?
  public private(set) var lastDesktopNotification: GhosttySurfaceDesktopNotification?
  public private(set) var childExitInfo: GhosttySurfaceChildExitInfo?
  public var onClose: ((Bool) -> Void)?
  public var onCloseWindow: (() -> Void)?
  public var onDesktopNotification: ((GhosttySurfaceDesktopNotification) -> Void)?
  public var onStateChange: (() -> Void)?

  weak var surfaceView: GhosttySurfaceView?
  var internalOnClose: ((Bool) -> Void)?
  var internalOnCloseWindow: (() -> Void)?

  public init() {}

  func attach(to surfaceView: GhosttySurfaceView) {
    self.surfaceView = surfaceView
  }

  func handleAction(_ action: ghostty_action_s) -> Bool {
    switch action.tag {
    case GHOSTTY_ACTION_CLOSE_WINDOW:
      internalOnCloseWindow?()
      onCloseWindow?()
      return true

    case GHOSTTY_ACTION_DESKTOP_NOTIFICATION:
      guard
        let titlePointer = action.action.desktop_notification.title,
        let bodyPointer = action.action.desktop_notification.body
      else {
        return false
      }
      let notification = GhosttySurfaceDesktopNotification(
        title: String(cString: titlePointer),
        body: String(cString: bodyPointer)
      )
      lastDesktopNotification = notification
      onDesktopNotification?(notification)
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SET_TITLE:
      guard let titlePointer = action.action.set_title.title else { return false }
      let title = String(cString: titlePointer)
      guard !title.isEmpty else { return false }
      self.title = title
      surfaceView?.setTitle(title)
      onStateChange?()
      return true

    case GHOSTTY_ACTION_PWD:
      guard let pwdPointer = action.action.pwd.pwd else { return false }
      workingDirectory = String(cString: pwdPointer)
      onStateChange?()
      return true

    case GHOSTTY_ACTION_MOUSE_SHAPE:
      surfaceView?.setCursorShape(action.action.mouse_shape)
      return true

    case GHOSTTY_ACTION_SECURE_INPUT:
      switch action.action.secure_input {
      case GHOSTTY_SECURE_INPUT_ON:
        secureInputEnabled = true
      case GHOSTTY_SECURE_INPUT_OFF:
        secureInputEnabled = false
      case GHOSTTY_SECURE_INPUT_TOGGLE:
        secureInputEnabled.toggle()
      default:
        return false
      }
      onStateChange?()
      return true

    case GHOSTTY_ACTION_CELL_SIZE:
      let backingSize = CGSize(
        width: Int(action.action.cell_size.width),
        height: Int(action.action.cell_size.height)
      )
      if let surfaceView {
        cellSize = surfaceView.convertFromBacking(backingSize)
      } else {
        cellSize = backingSize
      }
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SIZE_LIMIT:
      sizeLimit = GhosttySurfaceSizeLimit(
        minWidth: action.action.size_limit.min_width,
        minHeight: action.action.size_limit.min_height,
        maxWidth: action.action.size_limit.max_width,
        maxHeight: action.action.size_limit.max_height
      )
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SCROLLBAR:
      scrollbar = GhosttySurfaceScrollbarState(
        total: action.action.scrollbar.total,
        offset: action.action.scrollbar.offset,
        length: action.action.scrollbar.len
      )
      onStateChange?()
      return true

    case GHOSTTY_ACTION_PROGRESS_REPORT:
      progressReport = GhosttySurfaceProgressReport(
        state: progressState(from: action.action.progress_report.state),
        progress: action.action.progress_report.progress >= 0
          ? Int(action.action.progress_report.progress)
          : nil
      )
      onStateChange?()
      return true

    case GHOSTTY_ACTION_START_SEARCH:
      let needle = action.action.start_search.needle.map { String(cString: $0) }
      var state = searchState ?? GhosttySurfaceSearchState()
      state.needle = needle
      searchState = state
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SEARCH_TOTAL:
      var state = searchState ?? GhosttySurfaceSearchState()
      state.total = action.action.search_total.total >= 0 ? Int(action.action.search_total.total) : nil
      searchState = state
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SEARCH_SELECTED:
      var state = searchState ?? GhosttySurfaceSearchState()
      state.selected = action.action.search_selected.selected >= 0
        ? Int(action.action.search_selected.selected)
        : nil
      searchState = state
      onStateChange?()
      return true

    case GHOSTTY_ACTION_END_SEARCH:
      searchState = nil
      onStateChange?()
      return true

    case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
      childExitInfo = GhosttySurfaceChildExitInfo(
        exitCode: action.action.child_exited.exit_code,
        runtimeMilliseconds: action.action.child_exited.timetime_ms
      )
      onStateChange?()
      return true

    default:
      return false
    }
  }

  func closeSurface(processAlive: Bool) {
    GhosttyTrace.write("surface bridge closeSurface processAlive=\(processAlive)")
    internalOnClose?(processAlive)
    onClose?(processAlive)
  }

  private func progressState(
    from state: ghostty_action_progress_report_state_e
  ) -> GhosttySurfaceProgressState {
    switch state {
    case GHOSTTY_PROGRESS_STATE_REMOVE:
      return .remove
    case GHOSTTY_PROGRESS_STATE_SET:
      return .set
    case GHOSTTY_PROGRESS_STATE_ERROR:
      return .error
    case GHOSTTY_PROGRESS_STATE_INDETERMINATE:
      return .indeterminate
    case GHOSTTY_PROGRESS_STATE_PAUSE:
      return .pause
    default:
      return .unknown(state.rawValue)
    }
  }
}
