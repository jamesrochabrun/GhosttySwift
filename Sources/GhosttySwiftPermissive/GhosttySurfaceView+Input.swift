import AppKit
import GhosttyKit

extension GhosttySurfaceView {
  override public func becomeFirstResponder() -> Bool {
    let accepted = super.becomeFirstResponder()
    if accepted, let surfaceHandle {
      ghostty_surface_set_focus(surfaceHandle, true)
    }
    return accepted
  }

  override public func resignFirstResponder() -> Bool {
    let accepted = super.resignFirstResponder()
    if accepted, let surfaceHandle {
      ghostty_surface_set_focus(surfaceHandle, false)
    }
    return accepted
  }

  override public func updateTrackingAreas() {
    super.updateTrackingAreas()
    installTrackingAreaIfNeeded()
  }

  override public func keyDown(with event: NSEvent) {
    guard let surfaceHandle else {
      super.keyDown(with: event)
      return
    }

    sendKey(
      event,
      action: event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS,
      to: surfaceHandle
    )
  }

  override public func keyUp(with event: NSEvent) {
    guard let surfaceHandle else {
      super.keyUp(with: event)
      return
    }

    sendKey(event, action: GHOSTTY_ACTION_RELEASE, to: surfaceHandle)
  }

  override public func flagsChanged(with event: NSEvent) {
    guard let surfaceHandle else {
      super.flagsChanged(with: event)
      return
    }

    guard let payload = GhosttyKeyMap.modifierEventPayload(
      keyCode: event.keyCode,
      modifierFlags: event.modifierFlags.rawValue
    ) else {
      super.flagsChanged(with: event)
      return
    }

    sendKeyPayload(payload, to: surfaceHandle)
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
      rect: bounds,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
  }

  private func sendKey(
    _ event: NSEvent,
    action: ghostty_input_action_e,
    to surface: ghostty_surface_t
  ) {
    let mods = GhosttyKeyMap.mods(from: event.modifierFlags.rawValue)
    let translatedMods = ghostty_surface_key_translation_mods(surface, mods)
    let translatedModifierFlags = resolvedTranslationModifierFlags(
      from: event.modifierFlags,
      translatedMods: translatedMods
    )
    let payload = GhosttyKeyMap.keyEventPayload(
      keyCode: event.keyCode,
      modifierFlags: event.modifierFlags.rawValue,
      characters: ghosttyCharacters(for: event, translationModifiers: translatedModifierFlags),
      charactersIgnoringModifiers: event.characters(byApplyingModifiers: []),
      action: action,
      consumedModifierFlags: translatedModifierFlags
        .subtracting(NSEvent.ModifierFlags(arrayLiteral: .control, .command))
        .rawValue
    )
    sendKeyPayload(payload, to: surface)
  }

  private func sendKeyPayload(_ payload: GhosttyKeyEventPayload, to surface: ghostty_surface_t) {
    if let text = payload.text {
      text.withCString { textPointer in
        sendKeyPayload(payload, textPointer: textPointer, to: surface)
      }
    } else {
      sendKeyPayload(payload, textPointer: nil, to: surface)
    }
  }

  private func sendKeyPayload(
    _ payload: GhosttyKeyEventPayload,
    textPointer: UnsafePointer<CChar>?,
    to surface: ghostty_surface_t
  ) {
    var input = ghostty_input_key_s()
    input.action = payload.action
    input.mods = payload.mods
    input.consumed_mods = payload.consumedMods
    input.keycode = payload.keycode

    if let text = payload.text,
      let firstByte = text.utf8.first,
      firstByte >= 0x20
    {
      input.text = textPointer
    } else {
      input.text = nil
    }

    input.unshifted_codepoint = payload.unshiftedCodepoint
    input.composing = payload.composing
    _ = ghostty_surface_key(surface, input)
  }

  private func resolvedTranslationModifierFlags(
    from original: NSEvent.ModifierFlags,
    translatedMods: ghostty_input_mods_e
  ) -> NSEvent.ModifierFlags {
    let translated = GhosttyKeyMap.eventModifierFlags(from: translatedMods)
    var result = original

    for flag in [NSEvent.ModifierFlags.shift, .control, .option, .command] {
      if translated.contains(flag) {
        result.insert(flag)
      } else {
        result.remove(flag)
      }
    }

    return result
  }

  private func ghosttyCharacters(
    for event: NSEvent,
    translationModifiers: NSEvent.ModifierFlags
  ) -> String? {
    let characters = event.characters(byApplyingModifiers: translationModifiers) ?? event.characters
    guard let characters else { return nil }

    if characters.count == 1, let scalar = characters.unicodeScalars.first {
      if scalar.value < 0x20 {
        return event.characters(byApplyingModifiers: translationModifiers.subtracting(.control))
      }

      if scalar.value >= 0xF700 && scalar.value <= 0xF8FF {
        return nil
      }
    }

    return characters
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
    let mods = GhosttyKeyMap.mods(from: event.modifierFlags.rawValue)
    _ = ghostty_surface_mouse_button(surfaceHandle, mouseState, button, mods)
  }

  private func sendMousePos(_ event: NSEvent) {
    let localPoint = convert(event.locationInWindow, from: nil)
    let viewportPoint = GhosttyMouseMap.viewportPoint(for: localPoint, height: bounds.height)
    sendMousePos(viewportPoint, modifierFlags: event.modifierFlags)
  }

  private func sendMousePos(_ point: CGPoint, modifierFlags: NSEvent.ModifierFlags) {
    guard let surfaceHandle else { return }
    let mods = GhosttyKeyMap.mods(from: modifierFlags.rawValue)
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
