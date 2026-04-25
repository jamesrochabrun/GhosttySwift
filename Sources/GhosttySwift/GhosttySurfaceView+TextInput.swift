import AppKit
import GhosttyKit

// Text input and IME handling is re-authored against upstream Ghostty MIT sources,
// primarily SurfaceView_AppKit.swift.
extension GhosttySurfaceView: @preconcurrency NSTextInputClient {
  public func hasMarkedText() -> Bool {
    markedText.length > 0
  }

  public func markedRange() -> NSRange {
    guard markedText.length > 0 else { return NSRange() }
    return NSRange(location: 0, length: markedText.length)
  }

  public func selectedRange() -> NSRange {
    guard let surfaceHandle else { return NSRange() }

    var text = ghostty_text_s()
    guard ghostty_surface_read_selection(surfaceHandle, &text) else { return NSRange() }
    defer { ghostty_surface_free_text(surfaceHandle, &text) }
    return NSRange(location: Int(text.offset_start), length: Int(text.offset_len))
  }

  public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
    switch string {
    case let attributed as NSAttributedString:
      markedText = NSMutableAttributedString(attributedString: attributed)
    case let string as String:
      markedText = NSMutableAttributedString(string: string)
    default:
      return
    }

    if keyTextAccumulator == nil {
      syncPreedit()
    }
  }

  public func unmarkText() {
    guard markedText.length > 0 else { return }
    markedText.mutableString.setString("")
    syncPreedit()
  }

  public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
    []
  }

  public func attributedSubstring(
    forProposedRange range: NSRange,
    actualRange: NSRangePointer?
  ) -> NSAttributedString? {
    guard let surfaceHandle, range.length > 0 else { return nil }

    var text = ghostty_text_s()
    guard ghostty_surface_read_selection(surfaceHandle, &text) else { return nil }
    defer { ghostty_surface_free_text(surfaceHandle, &text) }

    actualRange?.pointee = NSRange(location: Int(text.offset_start), length: Int(text.offset_len))
    return NSAttributedString(string: String(cString: text.text))
  }

  public func characterIndex(for point: NSPoint) -> Int {
    0
  }

  public func firstRect(
    forCharacterRange range: NSRange,
    actualRange: NSRangePointer?
  ) -> NSRect {
    actualRange?.pointee = range

    guard let surfaceHandle else {
      return NSRect(x: frame.origin.x, y: frame.origin.y, width: 0, height: 0)
    }

    var x: Double = 0
    var y: Double = 0
    var width = Double(max(bridge.cellSize.width, 0))
    var height = Double(max(bridge.cellSize.height, 0))
    ghostty_surface_ime_point(surfaceHandle, &x, &y, &width, &height)

    let cellHeight = Double(max(bridge.cellSize.height, 0))
    let viewRect = NSRect(
      x: x,
      y: frame.size.height - y,
      width: width,
      height: max(height, cellHeight)
    )
    let windowRect = convert(viewRect, to: nil)
    guard let window else { return windowRect }
    return window.convertToScreen(windowRect)
  }

  public func insertText(_ string: Any, replacementRange: NSRange) {
    let characters: String
    switch string {
    case let attributed as NSAttributedString:
      characters = attributed.string
    case let string as String:
      characters = string
    default:
      return
    }

    unmarkText()

    if var accumulator = keyTextAccumulator {
      accumulator.append(characters)
      keyTextAccumulator = accumulator
      return
    }

    sendText(characters)
  }

  override public func doCommand(by selector: Selector) {
    // Intentionally ignore unhandled AppKit commands here so interpretKeyEvents
    // can drive composition without producing an NSBeep.
  }
}
