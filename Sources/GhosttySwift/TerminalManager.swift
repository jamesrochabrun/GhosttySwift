import Observation

@MainActor
@Observable
public final class TerminalManager {
  public let runtime: GhosttyRuntime
  public private(set) var sessionOrder: [TerminalSessionID] = []
  private var sessionsByID: [TerminalSessionID: TerminalSession] = [:]

  public init(configPath: String? = nil) throws {
    self.runtime = try GhosttyRuntime(configPath: configPath)
  }

  public var sessions: [TerminalSession] {
    sessionOrder.compactMap { sessionsByID[$0] }
  }

  @discardableResult
  public func openSession(
    id: TerminalSessionID = TerminalSessionID(),
    primaryConfiguration: GhosttySurfaceConfiguration = .init(),
    primaryName: String? = nil
  ) throws -> TerminalSession {
    if let existingSession = sessionsByID[id] {
      return existingSession
    }

    let session = try TerminalSession(
      runtime: runtime,
      primaryConfiguration: primaryConfiguration,
      primaryName: primaryName
    )
    sessionsByID[id] = session
    sessionOrder.append(id)
    return session
  }

  @discardableResult
  public func closeSession(id: TerminalSessionID) -> TerminalSession? {
    sessionOrder.removeAll { $0 == id }
    return sessionsByID.removeValue(forKey: id)
  }

  public func session(for id: TerminalSessionID) -> TerminalSession? {
    sessionsByID[id]
  }
}
