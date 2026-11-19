// Native logic checks use an in-memory boundary by default.
// Pass --system-pasteboard to additionally exercise an isolated named macOS pasteboard.
import Cocoa
import FlutterMacOS
setbuf(stdout, nil)

final class Messenger: NSObject, FlutterBinaryMessenger {
  var messages = 0
  func send(onChannel channel: String, message: Data?) { messages += 1 }
  func send(onChannel channel: String, message: Data?, binaryReply: FlutterBinaryReply?) { messages += 1; binaryReply?(nil) }
  func setMessageHandlerOnChannel(_ channel: String, binaryMessageHandler: FlutterBinaryMessageHandler?) -> FlutterBinaryMessengerConnection { 1 }
  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
func check(_ value: @autoclosure () -> Bool, _ label: String) {
  if !value() { fatalError("FAIL: \(label)") }
  print("PASS: \(label)")
}
let folder = FileManager.default.temporaryDirectory.appendingPathComponent("clipshelf-tests-\(UUID().uuidString)")
final class MemoryPasteboard: ClipboardAccess {
  var changeCount = 0
  var pasteboardItems: [NSPasteboardItem]? = []
  var image: NSImage? {
    guard let data = pasteboardItems?.first?.data(forType: .png) else { return nil }
    return NSImage(data: data)
  }
  func string(forType type: NSPasteboard.PasteboardType) -> String? { pasteboardItems?.first?.string(forType: type) }
  @discardableResult func clearContents() -> Int { pasteboardItems = []; changeCount += 1; return changeCount }
  func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool {
    pasteboardItems = objects.compactMap { $0 as? NSPasteboardItem }
    changeCount += 1
    return pasteboardItems?.count == objects.count
  }
}
let systemBoard: NSPasteboard? = CommandLine.arguments.contains("--system-pasteboard")
  ? NSPasteboard(name: NSPasteboard.Name("clipshelf-tests-\(UUID().uuidString)")) : nil
let board: ClipboardAccess = systemBoard ?? MemoryPasteboard()
defer { systemBoard?.releaseGlobally(); try? FileManager.default.removeItem(at: folder) }
let storage = folder.appendingPathComponent("history.json")
let bridge = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: storage, pasteboard: board, startMonitoring: false)
func write(_ text: String, html: String? = nil, concealed: Bool = false) {
  let item = NSPasteboardItem()
  item.setString(text, forType: .string)
  if let html = html { item.setString(html, forType: .html) }
  if concealed { item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")) }
  board.clearContents(); check(board.writeObjects([item]), "write test pasteboard")
  bridge.capture()
}
func call(_ name: String, _ args: [String: Any] = [:]) -> Any? {
  var response: Any?
  bridge.handle(FlutterMethodCall(methodName: name, arguments: args)) { response = $0 }
  return response
}
write("Hello", html: "<b>Hello</b>")
check(bridge.archive.clips.count == 1, "capture text")
check(bridge.archive.clips[0].items[0][NSPasteboard.PasteboardType.html.rawValue] != nil, "preserve HTML representation")
write("Hello", html: "<b>Hello</b>")
check(bridge.archive.clips.count == 1, "deduplicate identical native payloads")
let id = bridge.archive.clips[0].id
_ = call("copy", ["id": id, "paste": false])
check(board.string(forType: .html) == "<b>Hello</b>", "restore rich representation")
_ = call("copy", ["id": id, "paste": false, "plain": true])
check(board.string(forType: .string) == "Hello" && board.string(forType: .html) == nil, "plain-text copy strips rich representations")
bridge.capture()
check(bridge.archive.clips.count == 1, "ignore self-generated clipboard writes")
write("secret", concealed: true)
check(bridge.archive.clips.count == 1, "skip concealed content")
_ = call("pause")
write("paused text")
check(bridge.archive.clips.count == 1, "pause capture")
_ = call("pause"); bridge.capture()
check(bridge.archive.clips.count == 1, "do not capture content copied during pause")
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4,
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let png = bitmap.representation(using: .png, properties: [:])!
let imageItem = NSPasteboardItem(); imageItem.setData(png, forType: .png)
board.clearContents(); _ = board.writeObjects([imageItem]); bridge.capture()
check(bridge.archive.clips[0].kind == "image" && bridge.archive.clips[0].preview != nil, "classify and preview image")
_ = call("copy", ["id": bridge.archive.clips[0].id, "paste": false])
check(board.pasteboardItems?.first?.data(forType: .png) == png, "restore original image bytes")
let fileA = NSPasteboardItem(); fileA.setString("file:///tmp/first.txt", forType: .fileURL)
let fileB = NSPasteboardItem(); fileB.setString("file:///tmp/second.txt", forType: .fileURL)
board.clearContents(); _ = board.writeObjects([fileA, fileB]); bridge.capture()
check(bridge.archive.clips[0].kind == "file" && bridge.archive.clips[0].items.count == 2, "capture multiple file references")
_ = call("copy", ["id": bridge.archive.clips[0].id, "paste": false])
check(board.pasteboardItems?.count == 2 && board.pasteboardItems?[1].string(forType: .fileURL) == "file:///tmp/second.txt", "restore multi-item order")
let count = bridge.archive.clips.count
let large = NSPasteboardItem(); large.setData(Data(repeating: 1, count: 10 * 1024 * 1024 + 1), forType: .string)
board.clearContents(); _ = board.writeObjects([large]); bridge.capture()
check(bridge.archive.clips.count == count && bridge.warning.contains("10 MB"), "skip oversized copies")
check(call("snippet", ["text": "   "]) is FlutterError, "reject empty snippet")
_ = call("snippet", ["title": "Signature", "text": "Best, Alex"])
check(bridge.archive.clips.first?.snippet == true, "save snippet")
_ = call("clear")
check(bridge.archive.clips.count == 1 && bridge.archive.clips[0].snippet, "clear preserves snippets")
let reloaded = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: storage, pasteboard: board, startMonitoring: false)
check(reloaded.archive.clips.first?.text == "Best, Alex", "reload persisted snippets")
let sample = Clip(id: "sample", title: "text", text: "text", kind: "text", source: "test", date: 1, snippet: false, items: [["public.utf8-plain-text": Data("text".utf8)]], preview: nil)
bridge.archive.clips.append(contentsOf: Array(repeating: sample, count: 205))
bridge.trim()
check(bridge.archive.clips.filter { !$0.snippet }.count == 200, "bound history at 200 without pruning snippets")
try Data("invalid archive".utf8).write(to: storage)
let recovered = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: storage, pasteboard: board, startMonitoring: false)
check(recovered.archive.paused, "pause on unreadable history")
let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
check(files.contains { $0.contains("unreadable-") }, "preserve unreadable archive backup")
// Pinboards preserve reusable items and round-trip independently of captured history.
let pinBridge = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: folder.appendingPathComponent("pin.json"), pasteboard: MemoryPasteboard(), startMonitoring: false)
func invoke(_ target: ClipboardBridge, _ method: String, _ args: [String: Any] = [:]) -> Any? {
  var value: Any?
  target.handle(FlutterMethodCall(methodName: method, arguments: args)) { value = $0 }
  return value
}
_ = invoke(pinBridge, "snippet", ["text":"Reusable reply"])
pinBridge.archive.clips[0].snippet = false; pinBridge.persist()
_ = invoke(pinBridge, "board", ["name":"Work", "color":2])
let pinnedID = pinBridge.archive.clips[0].id
let boardID = pinBridge.archive.boards![0].id
_ = invoke(pinBridge, "pin", ["id":pinnedID, "boardID":boardID])
_ = invoke(pinBridge, "clear")
check(pinBridge.archive.clips.count == 1 && pinBridge.archive.clips[0].boardID == boardID, "clear preserves pinned items")
let pinnedReload = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: folder.appendingPathComponent("pin.json"), pasteboard: MemoryPasteboard(), startMonitoring: false)
check(pinnedReload.archive.boards?.first?.name == "Work" && pinnedReload.archive.clips[0].boardID == boardID, "persist board membership")
_ = invoke(pinBridge, "deleteBoard", ["id":boardID])
check(pinBridge.archive.clips[0].boardID == nil && pinBridge.archive.boards?.isEmpty == true, "delete board preserves its contents")

