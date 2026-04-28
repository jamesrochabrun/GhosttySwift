import QuartzCore

@MainActor
enum GhosttyLayerActions {
  /// Core Animation treats `NSNull` values in a layer `actions` dictionary as
  /// "no implicit action" for that key. Ghostty renders into IOSurface-backed
  /// layers, so implicit bounds/contents animations can briefly stretch a stale
  /// frame during pane resize before the next correctly sized surface arrives.
  static let disabled: [String: CAAction] = [
    "bounds": NSNull(),
    "position": NSNull(),
    "frame": NSNull(),
    "contents": NSNull(),
    "sublayers": NSNull(),
  ]
}
