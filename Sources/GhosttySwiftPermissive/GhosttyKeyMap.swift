import AppKit
import Carbon.HIToolbox
import GhosttyKit

struct GhosttyKeyEventPayload {
  let action: ghostty_input_action_e
  let mods: ghostty_input_mods_e
  let consumedMods: ghostty_input_mods_e
  let keycode: UInt32
  let text: String?
  let unshiftedCodepoint: UInt32
  let composing: Bool
}

enum GhosttyKeyMap {
  static func keyEventPayload(
    keyCode: UInt16,
    modifierFlags: UInt,
    characters: String?,
    charactersIgnoringModifiers: String?,
    action: ghostty_input_action_e,
    consumedModifierFlags: UInt = 0
  ) -> GhosttyKeyEventPayload {
    let key = key(for: keyCode)

    return GhosttyKeyEventPayload(
      action: action,
      mods: mods(from: modifierFlags),
      consumedMods: mods(from: consumedModifierFlags),
      keycode: UInt32(keyCode),
      text: isSpecialKey(key) ? nil : printableText(from: characters),
      unshiftedCodepoint: printableCodepoint(from: charactersIgnoringModifiers) ?? 0,
      composing: false
    )
  }

  static func modifierEventPayload(
    keyCode: UInt16,
    modifierFlags: UInt
  ) -> GhosttyKeyEventPayload? {
    let key = key(for: keyCode)
    guard isModifierKey(key) else { return nil }

    return GhosttyKeyEventPayload(
      action: modifierAction(for: keyCode, modifierFlags: modifierFlags),
      mods: mods(from: modifierFlags),
      consumedMods: ghostty_input_mods_e(rawValue: 0),
      keycode: UInt32(keyCode),
      text: nil,
      unshiftedCodepoint: 0,
      composing: false
    )
  }

