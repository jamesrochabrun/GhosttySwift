import Foundation

public struct TerminalID: Codable, Hashable, Identifiable, Sendable {
  public let id: UUID

  public init(_ id: UUID = UUID()) {
    self.id = id
  }
}
