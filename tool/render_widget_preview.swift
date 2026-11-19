// Renders the real SwiftUI widget view with sample favorites, outside WidgetKit hosting.
// This validates visual layout only; it does not register the widget or exercise AppIntent copy.
import AppKit
import SwiftUI
import WidgetKit

@main
struct WidgetPreviewRenderer {
  @MainActor static func main() throws {
    _ = NSApplication.shared
    let samples = [
      WidgetFavorite(id: "one", title: "Email signature", text: "Best regards, Alex"),
      WidgetFavorite(id: "two", title: "Project link", text: "https://example.com/project"),
      WidgetFavorite(id: "three", title: "Quick reply", text: "Thanks! I'll take a look."),
      WidgetFavorite(id: "four", title: "Meeting notes", text: "Agenda and next steps"),
      WidgetFavorite(id: "five", title: "Office address", text: "42 Garden Road"),
      WidgetFavorite(id: "six", title: "Favorite quote", text: "Make room for good ideas.")
    ]
    let collection = WidgetCollection(id: "snippets", name: "Snippets", items: samples, total: 6)
    for (name, family, width, previews) in [("small", WidgetFamily.systemSmall, 170.0, false), ("medium", .systemMedium, 360.0, false), ("small-text", .systemSmall, 170.0, true), ("medium-text", .systemMedium, 360.0, true)] {
      let entry = FavoritesEntry(date: Date(), collection: collection, enabled: true, showPreviews: previews, copiedID: nil)
      let content = FavoritesContentView(entry: entry, family: family)
        .padding(14).frame(width: width, height: 170).background(Color.white).environment(\.colorScheme, .light)
      let renderer = ImageRenderer(content: content); renderer.scale = 2
      guard let image = renderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("Could not render widget preview") }
      try data.write(to: URL(fileURLWithPath: "widget-\(name)-preview.png"))
    }
  }
}
