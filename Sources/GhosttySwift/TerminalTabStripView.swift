import SwiftUI

@MainActor
struct TerminalTabStripView: View {
  let panel: TerminalPanel
  let canClosePanel: Bool
  let canCloseTab: (TerminalTab) -> Bool
  let canOpenTab: Bool
  let onActivatePanel: () -> Void
  let onClosePanel: () -> Void
  let onSelectTab: (TerminalTab) -> Void
  let onCloseTab: (TerminalTab) -> Void
  let onOpenTab: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .center, spacing: 0) {
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
      }

      if canOpenTab {
        Button(action: onOpenTab) {
          Label("New Tab", systemImage: "plus")
            .labelStyle(.iconOnly)
            .font(.system(size: 12, weight: .regular))
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("New Tab")
      }

      if canClosePanel {
        Button(action: onClosePanel) {
          Label("Close Panel", systemImage: "xmark")
            .labelStyle(.iconOnly)
            .font(.system(size: 10, weight: .medium))
            .frame(width: 28, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Close Panel")
      }
    }
    .frame(height: 24)
    .background {
      ZStack(alignment: .bottom) {
        Rectangle()
          .fill(Color.primary.opacity(0.055))
        Rectangle()
          .fill(Color.primary.opacity(0.16))
          .frame(height: 1)
      }
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: onActivatePanel)
  }
}
