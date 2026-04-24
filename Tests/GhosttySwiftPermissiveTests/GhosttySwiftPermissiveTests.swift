import Testing
@testable import GhosttySwiftPermissive

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
