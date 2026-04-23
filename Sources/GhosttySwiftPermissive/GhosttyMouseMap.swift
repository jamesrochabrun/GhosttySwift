import CoreGraphics

enum GhosttyMouseMap {
  static func viewportPoint(for localPoint: CGPoint, height: CGFloat) -> CGPoint {
    CGPoint(x: localPoint.x, y: height - localPoint.y)
  }

  static var exitedViewportPoint: CGPoint {
    CGPoint(x: -1, y: -1)
  }
}
