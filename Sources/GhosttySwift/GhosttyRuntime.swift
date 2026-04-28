import AppKit
import Foundation
import GhosttyKit

// Runtime behavior is re-authored against upstream Ghostty MIT sources,
// primarily macos/Sources/Ghostty/Ghostty.App.swift plus ghostty.h.
@MainActor
public final class GhosttyRuntime {
  public enum RuntimeError: LocalizedError {
    case resourcesDirectoryUnavailable
    case ghosttyInitFailed(Int32)
    case configCreationFailed
    case appCreationFailed

    public var errorDescription: String? {
      switch self {
      case .resourcesDirectoryUnavailable:
        return "Unable to locate bundled Ghostty resources."
      case .ghosttyInitFailed(let code):
        return "ghostty_init failed with code \(code)."
      case .configCreationFailed:
        return "ghostty_config_new returned nil."
      case .appCreationFailed:
        return "ghostty_app_new returned nil."
      }
    }
  }

  static let resourcesEnvironmentKey = "GHOSTTY_RESOURCES_DIR"
  private static let initResult: Int32 = Int32(ghostty_init(UInt(CommandLine.argc), CommandLine.unsafeArgv))

  private var configHandle: ghostty_config_t?
  private var appHandleStorage: ghostty_app_t?
  private var isObservingApplicationNotifications = false

  var appHandle: ghostty_app_t {
    guard let appHandleStorage else {
      fatalError("Ghostty runtime used before appHandle was initialized.")
    }

    return appHandleStorage
  }

  public init(configPath: String? = nil) throws {
    self.configHandle = nil
    self.appHandleStorage = nil

    try Self.configureBundledResources()
    try Self.ensureGhosttyInitialized()

    var runtimeConfig = ghostty_runtime_config_s(
      userdata: Unmanaged.passUnretained(self).toOpaque(),
      supports_selection_clipboard: true,
      wakeup_cb: { @Sendable userdata in ghosttyRuntimeWakeup(userdata) },
      action_cb: { @Sendable app, target, action in
        ghosttyRuntimeAction(app, target, action)
      },
      read_clipboard_cb: { @Sendable userdata, location, request in
        ghosttyRuntimeReadClipboard(userdata, location, request)
      },
      confirm_read_clipboard_cb: { @Sendable userdata, string, request, requestType in
        ghosttyRuntimeConfirmReadClipboard(userdata, string, request, requestType)
      },
      write_clipboard_cb: { @Sendable userdata, location, content, contentCount, shouldConfirm in
        ghosttyRuntimeWriteClipboard(userdata, location, content, contentCount, shouldConfirm)
      },
      close_surface_cb: { @Sendable userdata, processAlive in
        ghosttyRuntimeCloseSurface(userdata, processAlive)
      }
    )

    guard let config = Self.loadConfig(configPath: configPath) else {
      throw RuntimeError.configCreationFailed
    }
    guard let app = ghostty_app_new(&runtimeConfig, config) else {
      ghostty_config_free(config)
      throw RuntimeError.appCreationFailed
    }

    self.configHandle = config
    self.appHandleStorage = app

    installApplicationObservers()
    ghostty_app_set_focus(app, NSApp?.isActive == true)
  }

  isolated deinit {
    if isObservingApplicationNotifications {
      NotificationCenter.default.removeObserver(self)
    }
    if let appHandleStorage {
      ghostty_app_free(appHandleStorage)
    }
    if let configHandle {
      ghostty_config_free(configHandle)
    }
  }

  public func tick() {
    guard let appHandleStorage else { return }
    ghostty_app_tick(appHandleStorage)
  }

