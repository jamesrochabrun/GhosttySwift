import SwiftUI

@MainActor
struct TerminalTabStripItemView: View {
  let tab: TerminalTab
  let displayName: String
  let isSelected: Bool
  let canClose: Bool
  let onSelect: () -> Void
  let onClose: () -> Void

  var body: some View {
    HStack(spacing: 6) {
      Button(action: onSelect) {
        Text(displayName)
          .font(.callout)
          .lineLimit(1)
          .frame(maxWidth: 160, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if canClose {
        Button(action: onClose) {
          Label("Close Tab", systemImage: "xmark")
            .labelStyle(.iconOnly)
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close Tab")
      }
    }
    .padding(.leading, 12)
    .padding(.trailing, canClose ? 6 : 12)
    .padding(.top, 7)
    .padding(.bottom, 6)
    .foregroundStyle(isSelected ? .primary : .secondary)
    .background {
      TerminalTabShape(cornerRadius: 8)
        .fill(isSelected ? Color(nsColor: .windowBackgroundColor) : Color.primary.opacity(0.045))
    }
    .overlay {
      TerminalTabShape(cornerRadius: 8)
        .stroke(isSelected ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
    }
    .overlay(alignment: .bottom) {
      if isSelected {
        Rectangle()
          .fill(Color(nsColor: .windowBackgroundColor))
          .frame(height: 1)
      }
    }
    .contentShape(TerminalTabShape(cornerRadius: 8))
    .help(displayName)
    .zIndex(isSelected ? 1 : 0)
  }
}
