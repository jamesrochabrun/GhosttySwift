import AppKit
import GhosttyKit

// Re-authored against upstream Ghostty MIT sources,
// primarily macos/Sources/Ghostty/Ghostty.Input.swift.
enum GhosttyKeyMap {
  static func mods(from flags: UInt) -> ghostty_input_mods_e {
    mods(from: NSEvent.ModifierFlags(rawValue: flags))
  }

  static func mods(from flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
    var raw: UInt32 = GHOSTTY_MODS_NONE.rawValue

    if flags.contains(.shift) { raw |= GHOSTTY_MODS_SHIFT.rawValue }
    if flags.contains(.control) { raw |= GHOSTTY_MODS_CTRL.rawValue }
    if flags.contains(.option) { raw |= GHOSTTY_MODS_ALT.rawValue }
    if flags.contains(.command) { raw |= GHOSTTY_MODS_SUPER.rawValue }
    if flags.contains(.capsLock) { raw |= GHOSTTY_MODS_CAPS.rawValue }
    if flags.contains(.numericPad) { raw |= GHOSTTY_MODS_NUM.rawValue }

    let rawFlags = flags.rawValue
    if rawFlags & UInt(NX_DEVICERSHIFTKEYMASK) != 0 { raw |= GHOSTTY_MODS_SHIFT_RIGHT.rawValue }
    if rawFlags & UInt(NX_DEVICERCTLKEYMASK) != 0 { raw |= GHOSTTY_MODS_CTRL_RIGHT.rawValue }
    if rawFlags & UInt(NX_DEVICERALTKEYMASK) != 0 { raw |= GHOSTTY_MODS_ALT_RIGHT.rawValue }
    if rawFlags & UInt(NX_DEVICERCMDKEYMASK) != 0 { raw |= GHOSTTY_MODS_SUPER_RIGHT.rawValue }

    return ghostty_input_mods_e(raw)
  }

  static func eventModifierFlags(from mods: ghostty_input_mods_e) -> NSEvent.ModifierFlags {
    var flags = NSEvent.ModifierFlags(rawValue: 0)

    if mods.rawValue & GHOSTTY_MODS_SHIFT.rawValue != 0 { flags.insert(.shift) }
    if mods.rawValue & GHOSTTY_MODS_CTRL.rawValue != 0 { flags.insert(.control) }
    if mods.rawValue & GHOSTTY_MODS_ALT.rawValue != 0 { flags.insert(.option) }
    if mods.rawValue & GHOSTTY_MODS_SUPER.rawValue != 0 { flags.insert(.command) }
    if mods.rawValue & GHOSTTY_MODS_CAPS.rawValue != 0 { flags.insert(.capsLock) }
    if mods.rawValue & GHOSTTY_MODS_NUM.rawValue != 0 { flags.insert(.numericPad) }

    return flags
  }
}
