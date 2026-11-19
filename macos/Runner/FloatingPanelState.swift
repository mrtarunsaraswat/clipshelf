import Cocoa

/// Device-local window preferences; clipboard content remains in the library.
final class FloatingPanelState {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  var pinned: Bool {
    get { defaults.object(forKey: "floatingPinned") as? Bool ?? true }
    set { defaults.set(newValue, forKey: "floatingPinned") }
  }
  var frame: NSRect? {
    get { defaults.string(forKey: "floatingFrame").map(NSRectFromString) }
    set { if let frame = newValue { defaults.set(NSStringFromRect(frame), forKey: "floatingFrame") } }
  }
  static func shouldDismiss(presentation: String, pinned: Bool) -> Bool {
    presentation != "floating" || !pinned
  }
  static func restoredFrame(_ saved: NSRect?, visible: NSRect) -> NSRect {
    let width = min(max(saved?.width ?? 440, 360), visible.width)
    let height = min(max(saved?.height ?? 560, 360), visible.height)
    return NSRect(x: min(max(saved?.minX ?? visible.maxX - width - 24, visible.minX), visible.maxX - width),
      y: min(max(saved?.minY ?? visible.midY - height / 2, visible.minY), visible.maxY - height),
      width: width, height: height)
  }
}

/// Nonactivating panels can receive an in-panel click through a global monitor.
/// Classify the pointer position rather than assuming every global event is outside.
enum PanelDismissalPolicy {
  static func isOutside(_ point: NSPoint, panelFrame: NSRect, ownedFrames: [NSRect]) -> Bool {
    !panelFrame.contains(point) && !ownedFrames.contains { $0.contains(point) }
  }
  static func shouldDismissAfterFocusChange(ownsFocus: Bool, presentation: String, pinned: Bool) -> Bool {
    !ownsFocus && FloatingPanelState.shouldDismiss(presentation: presentation, pinned: pinned)
  }
}