// Simulate distinct Macs offline: item-level versions must merge without replacing the archive.
let macB = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: folder.appendingPathComponent("mac-b.json"), pasteboard: MemoryPasteboard(), startMonitoring: false)
_ = invoke(macB, "snippet", ["text":"Created on another Mac"])
macB.merge(pinBridge.envelopes())
check(macB.archive.clips.count == 2, "merge independent offline additions")
let old = macB.envelopes().first { $0.key == "clip-" + pinnedID }!
_ = invoke(macB, "delete", ["id":pinnedID])
let deletion = macB.envelopes().first { $0.key == old.key }!
check(deletion.stamp.deleted && deletion.clip == nil, "persist outgoing deletion tombstone")
pinBridge.merge([deletion])
check(pinBridge.archive.clips.isEmpty, "propagate deletion to other Mac")
pinBridge.merge([old])
check(pinBridge.archive.clips.isEmpty, "stale offline record cannot resurrect deleted item")
let mergedReload = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: folder.appendingPathComponent("pin.json"), pasteboard: MemoryPasteboard(), startMonitoring: false)
mergedReload.merge([old])
check(mergedReload.archive.clips.isEmpty, "deletion survives restart")
check(SyncStamp(time:1,author:"A",deleted:false) < SyncStamp(time:1,author:"B",deleted:false), "deterministic concurrent-write ordering")
check(SyncStamp(time:1,author:"Z",deleted:false) < SyncStamp(time:1,author:"A",deleted:true), "deletion wins an exact-time tie")
check(invoke(pinBridge, "sync", ["value":true]) is FlutterError, "unprovisioned build reports iCloud setup requirement")
// Original history file shape remains compatible with the expanded archive schema.
var oldFormat = try JSONSerialization.jsonObject(with: JSONEncoder().encode(macB.archive)) as! [String: Any]
oldFormat.removeValue(forKey:"versions"); oldFormat.removeValue(forKey:"boards"); oldFormat.removeValue(forKey:"syncEnabled")
let migrated = try JSONDecoder().decode(Archive.self, from: JSONSerialization.data(withJSONObject:oldFormat))
check(migrated.clips.count == 1 && migrated.syncEnabled == nil, "migrate archive without sync metadata")
pinBridge.archive.versions?["clip-evicted"] = SyncStamp(time:1, author:"other", deleted:false)
_ = invoke(pinBridge, "clear")
check(pinBridge.archive.versions?["clip-evicted"]?.deleted == true, "clear history also deletes known evicted cloud items")
let firstScreen = NSRect(x:0,y:0,width:1440,height:876)
let rightFrame = ClipboardBridge.quickFrame(anchor:NSRect(x:1420,y:876,width:20,height:24),visible:firstScreen)
check(firstScreen.contains(rightFrame) && rightFrame.width == 440, "menu-bar panel stays inside right screen edge")
let leftScreen = NSRect(x:-1280,y:100,width:1280,height:700)
let leftFrame = ClipboardBridge.quickFrame(anchor:NSRect(x:-1280,y:800,width:22,height:24),visible:leftScreen)
check(leftScreen.contains(leftFrame), "menu-bar panel supports displays with negative coordinates")
let smallScreen = NSRect(x:0,y:0,width:800,height:400)
let smallFrame = ClipboardBridge.quickFrame(anchor:NSRect(x:600,y:400,width:22,height:24),visible:smallScreen)
check(smallScreen.contains(smallFrame) && smallFrame.height < 560, "menu-bar panel fits a short display")
check(bridge.state()["presentation"] as? String == "shelf", "hotkey shelf remains the default presentation")
var permission = false
let permissionMessenger = Messenger()
let permissionBridge = ClipboardBridge(window:nil, messenger:permissionMessenger, storageURL:folder.appendingPathComponent("permission.json"), pasteboard:MemoryPasteboard(), startMonitoring:false, accessibilityCheck:{ permission })
check(permissionBridge.state()["accessibility"] as? Bool == false, "permission status starts denied")
permission = true; permissionBridge.refreshAccessibility()
check(permissionBridge.state()["accessibility"] as? Bool == true && permissionMessenger.messages == 1, "grant pushes a live permission update without a clipboard change")
permissionBridge.refreshAccessibility()
check(permissionMessenger.messages == 1, "unchanged permission does not repeatedly publish history")
permission = false; permissionBridge.refreshAccessibility()
check(permissionBridge.state()["accessibility"] as? Bool == false && permissionMessenger.messages == 2, "revocation pushes a live permission update")
print("All native checks passed.")

