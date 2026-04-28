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
    HStack(spacing: 5) {
      Button(action: onSelect) {
        Text(displayName)
          .font(.caption2.weight(isSelected ? .medium : .regular))
          .lineLimit(1)
          .frame(minWidth: 76, maxWidth: 150, alignment: .leading)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if canClose {
        Button(action: onClose) {
          Label("Close Tab", systemImage: "xmark")
            .labelStyle(.iconOnly)
            .font(.system(size: 9, weight: .medium))
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close Tab")
      }
    }
    .frame(height: 24)
    .padding(.leading, 10)
    .padding(.trailing, canClose ? 7 : 10)
    .foregroundStyle(isSelected ? .primary : .secondary)
    .background {
      Rectangle()
        .fill(isSelected ? Color.primary.opacity(0.12) : Color.clear)
    }
    .overlay(alignment: .trailing) {
      Rectangle()
        .fill(Color.primary.opacity(0.14))
        .frame(width: 1)
    }
    .overlay(alignment: .bottom) {
      if isSelected {
        Rectangle()
          .fill(Color.accentColor.opacity(0.75))
          .frame(height: 2)
      }
    }
    .contentShape(Rectangle())
    .help(displayName)
    .zIndex(isSelected ? 1 : 0)
  }
}
