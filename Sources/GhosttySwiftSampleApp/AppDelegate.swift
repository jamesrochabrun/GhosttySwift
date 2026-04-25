import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var isObservingWindowUpdates = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    SampleTrace.write("app delegate did finish launching")
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    guard !isObservingWindowUpdates else { return }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowDidUpdate(_:)),
      name: NSWindow.didUpdateNotification,
      object: nil
    )
    isObservingWindowUpdates = true
  }

  @objc
  private func windowDidUpdate(_ note: Notification) {
    guard
      let window = note.object as? NSWindow,
      window.styleMask.contains(.titled),
      let screen = NSScreen.main
    else { return }

    let size = window.frame.size
    let centeredFrame = NSRect(
      x: screen.visibleFrame.midX - size.width / 2,
      y: screen.visibleFrame.midY - size.height / 2,
      width: size.width,
      height: size.height
    )

    if window.frame != centeredFrame {
      window.setFrame(centeredFrame, display: true)
    }

    if isObservingWindowUpdates {
      NotificationCenter.default.removeObserver(
        self,
        name: NSWindow.didUpdateNotification,
        object: nil
      )
    }
    isObservingWindowUpdates = false
  }

  func applicationWillTerminate(_ notification: Notification) {
    SampleTrace.write("app delegate will terminate")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
