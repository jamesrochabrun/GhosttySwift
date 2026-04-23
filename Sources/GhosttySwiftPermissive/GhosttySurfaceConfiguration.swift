import Foundation

public struct GhosttySurfaceConfiguration: Sendable {
  public var workingDirectory: String?
  public var command: String?
  public var initialInput: String?
  public var fontSize: Float

  public init(
    workingDirectory: String? = nil,
    command: String? = nil,
    initialInput: String? = nil,
    fontSize: Float = 0
  ) {
    self.workingDirectory = workingDirectory
    self.command = command
    self.initialInput = initialInput
    self.fontSize = fontSize
  }
}
