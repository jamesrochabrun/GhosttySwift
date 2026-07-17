import Foundation
import Testing
import GhosttyKit
@testable import GhosttySwift

@Test
func surfaceConfigurationDefaultsAreEmpty() {
  let configuration = GhosttySurfaceConfiguration()

  #expect(configuration.workingDirectory == nil)
  #expect(configuration.command == nil)
  #expect(configuration.environment.isEmpty)
  #expect(configuration.initialInput == nil)
  #expect(configuration.fontSize == 0)
  #expect(configuration.initialScaleFactor == nil)
  #expect(configuration.initialSize == nil)
  #expect(configuration.configurationOverlayPath == nil)
  #expect(configuration.colorScheme == nil)
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
  #expect(controller.foregroundProcessID == nil)
  #expect(String(describing: type(of: view)).contains("GhosttyTerminalView"))
}

@MainActor
@Test
func runtimeCanLoadConfigAsynchronously() async throws {
  let configURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-\(UUID().uuidString).conf")
  try "font-size = 14\n".write(to: configURL, atomically: true, encoding: .utf8)
  defer { try? FileManager.default.removeItem(at: configURL) }

  let runtime = try await GhosttyRuntime.make(configPath: configURL.path)

  #expect(String(describing: type(of: runtime)).contains("GhosttyRuntime"))
}

@MainActor
@Test
func configurationOverlayOverridesBaseColorsBeforeFinalization() throws {
  let baseURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-base-\(UUID().uuidString).conf")
  let overlayURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-overlay-\(UUID().uuidString).conf")
  try "foreground = #f4f4f5\nbackground = #18181b\n".write(
    to: baseURL,
    atomically: true,
    encoding: .utf8
  )
  try "foreground = #202124\nbackground = #fafafa\n".write(
    to: overlayURL,
    atomically: true,
    encoding: .utf8
  )
  defer {
    try? FileManager.default.removeItem(at: baseURL)
    try? FileManager.default.removeItem(at: overlayURL)
  }

  let runtime = try GhosttyRuntime(configPath: baseURL.path)
  let config = try #require(
    GhosttyRuntime.loadConfig(
      configPath: baseURL.path,
      overlayPath: overlayURL.path
    )
  )
  defer { ghostty_config_free(config) }
  withExtendedLifetime(runtime) {}

  let foreground = try #require(configurationColor("foreground", in: config))
  let background = try #require(configurationColor("background", in: config))

  #expect(foreground.0 == 32)
  #expect(foreground.1 == 33)
  #expect(foreground.2 == 36)
  #expect(background.0 == 250)
  #expect(background.1 == 250)
  #expect(background.2 == 250)
}

@MainActor
@Test
func runtimeAppliesAppOverlayBeforeCreatingNewSurface() throws {
  let overlayURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-app-overlay-\(UUID().uuidString).conf")
  try "foreground = #202124\nbackground = #fafafa\n".write(
    to: overlayURL,
    atomically: true,
    encoding: .utf8
  )
  defer { try? FileManager.default.removeItem(at: overlayURL) }

  let runtime = try GhosttyRuntime()
  let applied = try runtime.applyConfigurationOverlay(at: overlayURL.path)
  let controller = try GhosttyTerminalController(
    runtime: runtime,
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      colorScheme: .light
    )
  )
  let container = try GhosttyTerminalContainerView(controller: controller)

  #expect(applied)
  #expect(runtime.configurationOverlayPath == overlayURL.path)
  #expect(controller.colorScheme == .light)
  withExtendedLifetime(container) {}
}

@MainActor
@Test
func controllerAppliesAndRestoresLiveConfigurationOverlay() throws {
  let firstOverlayURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-overlay-\(UUID().uuidString).conf")
  let secondOverlayURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-overlay-\(UUID().uuidString).conf")
  try "foreground = #202020\nbackground = #fafafa\n".write(
    to: firstOverlayURL,
    atomically: true,
    encoding: .utf8
  )
  try "foreground = #f0f0f0\nbackground = #202020\n".write(
    to: secondOverlayURL,
    atomically: true,
    encoding: .utf8
  )
  defer {
    try? FileManager.default.removeItem(at: firstOverlayURL)
    try? FileManager.default.removeItem(at: secondOverlayURL)
  }

  let controller = try GhosttyTerminalController(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      fontSize: 12,
      configurationOverlayPath: firstOverlayURL.path
    )
  )
  let container = try GhosttyTerminalContainerView(controller: controller)

  #expect(controller.configurationOverlayPath == firstOverlayURL.path)
  let appliedSecondOverlay = try controller.applyConfigurationOverlay(at: secondOverlayURL.path)
  #expect(appliedSecondOverlay)
  #expect(controller.configurationOverlayPath == secondOverlayURL.path)
  let restoredRuntimeConfig = try controller.applyConfigurationOverlay(at: nil)
  #expect(restoredRuntimeConfig)
  #expect(controller.configurationOverlayPath == nil)
  withExtendedLifetime(container) {}
}

