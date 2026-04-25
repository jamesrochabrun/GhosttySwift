import Foundation

public struct TerminalSessionID: Codable, CustomStringConvertible, ExpressibleByStringLiteral, Hashable, Identifiable, Sendable {
  public let id: String

  public init(_ id: String = UUID().uuidString) {
    self.id = id
  }

  public init(stringLiteral value: StringLiteralType) {
    self.init(value)
  }

  public var description: String {
    id
  }
}
