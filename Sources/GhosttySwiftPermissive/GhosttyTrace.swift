import Foundation

enum GhosttyTrace {
  private static let fileURL = URL(fileURLWithPath: "/tmp/ghosttyswiftpermissive-sample.trace")

  static func write(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    let data = Data(line.utf8)

    if FileManager.default.fileExists(atPath: fileURL.path) {
      guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    } else {
      try? data.write(to: fileURL, options: .atomic)
    }
  }
}
