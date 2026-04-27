import SwiftUI

@MainActor
struct TerminalSurfacePaneView: View {
  let panel: TerminalPanel
  let isActive: Bool
  let showsPaneLabel: Bool
  let showsTabBar: Bool
  let canClosePanel: Bool
  let canCloseTab: (TerminalTab) -> Bool
  let onActivate: () -> Void
  let onClosePanel: () -> Void
  let onSelectTab: (TerminalTab) -> Void
  let onCloseTab: (TerminalTab) -> Void

  var body: some View {
    VStack(spacing: 0) {
      if showsPaneLabel {
        HStack(spacing: 8) {
          Text(panel.displayName)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          Spacer(minLength: 0)

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
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture(perform: onActivate)
      }

      if showsTabBar {
        TerminalTabStripView(
          panel: panel,
          canClosePanel: canClosePanel,
          canCloseTab: canCloseTab,
          onActivatePanel: onActivate,
          onClosePanel: onClosePanel,
          onSelectTab: onSelectTab,
          onCloseTab: onCloseTab
        )
      }

      if let activeTab = panel.activeTab {
        TerminalHostedContainerView(tab: activeTab)
          .id(activeTab.id)
          .onTapGesture(perform: onActivate)
      } else {
        Text("No tab available")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
    .overlay {
      if isActive {
        Rectangle()
          .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
      }
    }
  }
}