check(!FloatingPanelState.shouldDismiss(presentation: "floating", pinned: true), "pinned floating panel survives outside clicks")
check(FloatingPanelState.shouldDismiss(presentation: "floating", pinned: false), "unpinned floating panel dismisses")
check(FloatingPanelState.shouldDismiss(presentation: "quick", pinned: true) && FloatingPanelState.shouldDismiss(presentation: "shelf", pinned: true), "popup and shelf retain outside-click dismissal")
let secondaryScreen = NSRect(x: -1920, y: 100, width: 1920, height: 1000)
let restored = FloatingPanelState.restoredFrame(NSRect(x: 9000, y: -500, width: 5000, height: 8000), visible: secondaryScreen)
check(secondaryScreen.contains(restored), "disconnected monitor frame is clamped to available display")
let preferenceSuite = "clipshelf-floating-tests-\(UUID().uuidString)"
let preferences = UserDefaults(suiteName: preferenceSuite)!
defer { preferences.removePersistentDomain(forName: preferenceSuite) }
let floatingState = FloatingPanelState(defaults: preferences)
check(floatingState.pinned, "floating panel defaults to keep visible")
floatingState.pinned = false; floatingState.frame = NSRect(x: -500, y: 100, width: 440, height: 560)
let reopenedState = FloatingPanelState(defaults: preferences)
check(!reopenedState.pinned && reopenedState.frame == floatingState.frame, "floating position and pin preference survive reopening")
let widgetFolder = folder.appendingPathComponent("widget", isDirectory: true)
try FileManager.default.createDirectory(at: widgetFolder, withIntermediateDirectories: true)
let widgetStore = WidgetFavoritesStore(directory: widgetFolder)
let widgetSample = Clip(id: "favorite", title: "Greeting", text: "Hello 🌍", kind: "text", source: "Test", date: 0, snippet: true, items: [], preview: nil)
var historyOnly = widgetSample; historyOnly.id = "private-history"; historyOnly.snippet = false
var imageFavorite = widgetSample; imageFavorite.id = "image"; imageFavorite.kind = "image"
var longFavorite = widgetSample; longFavorite.id = "large"; longFavorite.text = String(repeating: "é", count: 5000)
var pinnedText = widgetSample; pinnedText.id = "pinned"; pinnedText.snippet = false; pinnedText.boardID = "work"
let widgetBoard = Pinboard(id: "work", name: "Work", color: 0)
let widgetSnapshot = WidgetLibraryExporter.snapshot(clips: [widgetSample, historyOnly, imageFavorite, longFavorite, pinnedText], boards: [widgetBoard], enabled: true)
check(widgetSnapshot.collections.first?.items.map(\.id) == ["favorite"], "widget excludes history, images and oversized text")
check(widgetSnapshot.collections.last?.items.map(\.id) == ["pinned"], "widget pinboard reuses saved text from the library")
let firstWidgetWrite = try widgetStore.write(widgetSnapshot)
let secondWidgetWrite = try widgetStore.write(widgetSnapshot)
check(firstWidgetWrite && !secondWidgetWrite, "unchanged favorites avoid repeated widget refreshes")
check(widgetStore.text(for: "favorite") == "Hello 🌍", "widget copy preserves exact Unicode text")
check(widgetStore.text(for: "large") == nil, "widget never copies silently truncated text")
try widgetStore.recordCopy(id: "favorite")
check(widgetStore.copiedID() == "favorite" && widgetStore.copiedID(now: Date().addingTimeInterval(20)) == nil, "widget copied feedback expires")
_ = try widgetStore.write(WidgetLibraryExporter.snapshot(clips: [widgetSample], boards: [widgetBoard], enabled: false))
check(widgetStore.read() == .empty && widgetStore.text(for: "favorite") == nil && widgetStore.copiedID() == nil, "disabling Favorites clears content and disables copy")
try Data("invalid".utf8).write(to: widgetFolder.appendingPathComponent("widget-favorites.json"))
check(widgetStore.read() == .empty, "unreadable widget snapshot fails closed")
let fallbackHome = folder.appendingPathComponent("home", isDirectory: true)
let fallbackStore = try WidgetFavoritesStore.accessibleStore(at: WidgetFavoritesStore.fallbackDirectory(home: fallbackHome.path))
check(fallbackStore.available && fallbackStore.directory?.path == fallbackHome.path + "/Library/Application Support/ClipShelf/Widget", "unsigned builds share Favorites through the Application Support folder")
_ = try fallbackStore.write(widgetSnapshot)
check(WidgetFavoritesStore(directory: fallbackStore.directory).text(for: "favorite") == "Hello 🌍", "widget reads what the host wrote to the fallback folder")
let widgetEntitlements = try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: "macos/ClipShelfWidgets/Widget.entitlements")), format: nil) as? [String: Any]
check((widgetEntitlements?["com.apple.security.temporary-exception.files.home-relative-path.read-write"] as? [String]) == ["/" + WidgetFavoritesStore.fallbackRelativePath + "/"], "widget sandbox exception matches the fallback folder")

