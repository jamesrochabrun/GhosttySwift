import SwiftUI

@main
struct GhosttySwiftPermissiveSampleApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  init() {
    SampleTrace.reset()
    SampleTrace.write("app init")
  }

  var body: some Scene {
    let _ = SampleTrace.write("app body")
    return WindowGroup {
      ContentView()
    }
    .defaultSize(width: 960, height: 600)
    .defaultPosition(.center)
  }
}
