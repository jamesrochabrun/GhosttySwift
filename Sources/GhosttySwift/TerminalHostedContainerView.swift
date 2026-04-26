import AppKit
import SwiftUI

@MainActor
struct TerminalHostedContainerView: NSViewRepresentable {
  typealias NSViewType = GhosttyTerminalContainerView

  let tab: TerminalTab

  func makeNSView(context: Context) -> GhosttyTerminalContainerView {
    tab.containerView
  }

  func updateNSView(_ nsView: GhosttyTerminalContainerView, context: Context) {}
}
