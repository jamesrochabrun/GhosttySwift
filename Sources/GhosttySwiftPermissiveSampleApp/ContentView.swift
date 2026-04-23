import AppKit
import GhosttySwiftPermissive
import SwiftUI

struct ContentView: View {
  @State private var runtime: GhosttyRuntime?
  @State private var bridge = GhosttySurfaceBridge()
  @State private var errorMessage: String?
  @State private var isStarting = false

  var body: some View {
    let _ = SampleTrace.write("content view body runtime=\(runtime != nil)")
    return ZStack {
      if let runtime {
        GhosttyTerminalView(
          runtime: runtime,
          configuration: GhosttySurfaceConfiguration(
            workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
          ),
          bridge: bridge
        )
      } else if let errorMessage {
        Text(errorMessage)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(24)
      } else {
        ProgressView("Starting…")
          .controlSize(.large)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 960, minHeight: 600)
    .task {
      guard runtime == nil, errorMessage == nil, !isStarting else { return }
      isStarting = true
      SampleTrace.write("content view task start")

      do {
        runtime = try GhosttyRuntime()
        SampleTrace.write("content view task runtime ready")
      } catch {
        errorMessage = error.localizedDescription
        SampleTrace.write("content view task error: \(error.localizedDescription)")
      }

      isStarting = false
    }
  }
}
