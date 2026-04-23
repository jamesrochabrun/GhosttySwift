import AppKit
import GhosttyKit

// Re-authored against upstream Ghostty MIT sources,
// primarily macos/Sources/Ghostty/NSEvent+Extension.swift.
extension NSEvent {
  func ghosttyKeyEvent(
    _ action: ghostty_input_action_e,
    translationMods: NSEvent.ModifierFlags? = nil
  ) -> ghostty_input_key_s {
    var keyEvent = ghostty_input_key_s()
    keyEvent.action = action
    keyEvent.keycode = UInt32(keyCode)
    keyEvent.text = nil
    keyEvent.composing = false
    keyEvent.mods = GhosttyKeyMap.mods(from: modifierFlags)
    keyEvent.consumed_mods = GhosttyKeyMap.mods(
      from: (translationMods ?? modifierFlags).subtracting([.control, .command])
    )

    keyEvent.unshifted_codepoint = 0
    if type == .keyDown || type == .keyUp {
      if let chars = characters(byApplyingModifiers: []),
        let codepoint = chars.unicodeScalars.first
      {
        keyEvent.unshifted_codepoint = codepoint.value
      }
    }

    return keyEvent
  }

  var ghosttyCharacters: String? {
    guard let characters else { return nil }

    if characters.count == 1,
      let scalar = characters.unicodeScalars.first
    {
      if scalar.value < 0x20 {
        return self.characters(byApplyingModifiers: modifierFlags.subtracting(.control))
      }

      if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
        return nil
      }
    }

    return characters
  }
}
