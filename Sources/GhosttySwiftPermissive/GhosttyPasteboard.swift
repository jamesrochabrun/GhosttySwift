import AppKit
import GhosttyKit
import UniformTypeIdentifiers

enum GhosttyShell {
  private static let escapeCharacters = "\\ ()[]{}<>\"'`!#$&;|*?\t"

  static func escape(_ value: String) -> String {
    var result = value

    for character in escapeCharacters {
      result = result.replacing(String(character), with: "\\\(character)")
    }

    return result
  }
}

extension NSPasteboard.PasteboardType {
  // Re-authored against upstream Ghostty MIT sources,
  // primarily Helpers/Extensions/NSPasteboard+Extension.swift.
  init?(mimeType: String) {
    switch mimeType {
    case "text/plain":
      self = .string
      return
    default:
      break
    }

    guard let type = UTType(mimeType: mimeType) else {
      self.init(mimeType)
      return
    }

    self.init(type.identifier)
  }
}

extension NSPasteboard {
  @MainActor
  static let ghosttySelection: NSPasteboard = {
    NSPasteboard(name: .init("com.mitchellh.ghostty.selection"))
  }()

  @MainActor
  func getOpinionatedStringContents() -> String? {
    if let urls = readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
      return urls
        .map { $0.isFileURL ? GhosttyShell.escape($0.path) : $0.absoluteString }
        .joined(separator: " ")
    }

    return string(forType: .string)
  }

  @MainActor
  static func ghostty(_ clipboard: ghostty_clipboard_e) -> NSPasteboard? {
    switch clipboard {
    case GHOSTTY_CLIPBOARD_STANDARD:
      return .general
    case GHOSTTY_CLIPBOARD_SELECTION:
      return ghosttySelection
    default:
      return nil
    }
  }
}