let budgetBoards = (0..<30).map { Pinboard(id: "budget-\($0)", name: "Board \($0)", color: 0) }
let budgetClips: [Clip] = budgetBoards.flatMap { board in
  (0..<6).map { index -> Clip in
    var value = widgetSample; value.id = "\(board.id)-\(index)"; value.boardID = board.id
    value.snippet = false; value.text = String(repeating: "\u{0001}", count: 8192)
    return value
  }
}
let boundedWidget = WidgetLibraryExporter.snapshot(clips: budgetClips, boards: budgetBoards, enabled: true)
let boundedData = try JSONEncoder().encode(boundedWidget)
check(boundedData.count <= 2_000_000 && boundedWidget.collections.flatMap(\.items).count < budgetClips.count, "JSON escaping cannot exceed widget snapshot budget")
check(boundedWidget.collections.flatMap(\.items).allSatisfy { $0.text.utf8.count == 8192 }, "widget budget omits whole entries rather than truncating their text")

let menuPanelFrame = NSRect(x: -500, y: 100, width: 440, height: 560)
let statusButtonFrame = NSRect(x: -160, y: 700, width: 24, height: 24)
let childMenuFrame = NSRect(x: -100, y: 400, width: 180, height: 200)
check(!PanelDismissalPolicy.isOutside(NSPoint(x: -80, y: 630), panelFrame: menuPanelFrame, ownedFrames: []), "globally delivered More button click inside panel does not dismiss it")
check(!PanelDismissalPolicy.isOutside(NSPoint(x: -150, y: 710), panelFrame: menuPanelFrame, ownedFrames: [statusButtonFrame]), "status icon click belongs to the panel toggle")
check(!PanelDismissalPolicy.isOutside(NSPoint(x: 50, y: 500), panelFrame: menuPanelFrame, ownedFrames: [childMenuFrame]), "owned child menu beyond panel bounds remains interactive")
check(PanelDismissalPolicy.isOutside(NSPoint(x: 250, y: 200), panelFrame: menuPanelFrame, ownedFrames: [statusButtonFrame, childMenuFrame]), "a real outside click still dismisses the transient panel")
check(!PanelDismissalPolicy.shouldDismissAfterFocusChange(ownsFocus: true, presentation: "quick", pinned: false), "app activation changes cannot hide a key quick panel")
check(PanelDismissalPolicy.shouldDismissAfterFocusChange(ownsFocus: false, presentation: "quick", pinned: true), "genuine focus loss still dismisses quick panel")
check(!PanelDismissalPolicy.shouldDismissAfterFocusChange(ownsFocus: false, presentation: "floating", pinned: true), "focus changes preserve pinned floating behavior")
check(PanelDismissalPolicy.shouldDismissAfterFocusChange(ownsFocus: false, presentation: "floating", pinned: false), "unpinned floating panel follows normal focus dismissal")