  private func installApplicationObservers() {
    guard !isObservingApplicationNotifications else { return }

    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(keyboardSelectionDidChange(notification:)),
      name: NSTextInputContext.keyboardSelectionDidChangeNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive(notification:)),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(applicationDidResignActive(notification:)),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )

    isObservingApplicationNotifications = true
  }

  @objc
  private func keyboardSelectionDidChange(notification: NSNotification) {
    guard let appHandleStorage else { return }
    ghostty_app_keyboard_changed(appHandleStorage)
  }

  @objc
  private func applicationDidBecomeActive(notification: NSNotification) {
    guard let appHandleStorage else { return }
    ghostty_app_set_focus(appHandleStorage, true)
  }

  @objc
  private func applicationDidResignActive(notification: NSNotification) {
    guard let appHandleStorage else { return }
    ghostty_app_set_focus(appHandleStorage, false)
  }

  private static func loadConfig(configPath: String?) -> ghostty_config_t? {
    guard let config = ghostty_config_new() else {
      return nil
    }

    #if os(macOS)
    if let configPath {
      ghostty_config_load_file(config, configPath)
    } else {
      ghostty_config_load_default_files(config)
    }

    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
      ghostty_config_load_cli_args(config)
    }

    ghostty_config_load_recursive_files(config)
    #endif

    ghostty_config_finalize(config)
    return config
  }

  private static func ensureGhosttyInitialized() throws {
    guard Self.initResult == GHOSTTY_SUCCESS else {
      throw RuntimeError.ghosttyInitFailed(Self.initResult)
    }
  }

  private static func configureBundledResources() throws {
    if ProcessInfo.processInfo.environment[Self.resourcesEnvironmentKey] != nil {
      return
    }

    guard
      let resourceURL = Bundle.module.resourceURL?
        .appendingPathComponent("share", isDirectory: true)
        .appendingPathComponent("ghostty", isDirectory: true),
      FileManager.default.fileExists(atPath: resourceURL.path)
    else {
      throw RuntimeError.resourcesDirectoryUnavailable
    }

    setenv(Self.resourcesEnvironmentKey, resourceURL.path, 1)
  }

  nonisolated fileprivate static func handleWakeup(_ userdata: UnsafeMutableRawPointer?) {
    let userdataBits = userdata.map { UInt(bitPattern: $0) }
    if Thread.isMainThread {
      MainActor.assumeIsolated {
        wakeup(userdataBits: userdataBits)
      }
      return
    }

    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        wakeup(userdataBits: userdataBits)
      }
    }
  }

  nonisolated fileprivate static func handleAction(
    _ app: ghostty_app_t?,
    _ target: ghostty_target_s,
    _ action: ghostty_action_s
  ) -> Bool {
    guard let app else { return false }
    let appBits = UInt(bitPattern: app)

    if Thread.isMainThread {
      return MainActor.assumeIsolated {
        actionOnMain(appBits: appBits, target: target, action: action)
      }
    }

    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        _ = actionOnMain(appBits: appBits, target: target, action: action)
      }
    }

    return false
  }

  nonisolated fileprivate static func handleCloseSurface(
    _ userdata: UnsafeMutableRawPointer?,
    _ processAlive: Bool
  ) {
    let userdataBits = userdata.map { UInt(bitPattern: $0) }
    if Thread.isMainThread {
      MainActor.assumeIsolated {
        closeSurface(userdataBits: userdataBits, processAlive: processAlive)
      }
      return
    }

    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        closeSurface(userdataBits: userdataBits, processAlive: processAlive)
      }
    }
  }

  private static func wakeup(userdataBits: UInt?) {
    let userdata = userdataBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }
    guard let runtime = userdata.flatMap(runtime(from:)) else { return }
    runtime.tick()
  }

  private static func actionOnMain(
    appBits: UInt,
    target: ghostty_target_s,
    action: ghostty_action_s
  ) -> Bool {
    GhosttyTrace.write(
      "runtime handleAction target=\(targetDescription(target.tag)) action=\(actionDescription(action.tag))"
    )

    _ = appBits

    guard target.tag == GHOSTTY_TARGET_SURFACE else {
      return false
    }

    switch action.tag {
    default:
      guard let bridgePointer = ghostty_surface_userdata(target.target.surface) else { return false }
      guard let bridge = bridge(from: bridgePointer) else { return false }
      return bridge.handleAction(action)
    }
  }

  nonisolated fileprivate static func runtime(from userdata: UnsafeMutableRawPointer) -> GhosttyRuntime? {
    Unmanaged<GhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
  }

  nonisolated fileprivate static func bridge(from userdata: UnsafeMutableRawPointer?) -> GhosttySurfaceBridge? {
    guard let userdata else { return nil }
    return Unmanaged<GhosttySurfaceBridge>.fromOpaque(userdata).takeUnretainedValue()
  }

  private static func closeSurface(userdataBits: UInt?, processAlive: Bool) {
    let userdata = userdataBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }
    guard let bridge = bridge(from: userdata) else { return }
    bridge.closeSurface(processAlive: processAlive)
  }
}

private func targetDescription(_ tag: ghostty_target_tag_e) -> String {
  switch tag {
  case GHOSTTY_TARGET_APP:
    return "app"
  case GHOSTTY_TARGET_SURFACE:
    return "surface"
  default:
    return "unknown(\(tag.rawValue))"
  }
}

private func actionDescription(_ tag: ghostty_action_tag_e) -> String {
  switch tag {
  case GHOSTTY_ACTION_SET_TITLE:
    return "set_title"
  case GHOSTTY_ACTION_MOUSE_SHAPE:
    return "mouse_shape"
  case GHOSTTY_ACTION_CELL_SIZE:
    return "cell_size"
  case GHOSTTY_ACTION_SIZE_LIMIT:
    return "size_limit"
  case GHOSTTY_ACTION_CLOSE_WINDOW:
    return "close_window"
  case GHOSTTY_ACTION_PROGRESS_REPORT:
    return "progress_report"
  case GHOSTTY_ACTION_DESKTOP_NOTIFICATION:
    return "desktop_notification"
  case GHOSTTY_ACTION_PWD:
    return "pwd"
  case GHOSTTY_ACTION_SECURE_INPUT:
    return "secure_input"
  case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
    return "show_child_exited"
  default:
    return "tag(\(tag.rawValue))"
  }
}

private func ghosttyRuntimeWakeup(_ userdata: UnsafeMutableRawPointer?) {
  GhosttyRuntime.handleWakeup(userdata)
}