  static func key(for keyCode: UInt16) -> ghostty_input_key_e {
    switch Int(keyCode) {
    case kVK_ANSI_A: GHOSTTY_KEY_A
    case kVK_ANSI_B: GHOSTTY_KEY_B
    case kVK_ANSI_C: GHOSTTY_KEY_C
    case kVK_ANSI_D: GHOSTTY_KEY_D
    case kVK_ANSI_E: GHOSTTY_KEY_E
    case kVK_ANSI_F: GHOSTTY_KEY_F
    case kVK_ANSI_G: GHOSTTY_KEY_G
    case kVK_ANSI_H: GHOSTTY_KEY_H
    case kVK_ANSI_I: GHOSTTY_KEY_I
    case kVK_ANSI_J: GHOSTTY_KEY_J
    case kVK_ANSI_K: GHOSTTY_KEY_K
    case kVK_ANSI_L: GHOSTTY_KEY_L
    case kVK_ANSI_M: GHOSTTY_KEY_M
    case kVK_ANSI_N: GHOSTTY_KEY_N
    case kVK_ANSI_O: GHOSTTY_KEY_O
    case kVK_ANSI_P: GHOSTTY_KEY_P
    case kVK_ANSI_Q: GHOSTTY_KEY_Q
    case kVK_ANSI_R: GHOSTTY_KEY_R
    case kVK_ANSI_S: GHOSTTY_KEY_S
    case kVK_ANSI_T: GHOSTTY_KEY_T
    case kVK_ANSI_U: GHOSTTY_KEY_U
    case kVK_ANSI_V: GHOSTTY_KEY_V
    case kVK_ANSI_W: GHOSTTY_KEY_W
    case kVK_ANSI_X: GHOSTTY_KEY_X
    case kVK_ANSI_Y: GHOSTTY_KEY_Y
    case kVK_ANSI_Z: GHOSTTY_KEY_Z

    case kVK_ANSI_0: GHOSTTY_KEY_DIGIT_0
    case kVK_ANSI_1: GHOSTTY_KEY_DIGIT_1
    case kVK_ANSI_2: GHOSTTY_KEY_DIGIT_2
    case kVK_ANSI_3: GHOSTTY_KEY_DIGIT_3
    case kVK_ANSI_4: GHOSTTY_KEY_DIGIT_4
    case kVK_ANSI_5: GHOSTTY_KEY_DIGIT_5
    case kVK_ANSI_6: GHOSTTY_KEY_DIGIT_6
    case kVK_ANSI_7: GHOSTTY_KEY_DIGIT_7
    case kVK_ANSI_8: GHOSTTY_KEY_DIGIT_8
    case kVK_ANSI_9: GHOSTTY_KEY_DIGIT_9

    case kVK_ANSI_Minus: GHOSTTY_KEY_MINUS
    case kVK_ANSI_Equal: GHOSTTY_KEY_EQUAL
    case kVK_ANSI_LeftBracket: GHOSTTY_KEY_BRACKET_LEFT
    case kVK_ANSI_RightBracket: GHOSTTY_KEY_BRACKET_RIGHT
    case kVK_ANSI_Backslash: GHOSTTY_KEY_BACKSLASH
    case kVK_ANSI_Semicolon: GHOSTTY_KEY_SEMICOLON
    case kVK_ANSI_Quote: GHOSTTY_KEY_QUOTE
    case kVK_ANSI_Grave: GHOSTTY_KEY_BACKQUOTE
    case kVK_ANSI_Comma: GHOSTTY_KEY_COMMA
    case kVK_ANSI_Period: GHOSTTY_KEY_PERIOD
    case kVK_ANSI_Slash: GHOSTTY_KEY_SLASH

    case kVK_Return: GHOSTTY_KEY_ENTER
    case kVK_ANSI_KeypadEnter: GHOSTTY_KEY_NUMPAD_ENTER
    case kVK_Tab: GHOSTTY_KEY_TAB
    case kVK_Space: GHOSTTY_KEY_SPACE
    case kVK_Delete: GHOSTTY_KEY_BACKSPACE
    case kVK_ForwardDelete: GHOSTTY_KEY_DELETE
    case kVK_Escape: GHOSTTY_KEY_ESCAPE
    case kVK_LeftArrow: GHOSTTY_KEY_ARROW_LEFT
    case kVK_RightArrow: GHOSTTY_KEY_ARROW_RIGHT
    case kVK_DownArrow: GHOSTTY_KEY_ARROW_DOWN
    case kVK_UpArrow: GHOSTTY_KEY_ARROW_UP
    case kVK_Home: GHOSTTY_KEY_HOME
    case kVK_End: GHOSTTY_KEY_END
    case kVK_PageUp: GHOSTTY_KEY_PAGE_UP
    case kVK_PageDown: GHOSTTY_KEY_PAGE_DOWN
    case kVK_Help: GHOSTTY_KEY_HELP

    case kVK_Shift: GHOSTTY_KEY_SHIFT_LEFT
    case kVK_RightShift: GHOSTTY_KEY_SHIFT_RIGHT
    case kVK_Control: GHOSTTY_KEY_CONTROL_LEFT
    case kVK_RightControl: GHOSTTY_KEY_CONTROL_RIGHT
    case kVK_Option: GHOSTTY_KEY_ALT_LEFT
    case kVK_RightOption: GHOSTTY_KEY_ALT_RIGHT
    case kVK_Command: GHOSTTY_KEY_META_LEFT
    case kVK_RightCommand: GHOSTTY_KEY_META_RIGHT
    case kVK_CapsLock: GHOSTTY_KEY_CAPS_LOCK
    case kVK_Function: GHOSTTY_KEY_FN

    case kVK_F1: GHOSTTY_KEY_F1
    case kVK_F2: GHOSTTY_KEY_F2
    case kVK_F3: GHOSTTY_KEY_F3
    case kVK_F4: GHOSTTY_KEY_F4
    case kVK_F5: GHOSTTY_KEY_F5
    case kVK_F6: GHOSTTY_KEY_F6
    case kVK_F7: GHOSTTY_KEY_F7
    case kVK_F8: GHOSTTY_KEY_F8
    case kVK_F9: GHOSTTY_KEY_F9
    case kVK_F10: GHOSTTY_KEY_F10
    case kVK_F11: GHOSTTY_KEY_F11
    case kVK_F12: GHOSTTY_KEY_F12

    default: GHOSTTY_KEY_UNIDENTIFIED
    }
  }

