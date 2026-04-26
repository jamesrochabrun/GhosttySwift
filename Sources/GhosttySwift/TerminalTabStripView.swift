import SwiftUI

@MainActor
struct TerminalTabStripView: View {
  let panel: TerminalPanel
  let canClosePanel: Bool
  let canCloseTab: (TerminalTab) -> Bool
  let onActivatePanel: () -> Void
  let onClosePanel: () -> Void
  let onSelectTab: (TerminalTab) -> Void
  let onCloseTab: (TerminalTab) -> Void

  var body: some View {
    HStack(alignment: .bottom, spacing: 6) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .bottom, spacing: 2) {
          ForEach(Array(panel.tabs.enumerated()), id: \.element.id) { index, tab in
            TerminalTabStripItemView(
              tab: tab,
              displayName: tab.displayName(index: index),
              isSelected: tab.id == panel.activeTabID,
              canClose: canCloseTab(tab),
              onSelect: { onSelectTab(tab) },
              onClose: { onCloseTab(tab) }
            )
          }
        }
        .padding(.leading, 8)
        .padding(.top, 6)
      }

      if canClosePanel {
        Button(action: onClosePanel) {
          Label("Close Panel", systemImage: "xmark")
            .labelStyle(.iconOnly)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close Panel")
        .padding(.trailing, 8)
      }
    }
    .background {
      ZStack(alignment: .bottom) {
        Rectangle()
          .fill(.bar)
        Rectangle()
          .fill(Color.primary.opacity(0.12))
          .frame(height: 1)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onActivatePanel)
  }
}
