import Foundation

public struct TerminalTabID: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID

  public init(_ id: UUID = UUID()) {
    self.id = id
  }
}