private func ghosttyRuntimeAction(
  _ app: ghostty_app_t?,
  _ target: ghostty_target_s,
  _ action: ghostty_action_s
) -> Bool {
  GhosttyRuntime.handleAction(app, target, action)
}

private func ghosttyRuntimeReadClipboard(
  _ userdata: UnsafeMutableRawPointer?,
  _ location: ghostty_clipboard_e,
  _ request: UnsafeMutableRawPointer?
) -> Bool {
  let userdataBits = userdata.map { UInt(bitPattern: $0) }
  let requestBits = request.map { UInt(bitPattern: $0) }

  if Thread.isMainThread {
    return MainActor.assumeIsolated {
      completeClipboardRead(userdataBits: userdataBits, location: location, requestBits: requestBits)
    }
  }

  return DispatchQueue.main.sync {
    MainActor.assumeIsolated {
      completeClipboardRead(userdataBits: userdataBits, location: location, requestBits: requestBits)
    }
  }
}

private func ghosttyRuntimeConfirmReadClipboard(
  _ userdata: UnsafeMutableRawPointer?,
  _ string: UnsafePointer<CChar>?,
  _ request: UnsafeMutableRawPointer?,
  _ requestType: ghostty_clipboard_request_e
) {
  guard let string else { return }

  let value = String(cString: string)
  let userdataBits = userdata.map { UInt(bitPattern: $0) }
  let requestBits = request.map { UInt(bitPattern: $0) }

  if Thread.isMainThread {
    MainActor.assumeIsolated {
      completeConfirmedClipboardRead(
        userdataBits: userdataBits,
        value: value,
        requestBits: requestBits,
        requestType: requestType
      )
    }
    return
  }

  DispatchQueue.main.async {
    MainActor.assumeIsolated {
      completeConfirmedClipboardRead(
        userdataBits: userdataBits,
        value: value,
        requestBits: requestBits,
        requestType: requestType
      )
    }
  }
}

private func ghosttyRuntimeWriteClipboard(
  _ userdata: UnsafeMutableRawPointer?,
  _ location: ghostty_clipboard_e,
  _ content: UnsafePointer<ghostty_clipboard_content_s>?,
  _ contentCount: Int,
  _ shouldConfirm: Bool
) {
  _ = userdata
  guard let content, contentCount > 0 else { return }

  let items: [(mime: String, data: String)] = (0..<contentCount).compactMap { index in
    let item = content.advanced(by: index).pointee
    guard let mimePointer = item.mime, let dataPointer = item.data else { return nil }
    return (mime: String(cString: mimePointer), data: String(cString: dataPointer))
  }

  guard !items.isEmpty else { return }

  if Thread.isMainThread {
    MainActor.assumeIsolated {
      writeClipboard(location: location, items: items, shouldConfirm: shouldConfirm)
    }
    return
  }

  DispatchQueue.main.async {
    MainActor.assumeIsolated {
      writeClipboard(location: location, items: items, shouldConfirm: shouldConfirm)
    }
  }
}

private func ghosttyRuntimeCloseSurface(
  _ userdata: UnsafeMutableRawPointer?,
  _ processAlive: Bool
) {
  GhosttyRuntime.handleCloseSurface(userdata, processAlive)
}

@MainActor
private func completeClipboardRead(
  userdataBits: UInt?,
  location: ghostty_clipboard_e,
  requestBits: UInt?
) -> Bool {
  let userdata = userdataBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }
  let request = requestBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }

  guard
    let bridge = GhosttyRuntime.bridge(from: userdata),
    let surface = bridge.surfaceView?.surfaceHandle,
    let value = NSPasteboard.ghostty(location)?.getOpinionatedStringContents()
  else {
    return false
  }

  value.withCString { pointer in
    ghostty_surface_complete_clipboard_request(surface, pointer, request, false)
  }

  return true
}

@MainActor
private func completeConfirmedClipboardRead(
  userdataBits: UInt?,
  value: String,
  requestBits: UInt?,
  requestType: ghostty_clipboard_request_e
) {
  _ = requestType

  let userdata = userdataBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }
  let request = requestBits.flatMap { UnsafeMutableRawPointer(bitPattern: $0) }

  guard
    let bridge = GhosttyRuntime.bridge(from: userdata),
    let surface = bridge.surfaceView?.surfaceHandle
  else {
    return
  }

  value.withCString { pointer in
    ghostty_surface_complete_clipboard_request(surface, pointer, request, true)
  }
}

@MainActor
private func writeClipboard(
  location: ghostty_clipboard_e,
  items: [(mime: String, data: String)],
  shouldConfirm: Bool
) {
  _ = shouldConfirm

  guard let pasteboard = NSPasteboard.ghostty(location) else { return }

  let types = items.compactMap { NSPasteboard.PasteboardType(mimeType: $0.mime) }
  pasteboard.declareTypes(types, owner: nil)

  for item in items {
    guard let type = NSPasteboard.PasteboardType(mimeType: item.mime) else { continue }
    pasteboard.setString(item.data, forType: type)
  }
}
