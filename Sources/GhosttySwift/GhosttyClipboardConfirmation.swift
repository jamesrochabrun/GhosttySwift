import GhosttyKit

public enum GhosttyClipboardLocation: Equatable, Sendable {
  case standard
  case selection

  init?(_ location: ghostty_clipboard_e) {
    switch location {
    case GHOSTTY_CLIPBOARD_STANDARD:
      self = .standard
    case GHOSTTY_CLIPBOARD_SELECTION:
      self = .selection
    default:
      return nil
    }
  }
}

public enum GhosttyClipboardRequest: Equatable, Sendable {
  case paste
  case osc52Read
  case osc52Write

  init?(_ request: ghostty_clipboard_request_e) {
    switch request {
    case GHOSTTY_CLIPBOARD_REQUEST_PASTE:
      self = .paste
    case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_READ:
      self = .osc52Read
    case GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE:
      self = .osc52Write
    default:
      return nil
    }
  }
}

public enum GhosttyClipboardDecision: Equatable, Sendable {
  case allow
  case deny
}

public struct GhosttyClipboardConfirmation: Equatable, Sendable {
  public let request: GhosttyClipboardRequest
  public let location: GhosttyClipboardLocation?
  public let contents: String

  public init(
    request: GhosttyClipboardRequest,
    location: GhosttyClipboardLocation?,
    contents: String
  ) {
    self.request = request
    self.location = location
    self.contents = contents
  }
}

public typealias GhosttyClipboardConfirmationHandler =
  @MainActor (GhosttyClipboardConfirmation) async -> GhosttyClipboardDecision
