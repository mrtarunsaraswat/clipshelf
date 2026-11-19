import Foundation
import Security

struct WidgetFavorite: Codable, Equatable, Identifiable {
  let id: String
  let title: String
  let text: String
}
struct WidgetCollection: Codable, Equatable, Identifiable {
  let id: String
  let name: String
  let items: [WidgetFavorite]
  let total: Int
}
struct WidgetFavorites: Codable, Equatable {
  var enabled: Bool
  var collections: [WidgetCollection]
  static let empty = WidgetFavorites(enabled: false, collections: [])
  /// Copy must preserve the whole value. Large entries stay in the main app.
  static func collection(id: String, name: String, items: [WidgetFavorite]) -> WidgetCollection {
    WidgetCollection(id: id, name: String(name.prefix(60)), items: Array(items.filter { !$0.text.isEmpty && $0.text.utf8.count <= 8192 }.prefix(6)).map { WidgetFavorite(id: $0.id, title: String($0.title.prefix(80)), text: $0.text) }, total: items.count)
  }
}
struct WidgetCopyFeedback: Codable {
  let id: String
  let date: Date
}
struct WidgetFavoritesStore {
  let directory: URL?
  var available: Bool { directory != nil }
  private static let liveStore = makeLive()
  static func live() -> Self { liveStore }
  /// macOS supports provisioned group.* IDs and unprovisioned TEAMID.name IDs.
  /// The latter must match the actual code-signing team, not an Info.plist value.
  static func authorizes(group: String, memberships: [String], signingTeam: String?) -> Bool {
    guard memberships.contains(group) else { return false }
    if group.hasPrefix("group.") { return group.count > 6 }
    guard let team = signingTeam, team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil else { return false }
    return group.hasPrefix(team + ".") && group.count > team.count + 1
  }
  private static func signingTeam() -> String? {
    var code: SecCode?
    guard SecCodeCopySelf([], &code) == errSecSuccess, let code = code else { return nil }
    var staticCode: SecStaticCode?
    guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode = staticCode else { return nil }
    var information: CFDictionary?
    guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess else { return nil }
    return (information as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
  }
  /// Builds without a Team-ID App Group (ad-hoc / unpaid) share through this folder
  /// instead. The unsandboxed host writes it directly; the sandboxed widget reaches it
  /// through the matching home-relative-path exception in Widget.entitlements.
  static let fallbackRelativePath = "Library/Application Support/ClipShelf/Widget"
  static func fallbackDirectory(home: String) -> URL {
    URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(fallbackRelativePath, isDirectory: true)
  }
  /// The user's real home. Inside the widget sandbox, NSHomeDirectory() is the container.
  private static func realHomeDirectory() -> String? {
    guard let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir else { return nil }
    return String(cString: directory)
  }
  private static func groupDirectory() -> URL? {
    let group = Bundle.main.object(forInfoDictionaryKey: "ClipShelfAppGroup") as? String ?? ""
    guard !group.isEmpty, let task = SecTaskCreateFromSelf(nil),
      let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String],
      authorizes(group: group, memberships: groups, signingTeam: signingTeam()) else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
  }
  private static func makeLive() -> Self {
    if let directory = groupDirectory(), let store = try? accessibleStore(at: directory) { return store }
    guard let home = realHomeDirectory(), let store = try? accessibleStore(at: fallbackDirectory(home: home)) else { return Self(directory: nil) }
    return store
  }
  /// On macOS a container URL alone does not prove access. Probe only an entitled
  /// container, once per process, with a unique file that contains no user data.
  static func accessibleStore(at directory: URL) throws -> Self {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700])
    let probe = directory.appendingPathComponent(".clipshelf-access-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: probe) }
    try Data().write(to: probe, options: .withoutOverwriting)
    _ = try Data(contentsOf: probe)
    return Self(directory: directory)
  }
  private var file: URL? { directory?.appendingPathComponent("widget-favorites.json") }
  func read() -> WidgetFavorites {
    guard let file = file, let data = try? Data(contentsOf: file), data.count <= 2_000_000,
      let value = try? JSONDecoder().decode(WidgetFavorites.self, from: data) else { return .empty }
    return value
  }
  @discardableResult func write(_ value: WidgetFavorites) throws -> Bool {
    guard let file = file else { return false }
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(value)
    guard data.count <= 2_000_000 else { throw CocoaError(.fileWriteOutOfSpace) }
    if (try? Data(contentsOf: file)) == data { return false }
    try data.write(to: file, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    // Invalidate stale copy feedback when the collection changes or sharing stops.
    if let directory = directory { try? FileManager.default.removeItem(at: directory.appendingPathComponent("widget-copied.json")) }
    return true
  }
  func text(for id: String) -> String? {
    let snapshot = read()
    guard snapshot.enabled else { return nil }
    return snapshot.collections.lazy.flatMap(\.items).first { $0.id == id }?.text
  }
  func recordCopy(id: String) throws {
    guard let directory = directory else { return }
    let data = try JSONEncoder().encode(WidgetCopyFeedback(id: id, date: Date()))
    try data.write(to: directory.appendingPathComponent("widget-copied.json"), options: .atomic)
  }
  func copiedID(now: Date = Date()) -> String? {
    guard let directory = directory,
      let data = try? Data(contentsOf: directory.appendingPathComponent("widget-copied.json")),
      let feedback = try? JSONDecoder().decode(WidgetCopyFeedback.self, from: data),
      now.timeIntervalSince(feedback.date) >= 0, now.timeIntervalSince(feedback.date) < 10 else { return nil }
    return feedback.id
  }
}
