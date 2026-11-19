import AppIntents
import AppKit
import SwiftUI
import WidgetKit

struct FavoritesCollectionEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Collection"
  static var defaultQuery = FavoritesCollectionQuery()
  let id: String
  let name: String
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct FavoritesCollectionQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [FavoritesCollectionEntity] {
    try await suggestedEntities().filter { identifiers.contains($0.id) }
  }
  func suggestedEntities() async throws -> [FavoritesCollectionEntity] {
    WidgetFavoritesStore.live().read().collections.map { FavoritesCollectionEntity(id: $0.id, name: $0.name) }
  }
  func defaultResult() async -> FavoritesCollectionEntity? { try? await suggestedEntities().first }
}
struct FavoritesConfiguration: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Favorites"
  static var description = IntentDescription("Choose saved text from a pinboard or your snippets.")
  @Parameter(title: "Collection") var collection: FavoritesCollectionEntity?
  @Parameter(title: "Show text previews", default: false) var showPreviews: Bool
}
struct CopyFavoriteIntent: AppIntent {
  static var title: LocalizedStringResource = "Copy favorite"
  static var description = IntentDescription("Copy this saved text to the clipboard.")
  static var openAppWhenRun = false
  @Parameter(title: "Favorite") var favoriteID: String
  init() {}
  init(id: String) { favoriteID = id }
  @MainActor func perform() async throws -> some IntentResult {
    let store = WidgetFavoritesStore.live()
    guard let text = store.text(for: favoriteID) else { throw CopyError.unavailable }
    NSPasteboard.general.clearContents()
    guard NSPasteboard.general.setString(text, forType: .string) else { throw CopyError.failed }
    try? store.recordCopy(id: favoriteID)
    WidgetCenter.shared.reloadTimelines(ofKind: "ClipShelfFavorites")
    return .result()
  }
  enum CopyError: Error, CustomLocalizedStringResourceConvertible {
    case unavailable, failed
    var localizedStringResource: LocalizedStringResource {
      switch self {
      case .unavailable: "This favorite is no longer available. Open ClipShelf to update Favorites."
      case .failed: "The text could not be copied. Try again."
      }
    }
  }
}
struct FavoritesEntry: TimelineEntry {
  let date: Date
  let collection: WidgetCollection?
  let enabled: Bool
  let showPreviews: Bool
  let copiedID: String?
  var storageAvailable: Bool = true
}
struct FavoritesProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> FavoritesEntry {
    FavoritesEntry(date: Date(), collection: WidgetCollection(id: "snippets", name: "Snippets", items: [
      WidgetFavorite(id: "example", title: "A favorite snippet", text: "Your saved text, a click away.")
    ], total: 1), enabled: true, showPreviews: false, copiedID: nil)
  }
  func snapshot(for configuration: FavoritesConfiguration, in context: Context) async -> FavoritesEntry {
    context.isPreview ? placeholder(in: context) : entry(configuration)
  }
  func timeline(for configuration: FavoritesConfiguration, in context: Context) async -> Timeline<FavoritesEntry> {
    let first = entry(configuration)
    let cleared = FavoritesEntry(date: Date().addingTimeInterval(10), collection: first.collection,
      enabled: first.enabled, showPreviews: first.showPreviews, copiedID: nil, storageAvailable: first.storageAvailable)
    return Timeline(entries: first.copiedID == nil ? [first] : [first, cleared], policy: .after(Date().addingTimeInterval(900)))
  }
  private func entry(_ configuration: FavoritesConfiguration) -> FavoritesEntry {
    let store = WidgetFavoritesStore.live()
    let data = store.read()
    let collection = configuration.collection.map { selected in data.collections.first { $0.id == selected.id } }
      ?? data.collections.first
    return FavoritesEntry(date: Date(), collection: collection, enabled: data.enabled,
      showPreviews: configuration.showPreviews, copiedID: store.copiedID(), storageAvailable: store.available)
  }
}
/// ImageRenderer cannot draw a system Link; preview builds render the identical label.
struct FavoritesLink<Label: View>: View {
  let destination: URL
  let label: Label
  init(destination: URL, @ViewBuilder label: () -> Label) {
    self.destination = destination; self.label = label()
  }
  init(_ title: String, destination: URL) where Label == Text {
    self.destination = destination; self.label = Text(title)
  }
  var body: some View {
    #if CLIPSHELF_WIDGET_PREVIEW
    label.foregroundStyle(.tint)
    #else
    Link(destination: destination) { label }
    #endif
  }
}
struct FavoritesWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FavoritesEntry
  var body: some View { FavoritesContentView(entry: entry, family: family) }
}
struct FavoritesContentView: View {
  let entry: FavoritesEntry
  let family: WidgetFamily
  private let floatingURL = URL(string: "clipshelf://open?view=floating")!
  var body: some View {
    VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
      HStack {
        Image(systemName: "clipboard.fill").foregroundStyle(.teal)
        Text(entry.collection?.name ?? "Favorites").font(.headline).lineLimit(1)
        Spacer(minLength: 0)
        FavoritesLink(destination: floatingURL) { Image(systemName: "arrow.up.forward.app") }
          .accessibilityLabel("Open floating panel")
      }
      if !entry.enabled {
        Spacer(minLength: 0)
        Text(entry.storageAvailable ? "Enable Desktop Favorites in ClipShelf Preferences." : "Complete widget signing setup in ClipShelf.").font(.caption).foregroundStyle(.secondary)
        FavoritesLink("Open ClipShelf", destination: floatingURL).font(.caption.bold())
        Spacer(minLength: 0)
      } else if let collection = entry.collection, !collection.items.isEmpty {
        let limit = entry.showPreviews ? (family == .systemSmall ? 2 : 4) : (family == .systemSmall ? 3 : 6)
        if family == .systemSmall {
          ForEach(Array(collection.items.prefix(limit))) { item in favoriteRow(item) }
        } else {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(Array(collection.items.prefix(limit))) { item in favoriteRow(item) }
          }
        }
        Spacer(minLength: 0)
        FavoritesLink("Open history", destination: URL(string: "clipshelf://open?view=shelf")!)
          .font(.caption2).foregroundStyle(.secondary)
      } else {
        Spacer(minLength: 0)
        Text(entry.collection == nil ? "Choose a collection in Edit Widget." : (entry.collection?.total ?? 0) > 0 ? "Open ClipShelf to view text too large for this widget." : "Save text snippets or pin text to this collection.")
          .font(.caption).foregroundStyle(.secondary)
        FavoritesLink("Open ClipShelf", destination: floatingURL).font(.caption.bold())
        Spacer(minLength: 0)
      }
    }
    .containerBackground(.background, for: .widget)
  }
  private func favoriteRow(_ item: WidgetFavorite) -> some View {
    Button(intent: CopyFavoriteIntent(id: item.id)) {
      HStack(spacing: 6) {
        VStack(alignment: .leading, spacing: 2) {
          Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
          if entry.showPreviews { Text(item.text).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }
        Spacer(minLength: 0)
        Image(systemName: entry.copiedID == item.id ? "checkmark" : "doc.on.doc").font(.caption2)
      }
      .padding(.horizontal, 7).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Copy \(item.title)")
  }
}
#if !CLIPSHELF_WIDGET_PREVIEW
@main
struct ClipShelfFavoritesWidget: Widget {
  let kind = "ClipShelfFavorites"
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: FavoritesConfiguration.self, provider: FavoritesProvider()) { entry in
      FavoritesWidgetView(entry: entry)
    }
    .configurationDisplayName("ClipShelf Favorites")
    .description("Copy saved text from your snippets and pinboards.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

#endif
