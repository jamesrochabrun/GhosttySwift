import AppKit
import Combine
import SwiftUI

@MainActor
final class GhosttyTerminalOverlayModel: ObservableObject {
  struct ChildExitBanner: Equatable {
    let title: String
    let subtitle: String
    let isError: Bool
  }

  @Published private(set) var secureInputEnabled = false
  @Published private(set) var searchState: GhosttySurfaceSearchState?
  @Published var searchNeedle = ""
  @Published private(set) var scrollbar: GhosttySurfaceScrollbarState?
  @Published private(set) var cellSize: CGSize = .zero
  @Published private(set) var childExitBanner: ChildExitBanner?

  private let controller: GhosttyTerminalController
  private var isSyncingSearchNeedle = false
  private var dismissChildExitWorkItem: DispatchWorkItem?
  private var lastChildExitInfo: GhosttySurfaceChildExitInfo?

  init(controller: GhosttyTerminalController) {
    self.controller = controller
    sync(from: controller)
  }

  func sync(from controller: GhosttyTerminalController) {
    secureInputEnabled = controller.secureInputEnabled
    scrollbar = controller.scrollbar
    cellSize = controller.cellSize
    searchState = controller.searchState

    if controller.searchState == nil {
      isSyncingSearchNeedle = true
      searchNeedle = ""
      isSyncingSearchNeedle = false
    } else if
      let needle = controller.searchState?.needle,
      !needle.isEmpty,
      searchNeedle != needle
    {
      isSyncingSearchNeedle = true
      searchNeedle = needle
      isSyncingSearchNeedle = false
    }

    updateChildExitBanner(for: controller.childExitInfo)
  }

  var searchTextBinding: Binding<String> {
    Binding(
      get: { self.searchNeedle },
      set: { [weak self] newValue in
        self?.setSearchNeedle(newValue)
      }
    )
  }

  func setSearchNeedle(_ needle: String) {
    searchNeedle = needle
    guard !isSyncingSearchNeedle else { return }
    _ = controller.setSearchNeedle(needle)
  }

  func closeSearch() {
    _ = controller.endSearch()
    controller.focusTerminal()
  }

  func navigateSearchNext() {
    _ = controller.navigateSearchNext()
  }

  func navigateSearchPrevious() {
    _ = controller.navigateSearchPrevious()
  }

  func scroll(trackHeight: CGFloat, thumbHeight: CGFloat, locationY: CGFloat) {
    guard
      let scrollbar,
      scrollbar.total > scrollbar.length,
      trackHeight > thumbHeight
    else {
      return
    }

    let maxOffset = Int(scrollbar.total - scrollbar.length)
    let clampedY = min(max(locationY - (thumbHeight / 2), 0), trackHeight - thumbHeight)
    let progress = clampedY / (trackHeight - thumbHeight)
    let row = Int(progress * CGFloat(maxOffset))
    _ = controller.scrollToRow(row)
  }

  func dismissChildExitBanner() {
    dismissChildExitWorkItem?.cancel()
    childExitBanner = nil
  }

  private func updateChildExitBanner(for info: GhosttySurfaceChildExitInfo?) {
    guard lastChildExitInfo != info else { return }
    lastChildExitInfo = info
    dismissChildExitWorkItem?.cancel()

    guard let info else {
      childExitBanner = nil
      return
    }

    childExitBanner = Self.makeChildExitBanner(from: info)
    let workItem = DispatchWorkItem { [weak self] in
      self?.childExitBanner = nil
    }
    dismissChildExitWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
  }

  nonisolated static func makeChildExitBanner(from info: GhosttySurfaceChildExitInfo) -> ChildExitBanner {
    let seconds = Double(info.runtimeMilliseconds) / 1000
    let subtitle = String(format: "Exit code %u after %.1fs", info.exitCode, seconds)
    if info.exitCode == 0 {
      return ChildExitBanner(
        title: "Process completed",
        subtitle: subtitle,
        isError: false
      )
    }

    return ChildExitBanner(
      title: "Process exited",
      subtitle: subtitle,
      isError: true
    )
  }
}
