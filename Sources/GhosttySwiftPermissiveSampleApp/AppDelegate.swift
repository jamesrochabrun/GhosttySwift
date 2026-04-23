import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowObserver: NSObjectProtocol?

  func applicationDidFinishLaunching(_ notification: Notification) {
    SampleTrace.write("app delegate did finish launching")
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    windowObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.didUpdateNotification,
      object: nil,
      queue: .main
    ) { [weak self] note in
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

      if let windowObserver = self?.windowObserver {
        NotificationCenter.default.removeObserver(windowObserver)
      }
      self?.windowObserver = nil
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    SampleTrace.write("app delegate will terminate")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}