let localGroup = "ABCDE12345.clipshelf"
check(WidgetFavoritesStore.authorizes(group: localGroup, memberships: [localGroup], signingTeam: "ABCDE12345"), "macOS Team-ID group accepts its actual signing team")
check(!WidgetFavoritesStore.authorizes(group: localGroup, memberships: [localGroup], signingTeam: "OTHER12345"), "macOS Team-ID group rejects a different signer")
check(!WidgetFavoritesStore.authorizes(group: localGroup, memberships: [], signingTeam: "ABCDE12345"), "widget group still requires signed membership")
check(!WidgetFavoritesStore.authorizes(group: localGroup, memberships: [localGroup], signingTeam: nil), "ad-hoc signature cannot claim a Team-ID group")
check(WidgetFavoritesStore.authorizes(group: "group.example.clipshelf", memberships: ["group.example.clipshelf"], signingTeam: "ABCDE12345"), "provisioned group format remains supported")
check(!WidgetFavoritesStore.authorizes(group: "group.", memberships: ["group."], signingTeam: nil), "empty group suffix is rejected")
let probeFolder = folder.appendingPathComponent("access-probe")
let accessibleWidgetStore = try WidgetFavoritesStore.accessibleStore(at: probeFolder)
let probeContents = try FileManager.default.contentsOfDirectory(atPath: probeFolder.path)
check(accessibleWidgetStore.available && probeContents.isEmpty, "shared folder probe establishes access and removes its empty test file")
let blockedFolder = folder.appendingPathComponent("not-a-directory")
try Data().write(to: blockedFolder)
do {
  _ = try WidgetFavoritesStore.accessibleStore(at: blockedFolder)
  check(false, "unusable group directory must not enable widget storage")
} catch { check(true, "unusable group directory does not enable widget storage") }

