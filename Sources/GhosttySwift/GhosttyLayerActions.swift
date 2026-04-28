import QuartzCore

@MainActor
enum GhosttyLayerActions {
  static let disabled: [String: CAAction] = [
    "bounds": NSNull(),
    "position": NSNull(),
    "frame": NSNull(),
    "contents": NSNull(),
    "sublayers": NSNull(),
  ]
}
