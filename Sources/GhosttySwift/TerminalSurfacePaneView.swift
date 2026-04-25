import SwiftUI

@MainActor
struct TerminalSurfacePaneView: View {
  let terminal: TerminalSessionTerminal
  let showsPaneLabel: Bool
  let canClose: Bool
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      if showsPaneLabel {
        HStack(spacing: 8) {
          Text(terminal.displayName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Spacer(minLength: 0)

          if canClose {
            Button(action: onClose) {
              Label("Close Panel", systemImage: "xmark")
                .labelStyle(.iconOnly)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close Panel")
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
      }

      TerminalHostedContainerView(terminal: terminal)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}
