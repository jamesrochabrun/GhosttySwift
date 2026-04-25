import AppKit
import GhosttyKit

// Input routing is re-authored against upstream Ghostty MIT sources,
// primarily SurfaceView_AppKit.swift, Ghostty.Input.swift, and NSEvent+Extension.swift.
extension GhosttySurfaceView {
  override public func updateTrackingAreas() {
    super.updateTrackingAreas()
    installTrackingAreaIfNeeded()
  }

  override public func keyDown(with event: NSEvent) {
    guard let surfaceHandle else {
      interpretKeyEvents([event])
      return
    }

    let translatedGhosttyModifiers = GhosttyKeyMap.eventModifierFlags(
      from: ghostty_surface_key_translation_mods(surfaceHandle, GhosttyKeyMap.mods(from: event.modifierFlags))
    )
    var translationModifiers = event.modifierFlags

    for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
      if translatedGhosttyModifiers.contains(flag) {
        translationModifiers.insert(flag)
      } else {
        translationModifiers.remove(flag)
      }
    }

    let translationEvent: NSEvent
    if translationModifiers == event.modifierFlags {
      translationEvent = event
    } else {
      translationEvent = NSEvent.keyEvent(
        with: event.type,
        location: event.locationInWindow,
        modifierFlags: translationModifiers,
        timestamp: event.timestamp,
        windowNumber: event.windowNumber,
        context: nil,
        characters: event.characters(byApplyingModifiers: translationModifiers) ?? "",
        charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
        isARepeat: event.isARepeat,
        keyCode: event.keyCode
      ) ?? event
    }

    let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
    keyTextAccumulator = []
    defer { keyTextAccumulator = nil }

    let markedTextBefore = markedText.length > 0
    interpretKeyEvents([translationEvent])
    syncPreedit(clearIfNeeded: markedTextBefore)

