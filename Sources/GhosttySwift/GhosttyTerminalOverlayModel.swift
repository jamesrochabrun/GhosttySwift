import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class GhosttyTerminalOverlayModel {
  struct ChildExitBanner: Equatable {
    let title: String
    let subtitle: String
    let isError: Bool
  }

  private(set) var secureInputEnabled = false
  private(set) var searchState: GhosttySurfaceSearchState?
  var searchNeedle = ""
  private(set) var cellSize: CGSize = .zero
  private(set) var childExitBanner: ChildExitBanner?

  @ObservationIgnored private let controller: GhosttyTerminalController
  @ObservationIgnored private var isSyncingSearchNeedle = false
  @ObservationIgnored private var dismissChildExitWorkItem: DispatchWorkItem?
  @ObservationIgnored private var lastChildExitInfo: GhosttySurfaceChildExitInfo?

  init(controller: GhosttyTerminalController) {
    self.controller = controller
    sync(from: controller)
  }

  func sync(from controller: GhosttyTerminalController) {
    secureInputEnabled = controller.secureInputEnabled
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