private func configurationColor(
  _ key: String,
  in config: ghostty_config_t
) -> (UInt8, UInt8, UInt8)? {
  var color = ghostty_config_color_s()
  let found = key.withCString { keyPointer in
    ghostty_config_get(
      config,
      &color,
      keyPointer,
      UInt(key.utf8.count)
    )
  }
  guard found else { return nil }
  return (color.r, color.g, color.b)
}

@MainActor
@Test
func terminalSurfaceViewAcceptsHostClosePolicy() throws {
  let session = try TerminalSession(
    primaryConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    )
  )
  let view = TerminalSurfaceView(
    session: session,
    panelClosePolicy: { _ in false },
    tabClosePolicy: { _, _ in false },
    onClosePanel: { _ in },
    onCloseTab: { _, _ in }
  )
  let controller = try #require(session.primaryPanel.activeTab?.controller)

  #expect(controller.closesHostWindowOnClose)
  controller.closesHostWindowOnClose = false

  #expect(String(describing: type(of: view)).contains("TerminalSurfaceView"))
  #expect(!controller.closesHostWindowOnClose)
}

@MainActor
@Test
func controllerPublicInputMethodsAreSafeBeforeSurfaceAttachment() throws {
  let controller = try GhosttyTerminalController(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      environment: ["TERM_PROGRAM": "AgentHub"]
    )
  )

  controller.sendText("hello")
  controller.sendBytes(Array("world".utf8))
  controller.sendReturnKey()
  controller.sendArrowDownKey()
  #expect(!controller.startSearch())
  controller.requestClose()

  #expect(controller.configuration.environment["TERM_PROGRAM"] == "AgentHub")
}

@MainActor
@Test
func bridgeOpenURLActionDelegatesToCallback() {
  let bridge = GhosttySurfaceBridge()
  var openedURL: String?
  bridge.onOpenURL = { url in
    openedURL = url
    return true
  }

  "https://agenthub.local".withCString { pointer in
    var action = ghostty_action_s()
    action.tag = GHOSTTY_ACTION_OPEN_URL
    action.action.open_url = ghostty_action_open_url_s(
      kind: GHOSTTY_ACTION_OPEN_URL_KIND_UNKNOWN,
      url: pointer,
      len: UInt("https://agenthub.local".utf8.count)
    )
    #expect(bridge.handleAction(action))
  }

  #expect(openedURL == "https://agenthub.local")
}

@MainActor
@Test
func bridgeDeniesClipboardConfirmationWithoutHostHandler() async {
  let bridge = GhosttySurfaceBridge()
  let confirmation = GhosttyClipboardConfirmation(
    request: .osc52Read,
    location: nil,
    contents: "secret"
  )

  let decision = await bridge.confirmClipboardRequest(confirmation)

  #expect(decision == .deny)
}

@MainActor
@Test
func controllerForwardsClipboardConfirmationToBridgeHandler() async throws {
  let controller = try GhosttyTerminalController(
    configuration: GhosttySurfaceConfiguration(workingDirectory: "/tmp")
  )
  let confirmation = GhosttyClipboardConfirmation(
    request: .paste,
    location: .standard,
    contents: "echo hello"
  )

  controller.onClipboardConfirmation = { request in
    #expect(request == confirmation)
    return .allow
  }

  let decision = await controller.bridge.confirmClipboardRequest(confirmation)

  #expect(decision == .allow)
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
  #expect(layout?.root == .split(
    axis: .horizontal,
    children: [
      .panel(primary),
      .panel(helper),
    ]
  ))
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
func splitDirectionDoesNotChangeTwoPaneShape() {
  let primary = TerminalPanelID()
  let helper = TerminalPanelID()

  let layout = TerminalSplitLayout.normalized(
    axis: .vertical,
    panelIDs: [primary, helper],
    availablePanelIDs: [primary, helper],
    primaryPanelID: primary
  )

  #expect(layout?.axis == .vertical)
  #expect(layout?.panelIDs == [primary, helper])
  #expect(layout?.root == .split(
    axis: .horizontal,
    children: [
      .panel(primary),
      .panel(helper),
    ]
  ))
}

@Test
func threePaneLayoutKeepsPrimaryFullHeightWithRightStack() {
  let primary = TerminalPanelID()
  let first = TerminalPanelID()
  let second = TerminalPanelID()

  let layout = TerminalSplitLayout.normalized(
    axis: .horizontal,
    panelIDs: [primary, first, second],
    availablePanelIDs: [primary, first, second],
    primaryPanelID: primary
  )

  #expect(layout?.panelIDs == [primary, first, second])
  #expect(layout?.root == .split(
    axis: .horizontal,
    children: [
      .panel(primary),
      .split(
        axis: .vertical,
        children: [
          .panel(first),
          .panel(second),
        ]
      ),
    ]
  ))
}

