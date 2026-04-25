import AppKit
import GhosttySwift
import SwiftUI

struct ContentView: View {
  @State private var bridge = GhosttySurfaceBridge()

  var body: some View {
    let _ = SampleTrace.write("content view body")
    return GhosttyTerminalView(
      configuration: GhosttySurfaceConfiguration(
        workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
      ),
      bridge: bridge
    )
    .frame(minWidth: 960, minHeight: 600)
  }
}
