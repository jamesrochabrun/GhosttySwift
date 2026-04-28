import Foundation

public struct GhosttySurfaceInitialSize: Equatable, Sendable {
  public var width: Double
  public var height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}

public struct GhosttySurfaceConfiguration: Sendable {
  public var workingDirectory: String?
  public var command: String?
  public var environment: [String: String]
  public var initialInput: String?
  public var fontSize: Float
  public var initialScaleFactor: Double?
  public var initialSize: GhosttySurfaceInitialSize?

  public init(
    workingDirectory: String? = nil,
    command: String? = nil,
    environment: [String: String] = [:],
    initialInput: String? = nil,
    fontSize: Float = 0,
    initialScaleFactor: Double? = nil,
    initialSize: GhosttySurfaceInitialSize? = nil
  ) {
    self.workingDirectory = workingDirectory
    self.command = command
    self.environment = environment
    self.initialInput = initialInput
    self.fontSize = fontSize
    self.initialScaleFactor = initialScaleFactor
    self.initialSize = initialSize
  }
}
