import AppKit

@MainActor
final class GhosttyTerminalScrollbarOverlayView: NSView {
  private let overlayModel: GhosttyTerminalOverlayModel

  init(overlayModel: GhosttyTerminalOverlayModel) {
    self.overlayModel = overlayModel
    super.init(frame: .zero)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)

    guard
      let scrollbar = overlayModel.scrollbar,
      scrollbar.total > scrollbar.length
    else {
      return
    }

    let trackRect = bounds.insetBy(dx: 1, dy: 8)
    let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4)
    NSColor.labelColor.withAlphaComponent(0.08).setFill()
    trackPath.fill()

    let thumbRect = CGRect(
      x: trackRect.minX,
      y: trackRect.minY + thumbOffset(in: trackRect, scrollbar: scrollbar),
      width: trackRect.width,
      height: thumbHeight(in: trackRect, scrollbar: scrollbar)
    )

    let thumbPath = NSBezierPath(roundedRect: thumbRect, xRadius: 4, yRadius: 4)
    NSColor.labelColor.withAlphaComponent(0.32).setFill()
    thumbPath.fill()
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard
      let scrollbar = overlayModel.scrollbar,
      scrollbar.total > scrollbar.length
    else {
      return nil
    }

    return bounds.contains(point) ? self : nil
  }

  override func mouseDown(with event: NSEvent) {
    handleScroll(event)
  }

  override func mouseDragged(with event: NSEvent) {
    handleScroll(event)
  }

  override func updateTrackingAreas() {
    trackingAreas.forEach(removeTrackingArea)
    super.updateTrackingAreas()

    addTrackingArea(NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .inVisibleRect, .mouseMoved],
      owner: self,
      userInfo: nil
    ))
  }

  override func mouseMoved(with event: NSEvent) {
    window?.invalidateCursorRects(for: self)
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .arrow)
  }

  func refresh() {
    let isVisible = overlayModel.scrollbar.map { $0.total > $0.length } ?? false
    alphaValue = isVisible ? 1 : 0
    isHidden = !isVisible
    needsDisplay = true
  }

  private func handleScroll(_ event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)
    let trackRect = bounds.insetBy(dx: 1, dy: 8)
    let locationY = max(trackRect.minY, min(point.y, trackRect.maxY)) - trackRect.minY
    let thumbHeight = thumbHeight(
      in: trackRect,
      scrollbar: overlayModel.scrollbar ?? .init(total: 0, offset: 0, length: 0)
    )

    overlayModel.scroll(
      trackHeight: trackRect.height,
      thumbHeight: thumbHeight,
      locationY: locationY
    )
  }

  private func thumbHeight(in trackRect: CGRect, scrollbar: GhosttySurfaceScrollbarState) -> CGFloat {
    guard scrollbar.total > 0 else { return trackRect.height }
    let ratio = CGFloat(scrollbar.length) / CGFloat(scrollbar.total)
    return min(max(trackRect.height * ratio, 28), trackRect.height)
  }

  private func thumbOffset(in trackRect: CGRect, scrollbar: GhosttySurfaceScrollbarState) -> CGFloat {
    guard scrollbar.total > scrollbar.length else { return 0 }
    let maxOffset = CGFloat(scrollbar.total - scrollbar.length)
    let progress = CGFloat(scrollbar.offset) / maxOffset
    return (trackRect.height - thumbHeight(in: trackRect, scrollbar: scrollbar)) * progress
  }
}
