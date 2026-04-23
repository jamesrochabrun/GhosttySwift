import AppKit
import GhosttyKit

@MainActor
public final class GhosttySurfaceBridge {
  public private(set) var title: String = "Ghostty"
  public var onClose: ((Bool) -> Void)?

  weak var surfaceView: GhosttySurfaceView?

  public init() {}

  func attach(to surfaceView: GhosttySurfaceView) {
    self.surfaceView = surfaceView
  }

  func setTitle(_ title: String) {
    guard !title.isEmpty else { return }
    self.title = title
    surfaceView?.window?.title = title
  }

  func updateMouseShape(_ shape: ghostty_action_mouse_shape_e) {
    guard let surfaceView else { return }

    switch shape {
    case GHOSTTY_MOUSE_SHAPE_TEXT:
      surfaceView.activeCursor = .iBeam
    case GHOSTTY_MOUSE_SHAPE_POINTER:
      surfaceView.activeCursor = .pointingHand
    default:
      surfaceView.activeCursor = .arrow
    }

    surfaceView.window?.invalidateCursorRects(for: surfaceView)
  }

  func closeSurface(processAlive: Bool) {
    GhosttyTrace.write("surface bridge closeSurface processAlive=\(processAlive)")
    onClose?(processAlive)
  }
}
