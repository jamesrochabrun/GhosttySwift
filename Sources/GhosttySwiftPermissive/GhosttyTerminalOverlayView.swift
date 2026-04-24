import AppKit
import SwiftUI

struct GhosttyTerminalSearchOverlayHostView: View {
  @ObservedObject var model: GhosttyTerminalOverlayModel

  var body: some View {
    Group {
      if let searchState = model.searchState {
        GhosttyTerminalSearchOverlay(
          model: model,
          searchState: searchState
        )
      }
    }
  }
}

struct GhosttyTerminalSecureInputBadgeHostView: View {
  @ObservedObject var model: GhosttyTerminalOverlayModel

  var body: some View {
    Group {
      if model.secureInputEnabled {
        GhosttyTerminalSecureInputBadge()
      }
    }
  }
}

struct GhosttyTerminalChildExitBannerHostView: View {
  @ObservedObject var model: GhosttyTerminalOverlayModel

  var body: some View {
    Group {
      if let childExitBanner = model.childExitBanner {
        GhosttyTerminalChildExitBanner(
          banner: childExitBanner,
          onDismiss: model.dismissChildExitBanner
        )
      }
    }
  }
}

private struct GhosttyTerminalSearchOverlay: View {
  @ObservedObject var model: GhosttyTerminalOverlayModel
  let searchState: GhosttySurfaceSearchState

  @FocusState private var isSearchFieldFocused: Bool

  var body: some View {
    HStack(spacing: 6) {
      TextField("Search", text: model.searchTextBinding)
        .textFieldStyle(.plain)
        .frame(width: 180)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .focused($isSearchFieldFocused)
        .overlay(alignment: .trailing) {
          searchCountLabel
            .padding(.trailing, 10)
        }
        .onSubmit {
          model.navigateSearchNext()
        }

      GhosttyTerminalOverlayButton(systemName: "chevron.up") {
        model.navigateSearchNext()
      }

      GhosttyTerminalOverlayButton(systemName: "chevron.down") {
        model.navigateSearchPrevious()
      }

      GhosttyTerminalOverlayButton(systemName: "xmark") {
        model.closeSearch()
      }
    }
    .padding(8)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .shadow(color: Color.black.opacity(0.14), radius: 8, y: 2)
    .onAppear {
      isSearchFieldFocused = true
    }
  }

  @ViewBuilder
  private var searchCountLabel: some View {
    if let selected = searchState.selected {
      Text("\(selected + 1)/\(searchState.total ?? 0)")
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    } else if let total = searchState.total {
      Text("-/\(total)")
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
  }
}

private struct GhosttyTerminalSecureInputBadge: View {
  var body: some View {
    Label("Secure Input", systemImage: "lock.shield.fill")
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 7)
      .background(.regularMaterial)
      .clipShape(Capsule())
      .overlay {
        Capsule()
          .stroke(Color.primary.opacity(0.08), lineWidth: 1)
      }
      .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
  }
}

private struct GhosttyTerminalChildExitBanner: View {
  let banner: GhosttyTerminalOverlayModel.ChildExitBanner
  let onDismiss: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: banner.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .foregroundStyle(banner.isError ? Color.orange : Color.green)

      VStack(alignment: .leading, spacing: 2) {
        Text(banner.title)
          .font(.subheadline.weight(.semibold))
        Text(banner.subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer(minLength: 0)

      GhosttyTerminalOverlayButton(systemName: "xmark") {
        onDismiss()
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
    }
    .shadow(color: Color.black.opacity(0.14), radius: 8, y: 2)
  }
}

private struct GhosttyTerminalOverlayButton: View {
  let systemName: String
  let action: () -> Void
  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .font(.system(size: 11, weight: .semibold))
        .frame(width: 30, height: 30)
        .background(Color.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      guard hovering != isHovering else { return }
      isHovering = hovering
      if hovering {
        NSCursor.pointingHand.push()
      } else {
        NSCursor.pop()
      }
    }
  }
}