@Test
func fourPaneLayoutUsesTwoByTwoGrid() {
  let primary = TerminalPanelID()
  let first = TerminalPanelID()
  let second = TerminalPanelID()
  let third = TerminalPanelID()

  let layout = TerminalSplitLayout.normalized(
    axis: .horizontal,
    panelIDs: [primary, first, second, third],
    availablePanelIDs: [primary, first, second, third],
    primaryPanelID: primary
  )

  #expect(layout?.panelIDs == [primary, first, second, third])
  #expect(layout?.root == .split(
    axis: .vertical,
    children: [
      .split(
        axis: .horizontal,
        children: [
          .panel(primary),
          .panel(first),
        ]
      ),
      .split(
        axis: .horizontal,
        children: [
          .panel(second),
          .panel(third),
        ]
      ),
    ]
  ))
}

@Test
func removingPanelRebuildsCanonicalLayoutForRemainingPaneCount() throws {
  let primary = TerminalPanelID()
  let first = TerminalPanelID()
  let second = TerminalPanelID()
  let third = TerminalPanelID()

  let layout = try #require(TerminalSplitLayout.normalized(
    axis: .horizontal,
    panelIDs: [primary, first, second, third],
    availablePanelIDs: [primary, first, second, third],
    primaryPanelID: primary
  ))

  let updatedLayout = try #require(layout.removingPanel(
    third,
    availablePanelIDs: [primary, first, second],
    primaryPanelID: primary
  ))

  #expect(updatedLayout.panelIDs == [primary, first, second])
  #expect(updatedLayout.root == .split(
    axis: .horizontal,
    children: [
      .panel(primary),
      .split(
        axis: .vertical,
        children: [
          .panel(first),
          .panel(second),
        ]
      ),
    ]
  ))
}

@Test
func removingLastAuxiliaryClearsSplitLayout() throws {
  let primary = TerminalPanelID()
  let helper = TerminalPanelID()

  let layout = try #require(TerminalSplitLayout.normalized(
    axis: .horizontal,
    panelIDs: [primary, helper],
    availablePanelIDs: [primary, helper],
    primaryPanelID: primary
  ))

  let updatedLayout = layout.removingPanel(
    helper,
    availablePanelIDs: [primary],
    primaryPanelID: primary
  )

  #expect(updatedLayout == nil)
}

@Test
func twoPaneNavigationMovesLeftAndRightWithoutWrapping() {
  let primary = TerminalPanelID()
  let helper = TerminalPanelID()
  let visibleIDs = [primary, helper]

  #expect(TerminalSession.panelID(
    from: primary,
    direction: .right,
    visibleIDs: visibleIDs
  ) == helper)
  #expect(TerminalSession.panelID(
    from: helper,
    direction: .left,
    visibleIDs: visibleIDs
  ) == primary)
  #expect(TerminalSession.panelID(
    from: primary,
    direction: .left,
    visibleIDs: visibleIDs
  ) == nil)
  #expect(TerminalSession.panelID(
    from: helper,
    direction: .right,
    visibleIDs: visibleIDs
  ) == nil)
}

@Test
func threePaneNavigationUsesLeftPanelAndRightStack() {
  let primary = TerminalPanelID()
  let topRight = TerminalPanelID()
  let bottomRight = TerminalPanelID()
  let visibleIDs = [primary, topRight, bottomRight]

  #expect(TerminalSession.panelID(
    from: primary,
    direction: .right,
    visibleIDs: visibleIDs
  ) == topRight)
  #expect(TerminalSession.panelID(
    from: topRight,
    direction: .down,
    visibleIDs: visibleIDs
  ) == bottomRight)
  #expect(TerminalSession.panelID(
    from: bottomRight,
    direction: .up,
    visibleIDs: visibleIDs
  ) == topRight)
  #expect(TerminalSession.panelID(
    from: bottomRight,
    direction: .left,
    visibleIDs: visibleIDs
  ) == primary)
  #expect(TerminalSession.panelID(
    from: topRight,
    direction: .right,
    visibleIDs: visibleIDs
  ) == nil)
}