// Saved screenshots are new marked files, never historical screenshots or generic photos.
let screenshotNow = Date()
func screenshotFile(_ name: String, size: Int = 10, modified: Date = screenshotNow, created: Date = screenshotNow, marked: Bool = true) -> ScreenshotFile {
  ScreenshotFile(url: folder.appendingPathComponent(name), key: name, size: size, modified: modified, created: created, marked: marked)
}
let screenshotTracker = ScreenshotFileTracker()
let oldScreenshot = screenshotFile("old.png", created: screenshotNow.addingTimeInterval(-100))
screenshotTracker.reset([oldScreenshot], now: screenshotNow)
check(screenshotTracker.observe([oldScreenshot], clipboardVersion: { 1 }).isEmpty, "existing screenshots are not imported at startup")
let partialScreenshot = screenshotFile("new.png", size: 0)
let completedScreenshot = screenshotFile("new.png", size: 20, modified: screenshotNow.addingTimeInterval(1))
check(screenshotTracker.observe([oldScreenshot, partialScreenshot], clipboardVersion: { 7 }).isEmpty, "partially written screenshot waits")
check(screenshotTracker.observe([oldScreenshot, completedScreenshot], clipboardVersion: { 8 }).isEmpty, "changed image size needs another stable sample")
let readyScreenshots = screenshotTracker.observe([oldScreenshot, completedScreenshot], clipboardVersion: { 9 })
check(readyScreenshots.count == 1 && readyScreenshots[0].1 == 7, "stable screenshot retains its initial clipboard version")
check(screenshotTracker.observe([completedScreenshot], clipboardVersion: { 10 }).isEmpty, "a saved screenshot is imported once")
let ordinaryPhoto = screenshotFile("Screenshot-lookalike.png", marked: false)
for _ in 0..<4 { check(screenshotTracker.observe([completedScreenshot, ordinaryPhoto], clipboardVersion: { 10 }).isEmpty, "image name alone is not a screenshot marker") }
let lateMarkedScreenshot = screenshotFile("Screenshot-lookalike.png", marked: true)
check(screenshotTracker.observe([completedScreenshot, lateMarkedScreenshot], clipboardVersion: { 11 }).count == 1, "late screenshot metadata is retried")
let historicalMovedScreenshot = screenshotFile("moved-old.png", created: screenshotNow.addingTimeInterval(-100))
_ = screenshotTracker.observe([historicalMovedScreenshot], clipboardVersion: { 12 })
check(screenshotTracker.observe([historicalMovedScreenshot], clipboardVersion: { 13 }).isEmpty, "moving a historical screenshot into the folder does not backfill it")
screenshotTracker.reset([completedScreenshot], now: screenshotNow)
check(screenshotTracker.observe([completedScreenshot], clipboardVersion: { 14 }).isEmpty, "resuming screenshot capture resets the baseline")

