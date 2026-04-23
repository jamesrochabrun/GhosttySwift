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
