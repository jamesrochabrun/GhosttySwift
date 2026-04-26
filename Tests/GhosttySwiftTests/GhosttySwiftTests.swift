import Testing
import GhosttyKit
@testable import GhosttySwift

@Test
func surfaceConfigurationDefaultsAreEmpty() {
  let configuration = GhosttySurfaceConfiguration()

  #expect(configuration.workingDirectory == nil)
  #expect(configuration.command == nil)
  #expect(configuration.initialInput == nil)
  #expect(configuration.fontSize == 0)
}

@MainActor
@Test
func terminalViewCanBeConstructedWithoutSupplyingRuntime() {
  let view = GhosttyTerminalView(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    )
  )

  #expect(String(describing: type(of: view)).contains("GhosttyTerminalView"))
}

@MainActor
@Test
func terminalViewCanBeConstructedFromController() throws {
  let controller = try GhosttyTerminalController(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    )
  )
  let view = GhosttyTerminalView(controller: controller)

  #expect(controller.title == "Ghostty")
  #expect(String(describing: type(of: view)).contains("GhosttyTerminalView"))
}

@Test
func childExitBannerFormatsSuccessAndFailure() {
  let success = GhosttyTerminalOverlayModel.makeChildExitBanner(
    from: GhosttySurfaceChildExitInfo(exitCode: 0, runtimeMilliseconds: 1234)
  )
  let failure = GhosttyTerminalOverlayModel.makeChildExitBanner(
    from: GhosttySurfaceChildExitInfo(exitCode: 7, runtimeMilliseconds: 2500)
  )

  #expect(success.title == "Process completed")
  #expect(success.isError == false)
  #expect(success.subtitle.contains("1.2s"))

  #expect(failure.title == "Process exited")
  #expect(failure.isError == true)
  #expect(failure.subtitle.contains("Exit code 7"))
}

@MainActor
@Test
func emptyStartSearchDoesNotClearExistingNeedle() {
  let bridge = GhosttySurfaceBridge()

  "abc".withCString { pointer in
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_START_SEARCH
    action.action.start_search = ghostty_action_start_search_s(needle: pointer)
    #expect(bridge.handleAction(action))
  }

  #expect(bridge.searchState?.needle == "abc")

  "".withCString { pointer in
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_START_SEARCH
    action.action.start_search = ghostty_action_start_search_s(needle: pointer)
    #expect(bridge.handleAction(action))
  }

  #expect(bridge.searchState?.needle == "abc")
}

@MainActor
@Test
func overlayModelPreservesLocalNeedleAcrossSearchCountUpdates() throws {
  let bridge = GhosttySurfaceBridge()
  let controller = try GhosttyTerminalController(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    ),
    bridge: bridge
  )
  let model = GhosttyTerminalOverlayModel(controller: controller)

  "".withCString { pointer in
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_START_SEARCH
    action.action.start_search = ghostty_action_start_search_s(needle: pointer)
    #expect(bridge.handleAction(action))
  }

  model.setSearchNeedle("hello")

  var searchTotal = ghostty_action_s()
  searchTotal.tag = GHOSTTY_ACTION_SEARCH_TOTAL
  searchTotal.action.search_total = ghostty_action_search_total_s(total: 14)
  #expect(bridge.handleAction(searchTotal))

  model.sync(from: controller)

  #expect(model.searchNeedle == "hello")
}

@MainActor
@Test
func nativeScrollHostCalculatesDocumentHeightFromScrollback() {
  let height = GhosttySurfaceScrollView.documentHeight(
    contentHeight: 320,
    cellHeight: 16,
    scrollbar: GhosttySurfaceScrollbarState(total: 100, offset: 20, length: 20)
  )

  #expect(height == 1600)
}

@MainActor
@Test
func nativeScrollHostCalculatesRowFromLiveScrollPosition() {
  let row = GhosttySurfaceScrollView.rowForLiveScroll(
    documentHeight: 1600,
    visibleOriginY: 960,
    visibleHeight: 320,
    cellHeight: 16
  )

  #expect(row == 20)
}

@Test
func splitLayoutNormalizationKeepsPrimaryFirstAndRemovesDuplicates() {
  let primary = TerminalPanelID()
  let helper = TerminalPanelID()
  let ignored = TerminalPanelID()

  let layout = TerminalSplitLayout.normalized(
    axis: .horizontal,
    panelIDs: [helper, helper, ignored],
    availablePanelIDs: [primary, helper],
    primaryPanelID: primary
  )

  #expect(layout?.axis == .horizontal)
  #expect(layout?.panelIDs == [primary, helper])
}

@Test
func splitLayoutNormalizationReturnsNilWithoutTwoKnownPanels() {
  let primary = TerminalPanelID()
  let helper = TerminalPanelID()

  let layout = TerminalSplitLayout.normalized(
    axis: .vertical,
    panelIDs: [helper],
    availablePanelIDs: [primary],
    primaryPanelID: primary
  )

  #expect(layout == nil)
}

@Test
func tabClosePolicyProtectsPrimaryPanelLastTab() {
  #expect(!TerminalPanel.canCloseTab(panelRole: .primary, tabCount: 1))
  #expect(TerminalPanel.canCloseTab(panelRole: .primary, tabCount: 2))
  #expect(TerminalPanel.canCloseTab(panelRole: .auxiliary, tabCount: 1))
}

@Test
func activeTabSelectionAfterClosingActiveTabChoosesNearestTab() {
  let first = TerminalTabID()
  let second = TerminalTabID()
  let third = TerminalTabID()

  #expect(TerminalPanel.activeTabIDAfterClosing(
    second,
    tabIDs: [first, second, third],
    activeTabID: second
  ) == third)

  #expect(TerminalPanel.activeTabIDAfterClosing(
    third,
    tabIDs: [first, second, third],
    activeTabID: third
  ) == second)
}

@Test
func activeTabSelectionPreservesActiveTabWhenClosingInactiveTab() {
  let first = TerminalTabID()
  let second = TerminalTabID()
  let third = TerminalTabID()

  #expect(TerminalPanel.activeTabIDAfterClosing(
    first,
    tabIDs: [first, second, third],
    activeTabID: third
  ) == third)
}

@MainActor
@Test
func tabDisplayNameUsesExplicitNameThenWorkingDirectoryThenFallbackNumber() {
  #expect(TerminalTab.displayName(
    name: "Build",
    workingDirectory: "/Users/jamesrochabrun/Desktop/git/GhosttySwift",
    index: 1
  ) == "Build")

  #expect(TerminalTab.displayName(
    name: nil,
    workingDirectory: "/Users/jamesrochabrun/Desktop/git/GhosttySwift",
    index: 1
  ) == "GhosttySwift")

  #expect(TerminalTab.displayName(
    name: nil,
    workingDirectory: nil,
    index: 2
  ) == "Tab 3")
}
