import AppKit
import SwiftUI

@MainActor
struct TerminalHostedContainerView: NSViewRepresentable {
  typealias NSViewType = GhosttyTerminalContainerView

  let terminal: TerminalSessionTerminal

  func makeNSView(context: Context) -> GhosttyTerminalContainerView {
    terminal.containerView
  }

  func updateNSView(_ nsView: GhosttyTerminalContainerView, context: Context) {}
}
