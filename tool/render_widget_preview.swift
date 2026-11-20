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
    let variants: [(String, WidgetFamily, Double, Bool, ColorScheme, String?)] = [
      ("small", .systemSmall, 170, false, .light, nil),
      ("medium", .systemMedium, 360, false, .light, nil),
      ("small-text", .systemSmall, 170, true, .light, nil),
      ("medium-text", .systemMedium, 360, true, .light, nil),
      // Dark appearance, with the second favorite in its "Copied" state.
      ("medium-dark", .systemMedium, 360, true, .dark, "two"),
      ("large", .systemLarge, 360, false, .light, nil),
      ("large-dark", .systemLarge, 360, true, .dark, nil),
    ]
    // A paused pinboard, to show the pinboard colour and the paused state.
    let board = WidgetCollection(id: "launch", name: "Launch week", items: Array(samples.prefix(4)), total: 4, colorIndex: 1)
    let paused = FavoritesEntry(date: Date(), collection: board, enabled: true, showPreviews: false, copiedID: nil, paused: true)
    let pausedView = FavoritesContentView(entry: paused, family: .systemMedium)
      .padding(14).frame(width: 360, height: 170)
      .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .environment(\.colorScheme, .light)
    let pausedRenderer = ImageRenderer(content: pausedView); pausedRenderer.scale = 2
    if let image = pausedRenderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
      try data.write(to: URL(fileURLWithPath: "widget-medium-paused-preview.png"))
    }
    for (name, family, width, previews, scheme, copied) in variants {
      let shown = family == .systemLarge ? WidgetCollection(id: "snippets", name: "Snippets", items: samples + samples.map { WidgetFavorite(id: $0.id + "-2", title: $0.title + " 2", text: $0.text) }, total: 12) : collection
      let entry = FavoritesEntry(date: Date(), collection: shown, enabled: true, showPreviews: previews, copiedID: copied)
      let background = scheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.13) : Color.white
      let content = FavoritesContentView(entry: entry, family: family)
        .padding(14).frame(width: width, height: family == .systemLarge ? 376 : 170)
        .background(LinearGradient(colors: [Color.accentColor.opacity(0.10), .clear], startPoint: .topLeading, endPoint: .center))
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .environment(\.colorScheme, scheme)
      let renderer = ImageRenderer(content: content); renderer.scale = 2
      guard let image = renderer.cgImage, let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { fatalError("Could not render widget preview") }
      try data.write(to: URL(fileURLWithPath: "widget-\(name)-preview.png"))
    }
  }
}