  static func mods(from flags: UInt) -> ghostty_input_mods_e {
    var raw: UInt32 = 0

    if flags & shiftMask != 0 {
      raw |= GHOSTTY_MODS_SHIFT.rawValue
      if flags & rightShiftMask != 0 { raw |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
    }

    if flags & controlMask != 0 {
      raw |= GHOSTTY_MODS_CTRL.rawValue
      if flags & rightControlMask != 0 { raw |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
    }

    if flags & optionMask != 0 {
      raw |= GHOSTTY_MODS_ALT.rawValue
      if flags & rightOptionMask != 0 { raw |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
    }

    if flags & commandMask != 0 {
      raw |= GHOSTTY_MODS_SUPER.rawValue
      if flags & rightCommandMask != 0 { raw |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }
    }

    if flags & capsLockMask != 0 {
      raw |= GHOSTTY_MODS_CAPS.rawValue
    }

    if flags & numericPadMask != 0 {
      raw |= GHOSTTY_MODS_NUM.rawValue
    }

    return ghostty_input_mods_e(rawValue: raw)
  }

  static func eventModifierFlags(from mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
    var flags = NSEvent.ModifierFlags()

    if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { flags.insert(.shift) }
    if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { flags.insert(.control) }
    if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { flags.insert(.option) }
    if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { flags.insert(.command) }
    if mods.rawValue & GHOSTTY_MODS_CAPS.rawValue != 0 { flags.insert(.capsLock) }
    if mods.rawValue & GHOSTTY_MODS_NUM.rawValue != 0 { flags.insert(.numericPad) }

    return flags
  }

  static func isSpecialKey(_ key: ghostty_input_key_e) -> Bool {
    switch key {
    case GHOSTTY_KEY_ARROW_UP, GHOSTTY_KEY_ARROW_DOWN,
      GHOSTTY_KEY_ARROW_LEFT, GHOSTTY_KEY_ARROW_RIGHT,
      GHOSTTY_KEY_HOME, GHOSTTY_KEY_END,
      GHOSTTY_KEY_PAGE_UP, GHOSTTY_KEY_PAGE_DOWN,
      GHOSTTY_KEY_BACKSPACE, GHOSTTY_KEY_DELETE,
      GHOSTTY_KEY_ENTER, GHOSTTY_KEY_NUMPAD_ENTER,
      GHOSTTY_KEY_TAB, GHOSTTY_KEY_ESCAPE,
      GHOSTTY_KEY_F1, GHOSTTY_KEY_F2, GHOSTTY_KEY_F3, GHOSTTY_KEY_F4,
      GHOSTTY_KEY_F5, GHOSTTY_KEY_F6, GHOSTTY_KEY_F7, GHOSTTY_KEY_F8,
      GHOSTTY_KEY_F9, GHOSTTY_KEY_F10, GHOSTTY_KEY_F11, GHOSTTY_KEY_F12,
      GHOSTTY_KEY_INSERT, GHOSTTY_KEY_HELP,
      GHOSTTY_KEY_CAPS_LOCK, GHOSTTY_KEY_FN,
      GHOSTTY_KEY_SHIFT_LEFT, GHOSTTY_KEY_SHIFT_RIGHT,
      GHOSTTY_KEY_CONTROL_LEFT, GHOSTTY_KEY_CONTROL_RIGHT,
      GHOSTTY_KEY_ALT_LEFT, GHOSTTY_KEY_ALT_RIGHT,
      GHOSTTY_KEY_META_LEFT, GHOSTTY_KEY_META_RIGHT:
      return true
    default:
      return false
    }
  }

  private static func isModifierKey(_ key: ghostty_input_key_e) -> Bool {
    switch key {
    case GHOSTTY_KEY_SHIFT_LEFT, GHOSTTY_KEY_SHIFT_RIGHT,
      GHOSTTY_KEY_CONTROL_LEFT, GHOSTTY_KEY_CONTROL_RIGHT,
      GHOSTTY_KEY_ALT_LEFT, GHOSTTY_KEY_ALT_RIGHT,
      GHOSTTY_KEY_META_LEFT, GHOSTTY_KEY_META_RIGHT,
      GHOSTTY_KEY_CAPS_LOCK, GHOSTTY_KEY_FN:
      return true
    default:
      return false
    }
  }

  private static func modifierAction(
    for keyCode: UInt16,
    modifierFlags: UInt
  ) -> ghostty_input_action_e {
    isModifierActive(keyCode: keyCode, modifierFlags: modifierFlags)
      ? GHOSTTY_ACTION_PRESS
      : GHOSTTY_ACTION_RELEASE
  }

  private static func isModifierActive(
    keyCode: UInt16,
    modifierFlags: UInt
  ) -> Bool {
    switch Int(keyCode) {
    case kVK_Shift:
      modifierFlags & leftShiftMask != 0
    case kVK_RightShift:
      modifierFlags & rightShiftMask != 0
    case kVK_Control:
      modifierFlags & leftControlMask != 0
    case kVK_RightControl:
      modifierFlags & rightControlMask != 0
    case kVK_Option:
      modifierFlags & leftOptionMask != 0
    case kVK_RightOption:
      modifierFlags & rightOptionMask != 0
    case kVK_Command:
      modifierFlags & leftCommandMask != 0
    case kVK_RightCommand:
      modifierFlags & rightCommandMask != 0
    case kVK_CapsLock:
      modifierFlags & capsLockMask != 0
    case kVK_Function:
      modifierFlags & functionMask != 0
    default:
      false
    }
  }

  private static func printableText(from raw: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }
    if raw.unicodeScalars.contains(where: isAppleFunctionKeyScalar) {
      return nil
    }
    return raw
  }

  private static func printableCodepoint(from raw: String?) -> UInt32? {
    guard let first = raw?.unicodeScalars.first else { return nil }
    if isAppleFunctionKeyScalar(first) {
      return nil
    }
    return first.value
  }

  private static func isAppleFunctionKeyScalar(_ scalar: Unicode.Scalar) -> Bool {
    scalar.value >= 0xF700 && scalar.value <= 0xF8FF
  }

  private static let capsLockMask = NSEvent.ModifierFlags.capsLock.rawValue
  private static let shiftMask = NSEvent.ModifierFlags.shift.rawValue
  private static let controlMask = NSEvent.ModifierFlags.control.rawValue
  private static let optionMask = NSEvent.ModifierFlags.option.rawValue
  private static let commandMask = NSEvent.ModifierFlags.command.rawValue
  private static let numericPadMask = NSEvent.ModifierFlags.numericPad.rawValue
  private static let functionMask = NSEvent.ModifierFlags.function.rawValue

  private static let leftControlMask: UInt = 0x00000001
  private static let leftShiftMask: UInt = 0x00000002
  private static let rightShiftMask: UInt = 0x00000004
  private static let leftCommandMask: UInt = 0x00000008
  private static let rightCommandMask: UInt = 0x00000010
  private static let leftOptionMask: UInt = 0x00000020
  private static let rightOptionMask: UInt = 0x00000040
  private static let rightControlMask: UInt = 0x00002000
}