    if let keyTextAccumulator, !keyTextAccumulator.isEmpty {
      for text in keyTextAccumulator {
        _ = keyAction(
          action,
          event: event,
          translationEvent: translationEvent,
          text: text,
          to: surfaceHandle
        )
      }
    } else {
      _ = keyAction(
        action,
        event: event,
        translationEvent: translationEvent,
        text: translationEvent.ghosttyCharacters,
        composing: markedText.length > 0 || markedTextBefore,
        to: surfaceHandle
      )
    }
  }

  override public func keyUp(with event: NSEvent) {
    guard let surfaceHandle else {
      super.keyUp(with: event)
      return
    }

    _ = keyAction(GHOSTTY_ACTION_RELEASE, event: event, to: surfaceHandle)
  }

  override public func flagsChanged(with event: NSEvent) {
    guard let surfaceHandle else {
      super.flagsChanged(with: event)
      return
    }

    if hasMarkedText() {
      return
    }

    let modifier: UInt32
    switch event.keyCode {
    case 0x39: modifier = GHOSTTY_MODS_CAPS.rawValue
    case 0x38, 0x3C: modifier = GHOSTTY_MODS_SHIFT.rawValue
    case 0x3B, 0x3E: modifier = GHOSTTY_MODS_CTRL.rawValue
    case 0x3A, 0x3D: modifier = GHOSTTY_MODS_ALT.rawValue
    case 0x37, 0x36: modifier = GHOSTTY_MODS_SUPER.rawValue
    default:
      super.flagsChanged(with: event)
      return
    }

    let modifiers = GhosttyKeyMap.mods(from: event.modifierFlags)
    var action = GHOSTTY_ACTION_RELEASE
    if modifiers.rawValue & modifier != 0 {
      let sidePressed: Bool
      switch event.keyCode {
      case 0x3C:
        sidePressed = event.modifierFlags.rawValue & UInt(NX_DEVICERSHIFTKEYMASK) != 0
      case 0x3E:
        sidePressed = event.modifierFlags.rawValue & UInt(NX_DEVICERCTLKEYMASK) != 0
      case 0x3D:
        sidePressed = event.modifierFlags.rawValue & UInt(NX_DEVICERALTKEYMASK) != 0
      case 0x36:
        sidePressed = event.modifierFlags.rawValue & UInt(NX_DEVICERCMDKEYMASK) != 0
      default:
        sidePressed = true
      }

      if sidePressed {
        action = GHOSTTY_ACTION_PRESS
      }
    }

    _ = keyAction(action, event: event, to: surfaceHandle)
  }

  override public func mouseDown(with event: NSEvent) {
    claimFirstResponder()
    sendMouseButton(.press, ghosttyButton(from: event.buttonNumber, defaultLeft: true), event: event)
  }

  override public func mouseUp(with event: NSEvent) {
    sendMouseButton(.release, ghosttyButton(from: event.buttonNumber, defaultLeft: true), event: event)
  }

  override public func rightMouseDown(with event: NSEvent) {
    claimFirstResponder()
    sendMouseButton(.press, GHOSTTY_MOUSE_RIGHT, event: event)
  }

  override public func rightMouseUp(with event: NSEvent) {
    sendMouseButton(.release, GHOSTTY_MOUSE_RIGHT, event: event)
  }

  override public func otherMouseDown(with event: NSEvent) {
    claimFirstResponder()
    sendMouseButton(.press, ghosttyButton(from: event.buttonNumber, defaultLeft: false), event: event)
  }

  override public func otherMouseUp(with event: NSEvent) {
    sendMouseButton(.release, ghosttyButton(from: event.buttonNumber, defaultLeft: false), event: event)
  }

  override public func mouseDragged(with event: NSEvent) {
    sendMousePos(event)
  }

  override public func rightMouseDragged(with event: NSEvent) {
    sendMousePos(event)
  }

  override public func otherMouseDragged(with event: NSEvent) {
    sendMousePos(event)
  }

  override public func mouseMoved(with event: NSEvent) {
    sendMousePos(event)
  }

  override public func mouseEntered(with event: NSEvent) {
    sendMousePos(event)
  }

  override public func mouseExited(with event: NSEvent) {
    if NSEvent.pressedMouseButtons != 0 {
      sendMousePos(event)
    } else {
      sendMousePos(GhosttyMouseMap.exitedViewportPoint, modifierFlags: event.modifierFlags)
    }
  }

  override public func scrollWheel(with event: NSEvent) {
    guard let surfaceHandle else { return }
    let scrollMods: ghostty_input_scroll_mods_t = event.hasPreciseScrollingDeltas ? 1 : 0
    ghostty_surface_mouse_scroll(
      surfaceHandle,
      Double(event.scrollingDeltaX),
      Double(event.scrollingDeltaY),
      scrollMods
    )
  }

  func installTrackingAreaIfNeeded() {
    for area in trackingAreas {
      removeTrackingArea(area)
    }

    guard window != nil else { return }

    let area = NSTrackingArea(
      rect: frame,
      options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
  }

  private func keyAction(
    _ action: ghostty_input_action_e,
    event: NSEvent,
    translationEvent: NSEvent? = nil,
    text: String? = nil,
    composing: Bool = false,
    to surface: ghostty_surface_t
  ) -> Bool {
    var keyEvent = event.ghosttyKeyEvent(action, translationMods: translationEvent?.modifierFlags)
    keyEvent.composing = composing

    if let text, !text.isEmpty, let firstByte = text.utf8.first, firstByte >= 0x20 {
      return text.withCString { pointer in
        keyEvent.text = pointer
        return ghostty_surface_key(surface, keyEvent)
      }
    }

    return ghostty_surface_key(surface, keyEvent)
  }

  private enum MouseState {
    case press
    case release
  }

  private func sendMouseButton(
    _ state: MouseState,
    _ button: ghostty_input_mouse_button_e,
    event: NSEvent
  ) {
    guard let surfaceHandle else { return }
    sendMousePos(event)
    let mouseState: ghostty_input_mouse_state_e = state == .press ? GHOSTTY_MOUSE_PRESS : GHOSTTY_MOUSE_RELEASE
    let mods = GhosttyKeyMap.mods(from: event.modifierFlags)
    _ = ghostty_surface_mouse_button(surfaceHandle, mouseState, button, mods)
  }

  private func sendMousePos(_ event: NSEvent) {
    let localPoint = convert(event.locationInWindow, from: nil)
    let viewportPoint = GhosttyMouseMap.viewportPoint(for: localPoint, height: bounds.height)
    sendMousePos(viewportPoint, modifierFlags: event.modifierFlags)
  }

  private func sendMousePos(_ point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
    guard let surfaceHandle else { return }
    let mods = GhosttyKeyMap.mods(from: modifierFlags)
    ghostty_surface_mouse_pos(surfaceHandle, point.x, point.y, mods)
  }

  private func ghosttyButton(
    from buttonNumber: Int,
    defaultLeft: Bool
  ) -> ghostty_input_mouse_button_e {
    switch buttonNumber {
    case 0: GHOSTTY_MOUSE_LEFT
    case 1: GHOSTTY_MOUSE_RIGHT
    case 2: GHOSTTY_MOUSE_MIDDLE
    case 3: GHOSTTY_MOUSE_FOUR
    case 4: GHOSTTY_MOUSE_FIVE
    default: defaultLeft ? GHOSTTY_MOUSE_LEFT : GHOSTTY_MOUSE_UNKNOWN
    }
  }
}