let screenshotFolder = folder.appendingPathComponent("screenshots", isDirectory: true)
try FileManager.default.createDirectory(at: screenshotFolder, withIntermediateDirectories: true)
func markScreenshot(_ url: URL) throws {
  let marker = try PropertyListSerialization.data(fromPropertyList: true, format: .binary, options: 0)
  let code = marker.withUnsafeBytes { bytes in setxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", bytes.baseAddress, bytes.count, 0, 0) }
  if code != 0 { throw POSIXError(.EACCES) }
}
let screenshotURL = screenshotFolder.appendingPathComponent("new-shot.png")
try png.write(to: screenshotURL); try markScreenshot(screenshotURL)
let photoURL = screenshotFolder.appendingPathComponent("photo.png")
try png.write(to: photoURL)
let imageLink = screenshotFolder.appendingPathComponent("link.png")
try FileManager.default.createSymbolicLink(at: imageLink, withDestinationURL: screenshotURL)
let screenshotEntries = try ScreenshotMonitor.files(in: screenshotFolder)
check(screenshotEntries.count == 2 && screenshotEntries.first(where: { $0.url.resolvingSymlinksInPath() == screenshotURL.resolvingSymlinksInPath() })?.marked == true, "file discovery reads screenshot metadata and skips symlinks")
check(screenshotEntries.first(where: { $0.url.resolvingSymlinksInPath() == photoURL.resolvingSymlinksInPath() })?.marked == false, "ordinary image files remain unmarked")
let screenshotEntry = screenshotEntries.first { $0.url.resolvingSymlinksInPath() == screenshotURL.resolvingSymlinksInPath() }!
let screenshotPayload = try ScreenshotImage.load(screenshotEntry)
check(!screenshotPayload.png.isEmpty && !screenshotPayload.preview.isEmpty && screenshotPayload.fingerprint != nil, "screenshot decoding prepares original image, preview and duplicate fingerprint")
let largeScreenshot = ScreenshotFile(url: screenshotURL, key: "large", size: ScreenshotImage.maximumBytes + 1, modified: screenshotNow, created: screenshotNow, marked: true)
do { _ = try ScreenshotImage.load(largeScreenshot); check(false, "oversized screenshot must be rejected") }
catch { check(true, "oversized screenshot leaves the original file untouched") }

let screenshotPreferenceSuite = "clipshelf-screenshots-\(UUID().uuidString)"
let screenshotDefaults = UserDefaults(suiteName: screenshotPreferenceSuite)!
defer { screenshotDefaults.removePersistentDomain(forName: screenshotPreferenceSuite) }
let screenshotBoard = MemoryPasteboard()
let screenshotBridge = ClipboardBridge(window: nil, messenger: Messenger(), storageURL: folder.appendingPathComponent("screenshot-library.json"), pasteboard: screenshotBoard, startMonitoring: false, screenshotPreferences: screenshotDefaults)
screenshotBridge.importScreenshot(screenshotPayload, clipboardVersion: screenshotBoard.changeCount)
check(screenshotBoard.pasteboardItems?.first?.data(forType: .png) == screenshotPayload.png, "file screenshot is copied to the system clipboard boundary")
check(screenshotBridge.archive.clips.count == 1 && screenshotBridge.archive.clips[0].kind == "image" && screenshotBridge.archive.clips[0].source == "Screenshot", "saved screenshot becomes a regular image history entry")
screenshotBridge.capture()
check(screenshotBridge.archive.clips.count == 1, "automatic screenshot write is not captured twice")
let clipboardImage = NSPasteboardItem(); clipboardImage.setData(png, forType: .png)
screenshotBoard.clearContents(); _ = screenshotBoard.writeObjects([clipboardImage]); screenshotBridge.capture()
check(screenshotBridge.archive.clips.count == 1, "clipboard and file representations of the same screenshot are deduplicated")
let staleClipboardVersion = screenshotBoard.changeCount
let newerCopy = NSPasteboardItem(); newerCopy.setString("Newer clipboard text", forType: .string)
screenshotBoard.clearContents(); _ = screenshotBoard.writeObjects([newerCopy])
screenshotBridge.importScreenshot(screenshotPayload, clipboardVersion: staleClipboardVersion)
check(screenshotBoard.string(forType: .string) == "Newer clipboard text", "a newer user copy is not overwritten while a screenshot finishes")
check(screenshotBridge.archive.clips.first?.text == "Newer clipboard text" && screenshotBridge.archive.clips.contains(where: { $0.kind == "image" }), "newer clipboard content stays first while screenshot is retained in history")
let countBeforePausedScreenshot = screenshotBridge.archive.clips.count
screenshotBridge.archive.paused = true
screenshotBridge.importScreenshot(screenshotPayload, clipboardVersion: screenshotBoard.changeCount)
check(screenshotBridge.archive.clips.count == countBeforePausedScreenshot, "pause suppresses automatic screenshot import")
screenshotBridge.archive.paused = false; screenshotDefaults.set(false, forKey: "copyScreenshots")
screenshotBridge.importScreenshot(screenshotPayload, clipboardVersion: screenshotBoard.changeCount)
check(screenshotBridge.archive.clips.count == countBeforePausedScreenshot, "disabling screenshot copying suppresses screenshot imports")
let preservedScreenshotBytes = try Data(contentsOf: screenshotURL)
check(preservedScreenshotBytes == png, "screenshot import never removes or changes the original file")

// A real directory event is exercised in an isolated fixture folder.
let eventFolder = folder.appendingPathComponent("screenshot-events", isDirectory: true)
try FileManager.default.createDirectory(at: eventFolder, withIntermediateDirectories: true)
var screenshotWatcherReady = false
var observedScreenshotEvents = 0
let fixtureWatcher = ScreenshotMonitor(clipboardVersion: { 123 }, receive: { image, version in
  if version == 123 && !image.png.isEmpty { observedScreenshotEvents += 1 }
}, status: { active, _ in screenshotWatcherReady = active })
fixtureWatcher.start(eventFolder)
let watcherStartDeadline = Date().addingTimeInterval(3)
while !screenshotWatcherReady && Date() < watcherStartDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
check(screenshotWatcherReady, "screenshot folder event watcher starts")
let eventScreenshot = eventFolder.appendingPathComponent("event.png")
try png.write(to: eventScreenshot); try markScreenshot(eventScreenshot)
let watcherEventDeadline = Date().addingTimeInterval(5)
while observedScreenshotEvents == 0 && Date() < watcherEventDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
check(observedScreenshotEvents == 1, "real saved-file event imports the marked screenshot once")
fixtureWatcher.stop()
