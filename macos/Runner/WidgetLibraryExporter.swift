import Foundation
import WidgetKit

enum WidgetLibraryExporter {
  static func snapshot(clips: [Clip], boards: [Pinboard], enabled: Bool, paused: Bool = false) -> WidgetFavorites {
    let savedText = clips.filter { $0.kind == "text" && $0.retained && !$0.text.isEmpty }
    func favorites(_ clips: [Clip]) -> [WidgetFavorite] {
      clips.map { WidgetFavorite(id: $0.id, title: $0.title, text: $0.text) }
    }
    var collections: [WidgetCollection] = []
    if enabled {
      collections.append(WidgetFavorites.collection(id: "snippets", name: "Snippets", items: favorites(savedText.filter(\.snippet))))
      for board in boards {
        collections.append(WidgetFavorites.collection(id: board.id, name: board.name, items: favorites(savedText.filter { $0.boardID == board.id }), colorIndex: board.color))
      }
    }
    // Bound the encoded payload too: control characters can expand during JSON encoding.
    var remaining = 1_800_000
    let bounded = collections.prefix(31).map { collection -> WidgetCollection in
      let items = collection.items.filter { item in
        let size = (try? JSONEncoder().encode(item).count) ?? Int.max
        guard size <= remaining else { return false }
        remaining -= size
        return true
      }
      return WidgetCollection(id: collection.id, name: collection.name, items: items, total: collection.total, colorIndex: collection.colorIndex)
    }
    return WidgetFavorites(enabled: enabled, collections: bounded, paused: enabled ? paused : nil)  // nothing shared while off
  }
}
extension ClipboardBridge {
  func updateWidget() {
    let store = widgetStore
    guard store.available else { return }
    do {
      let snapshot = WidgetLibraryExporter.snapshot(clips: archive.clips, boards: archive.boards ?? [], enabled: widgetSharing, paused: archive.paused)
      if try store.write(snapshot) { WidgetCenter.shared.reloadTimelines(ofKind: "ClipShelfFavorites") }
    } catch { warning = "Desktop Favorites could not be updated. Your library is still available here." }
  }
}
extension ClipboardBridge {
  /// Applies a Pause / Resume tapped in the widget (checked on the capture timer).
  func applyWidgetCaptureRequest() {
    guard widgetSharing, let paused = widgetStore.takeCaptureRequest(), paused != archive.paused else { return }
    archive.paused = paused
    configureScreenshots(); persist(); publish()
  }
}