@Test
func fourPaneNavigationUsesGridNeighbors() {
  let topLeft = TerminalPanelID()
  let topRight = TerminalPanelID()
  let bottomLeft = TerminalPanelID()
  let bottomRight = TerminalPanelID()
  let visibleIDs = [topLeft, topRight, bottomLeft, bottomRight]

  #expect(TerminalSession.panelID(
    from: topLeft,
    direction: .right,
    visibleIDs: visibleIDs
  ) == topRight)
  #expect(TerminalSession.panelID(
    from: topLeft,
    direction: .down,
    visibleIDs: visibleIDs
  ) == bottomLeft)
  #expect(TerminalSession.panelID(
    from: bottomRight,
    direction: .left,
    visibleIDs: visibleIDs
  ) == bottomLeft)
  #expect(TerminalSession.panelID(
    from: bottomRight,
    direction: .up,
    visibleIDs: visibleIDs
  ) == topRight)
  #expect(TerminalSession.panelID(
    from: topRight,
    direction: .right,
    visibleIDs: visibleIDs
  ) == nil)
}

@Test
func tabNavigationMovesBetweenAdjacentTabsWithoutWrapping() {
  let first = TerminalTabID()
  let second = TerminalTabID()
  let third = TerminalTabID()
  let tabIDs = [first, second, third]

  #expect(TerminalSession.tabID(
    from: second,
    direction: .previous,
    tabIDs: tabIDs
  ) == first)
  #expect(TerminalSession.tabID(
    from: second,
    direction: .next,
    tabIDs: tabIDs
  ) == third)
  #expect(TerminalSession.tabID(
    from: first,
    direction: .previous,
    tabIDs: tabIDs
  ) == nil)
  #expect(TerminalSession.tabID(
    from: third,
    direction: .next,
    tabIDs: tabIDs
  ) == nil)
}

@Test
func tabClosePolicyProtectsPrimaryPanelLastTab() {
  #expect(!TerminalPanel.canCloseTab(panelRole: .primary, tabCount: 1))
  #expect(TerminalPanel.canCloseTab(panelRole: .primary, tabCount: 2))
  #expect(TerminalPanel.canCloseTab(panelRole: .auxiliary, tabCount: 1))
}

@MainActor
@Test
func sessionRequestCloseAllIsSafeBeforeSurfaceAttachment() throws {
  let session = try TerminalSession(
    primaryConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    )
  )
  _ = try session.openTab(configuration: GhosttySurfaceConfiguration(workingDirectory: "/tmp"))
  _ = try session.openPanel(configuration: GhosttySurfaceConfiguration(workingDirectory: "/tmp"))

  session.requestCloseAll()

  #expect(session.panels.count == 2)
  #expect(session.primaryPanel.tabs.count == 2)
  #expect(session.auxiliaryPanels.first?.tabs.count == 1)
}

@MainActor
@Test
func openPanelPreservesExplicitInitialScaleFactor() throws {
  let session = try TerminalSession(
    primaryConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp"
    )
  )

  let panel = try session.openPanel(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      initialScaleFactor: 1.25
    )
  )

  #expect(panel.activeTab?.controller.configuration.initialScaleFactor == 1.25)
}

@Test
func panelConfigurationSeedsInitialScaleFactorFromActiveWindow() {
  let configuration = TerminalSession.resolvedPanelConfiguration(
    configuration: nil,
    defaultConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      fontSize: 13
    ),
    activeWindowScaleFactor: 1.5
  )

  #expect(configuration.workingDirectory == "/tmp")
  #expect(configuration.fontSize == 13)
  #expect(configuration.initialScaleFactor == 1.5)
}

@Test
func panelConfigurationPreservesConfigurationOverlay() {
  let configuration = TerminalSession.resolvedPanelConfiguration(
    configuration: nil,
    defaultConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      configurationOverlayPath: "/tmp/light.conf"
    ),
    activeWindowScaleFactor: nil
  )

  #expect(configuration.configurationOverlayPath == "/tmp/light.conf")
}

@MainActor
@Test
func newTabPreservesConfigurationOverlay() throws {
  let overlayURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("ghostty-overlay-\(UUID().uuidString).conf")
  try "foreground = #202020\nbackground = #fafafa\n".write(
    to: overlayURL,
    atomically: true,
    encoding: .utf8
  )
  defer {
    try? FileManager.default.removeItem(at: overlayURL)
  }

  let session = try TerminalSession(
    primaryConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      configurationOverlayPath: overlayURL.path,
      colorScheme: .light
    )
  )
  let tab = try session.openTab()

  #expect(tab.controller.configurationOverlayPath == overlayURL.path)
  #expect(tab.controller.colorScheme == .light)
}

@Test
func panelConfigurationDoesNotOverrideExplicitInitialScaleFactor() {
  let configuration = TerminalSession.resolvedPanelConfiguration(
    configuration: GhosttySurfaceConfiguration(
      workingDirectory: "/tmp",
      initialScaleFactor: 2
    ),
    defaultConfiguration: GhosttySurfaceConfiguration(
      workingDirectory: "/fallback"
    ),
    activeWindowScaleFactor: 1
  )

  #expect(configuration.workingDirectory == "/tmp")
  #expect(configuration.initialScaleFactor == 2)
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
