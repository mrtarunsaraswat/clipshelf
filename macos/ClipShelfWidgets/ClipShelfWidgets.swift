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
/// The widget's Pause / Resume button. The app applies the request within
/// about a second and refreshes the widget.
struct SetCapturePausedIntent: AppIntent {
  static var title: LocalizedStringResource = "Pause or resume ClipShelf"
  static var description = IntentDescription("Pause or resume clipboard capture.")
  static var openAppWhenRun = false
  @Parameter(title: "Paused") var paused: Bool
  init() {}
  init(paused: Bool) { self.paused = paused }
  func perform() async throws -> some IntentResult {
    try WidgetFavoritesStore.live().requestCapture(paused: paused)
    return .result()
  }
}
/// ClipShelf's app icon (64 px), embedded so the widget needs no asset catalog.
enum WidgetArtwork {
  static let appIcon: NSImage? = Data(base64Encoded: "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").flatMap(NSImage.init(data:))
  /// Pinboard colours, matching the app's palette; Snippets use purple.
  static let boards: [Color] = [
    Color(red: 0.36, green: 0.50, blue: 0.87), Color(red: 0.91, green: 0.54, blue: 0.31),
    Color(red: 0.68, green: 0.46, blue: 0.80), Color(red: 0.33, green: 0.65, blue: 0.55),
    Color(red: 0.84, green: 0.47, blue: 0.56), Color(red: 0.78, green: 0.66, blue: 0.29),
  ]
  static let snippets = Color(red: 0.61, green: 0.36, blue: 0.78)
  static func tint(for collection: WidgetCollection?) -> Color {
    guard let index = collection?.colorIndex else { return snippets }
    return boards[abs(index) % boards.count]
  }
}
struct FavoritesEntry: TimelineEntry {
  let date: Date
  let collection: WidgetCollection?
  let enabled: Bool
  let showPreviews: Bool
  let copiedID: String?
  var storageAvailable: Bool = true
  var paused: Bool = false
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
      enabled: first.enabled, showPreviews: first.showPreviews, copiedID: nil, storageAvailable: first.storageAvailable,
      paused: first.paused)
    return Timeline(entries: first.copiedID == nil ? [first] : [first, cleared], policy: .after(Date().addingTimeInterval(900)))
  }
  private func entry(_ configuration: FavoritesConfiguration) -> FavoritesEntry {
    let store = WidgetFavoritesStore.live()
    let data = store.read()
    let collection = configuration.collection.map { selected in data.collections.first { $0.id == selected.id } }
      ?? data.collections.first
    return FavoritesEntry(date: Date(), collection: collection, enabled: data.enabled,
      showPreviews: configuration.showPreviews, copiedID: store.copiedID(), storageAvailable: store.available,
      paused: data.paused ?? false)
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
  @Environment(\.widgetRenderingMode) private var renderingMode
  let entry: FavoritesEntry
  let family: WidgetFamily
  private let floatingURL = URL(string: "clipshelf://open?view=floating")!
  /// Tinted / accented desktop modes recolour everything; drop decorative fills there.
  private var fullColor: Bool { renderingMode == .fullColor }
  var body: some View {
    VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
      header
      if !entry.enabled {
        message(entry.storageAvailable ? "Enable Desktop Favorites in ClipShelf Preferences." : "Open ClipShelf once to set up Favorites.")
      } else if let collection = entry.collection, !collection.items.isEmpty {
        let limit = switch family {
        case .systemSmall: entry.showPreviews ? 2 : 3
        case .systemLarge: entry.showPreviews ? 8 : 12
        default: entry.showPreviews ? 4 : 6
        }
        if family == .systemSmall {
          ForEach(Array(collection.items.prefix(limit))) { item in favoriteRow(item) }
        } else {
          LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Array(collection.items.prefix(limit))) { item in favoriteRow(item) }
          }
        }
        Spacer(minLength: 0)
        FavoritesLink(destination: URL(string: "clipshelf://open?view=shelf")!) {
          HStack(spacing: 3) {
            Text("Open history")
            Image(systemName: "chevron.right").imageScale(.small)
          }
        }
        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
      } else {
        message(entry.collection == nil ? "Choose a collection in Edit Widget." : (entry.collection?.total ?? 0) > 0 ? "Open ClipShelf to view text too large for this widget." : "Save text snippets or pin text to this collection.")
      }
    }
    .containerBackground(for: .widget) {
      if fullColor {
        LinearGradient(colors: [tint.opacity(0.12), Color.clear], startPoint: .topLeading, endPoint: .center)
          .background(.background)
      } else {
        Color.clear
      }
    }
  }
  private var tint: Color { WidgetArtwork.tint(for: entry.collection) }
  private var header: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 7) {
        appIcon
        if entry.collection?.colorIndex != nil {
          Circle().fill(tint).frame(width: 7, height: 7).widgetAccentable()
        }
        Text(entry.collection?.name ?? "Favorites").font(.system(size: 13, weight: .semibold)).lineLimit(1)
        Spacer(minLength: 0)
        if entry.enabled {
          Button(intent: SetCapturePausedIntent(paused: !entry.paused)) {
            Image(systemName: entry.paused ? "play.fill" : "pause.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(entry.paused ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
              .frame(width: 22, height: 22)
              .background(.quaternary, in: Circle())
              .contentTransition(.symbolEffect(.replace))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(entry.paused ? "Resume clipboard capture" : "Pause clipboard capture")
        }
        FavoritesLink(destination: floatingURL) {
          Image(systemName: "arrow.up.forward.app").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
        }
        .accessibilityLabel("Open floating panel")
      }
      if entry.enabled && entry.paused {
        Label("Capture paused", systemImage: "pause.circle.fill")
          .font(.caption2.weight(.medium)).foregroundStyle(.orange).lineLimit(1)
      }
    }
  }
  /// The real app icon; a tinted glyph if it can't load. In tinted / accented
  /// desktop styles it is shown desaturated, like other apps' icons.
  @ViewBuilder private var appIcon: some View {
    if let icon = WidgetArtwork.appIcon {
      if #available(macOS 15.0, *) {
        Image(nsImage: icon).resizable().widgetAccentedRenderingMode(.accentedDesaturated).frame(width: 20, height: 20)
      } else {
        Image(nsImage: icon).resizable().frame(width: 20, height: 20)
      }
    } else {
      Image(systemName: "list.clipboard.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint).widgetAccentable()
    }
  }
  private func message(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Spacer(minLength: 0)
      Text(text).font(.caption).foregroundStyle(.secondary)
      FavoritesLink("Open ClipShelf", destination: floatingURL).font(.caption.bold())
        .foregroundStyle(tint).widgetAccentable()
      Spacer(minLength: 0)
    }
  }
  private func favoriteRow(_ item: WidgetFavorite) -> some View {
    let copied = entry.copiedID == item.id
    return Button(intent: CopyFavoriteIntent(id: item.id)) {
      HStack(spacing: 6) {
        VStack(alignment: .leading, spacing: 1) {
          Text(item.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
          if copied {
            Text("Copied").font(.caption2.weight(.medium)).foregroundStyle(.green).lineLimit(1)
          } else if entry.showPreviews {
            Text(item.text).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(copied ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
          .contentTransition(.symbolEffect(.replace))
      }
      .padding(.horizontal, 8).padding(.vertical, entry.showPreviews ? 5 : 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(fullColor ? AnyShapeStyle((copied ? Color.green : tint).opacity(0.13)) : AnyShapeStyle(.quaternary))
      }
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .strokeBorder(.quaternary, lineWidth: fullColor ? 0.5 : 0)
      }
      .animation(.easeOut(duration: 0.2), value: copied)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(copied ? "Copied \(item.title)" : "Copy \(item.title)")
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
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

#endif
