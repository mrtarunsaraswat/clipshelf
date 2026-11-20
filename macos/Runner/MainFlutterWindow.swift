import Cocoa
import FlutterMacOS
import Carbon
import ApplicationServices
import CloudKit
import WidgetKit

// Keeps clipboard logic testable without accessing the user's system clipboard.
protocol ClipboardAccess {
  var changeCount: Int { get }
  var pasteboardItems: [NSPasteboardItem]? { get }
  var image: NSImage? { get }
  func string(forType type: NSPasteboard.PasteboardType) -> String?
  @discardableResult func clearContents() -> Int
  func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool
}
extension NSPasteboard: ClipboardAccess {
  var image: NSImage? { NSImage(pasteboard: self) }
}

struct Clip: Codable {
  var id: String
  var title: String
  var text: String
  var kind: String
  var source: String
  var date: Double
  var snippet: Bool
  var items: [[String: Data]]
  var preview: Data?
  var boardID: String? = nil
  var retained: Bool { snippet || boardID != nil }
  var size: Int { items.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } }
}
struct Pinboard: Codable {
  var id: String
  var name: String
  var color: Int
}
struct SyncStamp: Codable, Equatable, Comparable {
  var time: Double
  var author: String
  var deleted: Bool
  static func < (a: SyncStamp, b: SyncStamp) -> Bool {
    if a.time != b.time { return a.time < b.time }
    if a.deleted != b.deleted { return !a.deleted && b.deleted }
    return a.author < b.author
  }
}
struct SyncEnvelope: Codable {
  var key: String
  var stamp: SyncStamp
  var clip: Clip?
  var board: Pinboard?
}
struct Archive: Codable {
  var clips: [Clip] = []
  var paused = false
  var boards: [Pinboard]? = nil
  var versions: [String: SyncStamp]? = nil
  var syncEnabled: Bool? = nil
}

/// Maps ⌘ plus a top-row digit to a quick-use index (⌘1 → 0 … ⌘9 → 8). Uses key
/// codes, not characters, so layouts that need Shift for digits still work.
enum QuickUseKey {
  static let digitKeyCodes: [UInt16] = [
    UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3), UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5),
    UInt16(kVK_ANSI_6), UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9),
  ]
  static func index(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Int? {
    let relevant = modifiers.intersection([.command, .shift, .option, .control])
    guard relevant == .command else { return nil }
    return digitKeyCodes.firstIndex(of: keyCode)
  }
  static func index(for event: NSEvent) -> Int? {
    guard event.type == .keyDown else { return nil }
    return index(keyCode: event.keyCode, modifiers: event.modifierFlags)
  }
}

class MainFlutterWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
  private var bridge: ClipboardBridge?
  /// The Flutter view sits inside a frosted NSVisualEffectView, so it is not the
  /// window's contentViewController; keep it for first-responder handling.
  private(set) var flutterView: NSView?
  private var flutterController: FlutterViewController?
  /// ⌘1–⌘9 must reach the panel even while Flutter's search field is the first
  /// responder, where AppKit's text handling can swallow ⌘-number keys.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if let index = QuickUseKey.index(for: event) {
      bridge?.quickUse(index)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
  func openClipShelfURL(_ url: URL) {
    guard url.scheme == "clipshelf", url.host == "open" else { return }
    let view = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "view" }?.value
    if view == "floating" { bridge?.showFloating() } else { bridge?.show() }
  }
  override func awakeFromNib() {
    let controller = FlutterViewController()
    // Native glass: a behind-window blur shows through Flutter's transparent canvas.
    // AppKit swaps in an opaque material by itself when Reduce Transparency is on.
    controller.backgroundColor = .clear
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    let glass = NSVisualEffectView()
    glass.material = .popover
    glass.blendingMode = .behindWindow
    glass.state = .active  // a non-activating panel must not fall back to the inactive look
    controller.view.frame = glass.bounds
    controller.view.autoresizingMask = [.width, .height]
    glass.addSubview(controller.view)
    contentView = glass
    flutterView = controller.view
    flutterController = controller
    setContentSize(NSSize(width: 1120, height: 430))
    minSize = NSSize(width: 880, height: 360)
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.formUnion([.fullSizeContentView, .nonactivatingPanel])
    becomesKeyOnlyIfNeeded = false
    hidesOnDeactivate = false
    initialFirstResponder = controller.view
    standardWindowButton(.closeButton)?.isHidden = true
    standardWindowButton(.miniaturizeButton)?.isHidden = true
    standardWindowButton(.zoomButton)?.isHidden = true
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    title = "ClipShelf"
    isReleasedWhenClosed = false
    center()
    RegisterGeneratedPlugins(registry: controller)
    bridge = ClipboardBridge(window: self, messenger: controller.engine.binaryMessenger)
    super.awakeFromNib()
  }
}

final class ClipboardBridge: NSObject {
  weak var window: NSWindow?
  let channel: FlutterMethodChannel
  var archive = Archive()
  var screenshotMonitor: ScreenshotMonitor?
  let screenshotPreferences: UserDefaults
  let monitoringEnabled: Bool
  var screenshotScope: URL?
  var screenshotRun = UUID()
  var screenshotFolderPath = ""
  var screenshotStatus = "Automatic screenshot copying is starting."
  var screenshotWatching = false
  var screenshotPreferenceTicks = 0
  var recentImageFingerprint: Data?
  var recentImageID: String?
  var recentImageDate: Double = 0
  var timer: Timer?
  var outsideClickMonitor: Any?
  var localClickMonitor: Any?
  var panelGeneration = 0
  let checkAccessibility: () -> Bool
  var accessibilityGranted: Bool
  var status: NSStatusItem?
  var statusMenu: NSMenu?
  var presentation = "shelf"
  let floating = FloatingPanelState()
  var dragEvent: NSEvent?
  var widgetSharing: Bool { UserDefaults.standard.bool(forKey: "widgetSharing") }
  var widgetStore: WidgetFavoritesStore { WidgetFavoritesStore.live() }
  var shelfHeight: CGFloat = 430
  var hotKey: EventHotKeyRef?
  var handler: EventHandlerRef?
  var previousApp: NSRunningApplication?
  let pasteboard: ClipboardAccess
  var change: Int
  var warning = ""
  let location: URL
  var storageReady = true
  var lastSnapshot: [String: Data] = [:]
  var cloud: CloudSync?
  var cloudStatus = "iCloud sync is off"
  let deviceID: String = {
    let defaults = UserDefaults.standard
    if let value = defaults.string(forKey: "ClipShelfDeviceID") { return value }
    let value = UUID().uuidString
    defaults.set(value, forKey: "ClipShelfDeviceID")
    return value
  }()
  var cloudIdentifier: String {
    let value = Bundle.main.object(forInfoDictionaryKey: "ClipShelfCloudContainer") as? String ?? ""
    return value.hasPrefix("iCloud.") ? value : ""
  }

  init(window: NSWindow?, messenger: FlutterBinaryMessenger, storageURL: URL? = nil,
       pasteboard: ClipboardAccess = NSPasteboard.general, startMonitoring: Bool = true,
       screenshotPreferences: UserDefaults = .standard,
       accessibilityCheck: @escaping () -> Bool = {
         AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary)
       }) {
    self.window = window
    self.screenshotPreferences = screenshotPreferences
    self.monitoringEnabled = startMonitoring
    checkAccessibility = accessibilityCheck
    accessibilityGranted = accessibilityCheck()
    self.pasteboard = pasteboard
    change = pasteboard.changeCount
    channel = FlutterMethodChannel(name: "clipshelf/native", binaryMessenger: messenger)
    location = storageURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("ClipShelf/history.json")
    super.init()
    do {
      if FileManager.default.fileExists(atPath: location.path) {
        archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: location))
      }
    } catch {
      archive.paused = true
      let backup = location.deletingPathExtension().appendingPathExtension("unreadable-\(Int(Date().timeIntervalSince1970)).json")
      do {
        try FileManager.default.copyItem(at: location, to: backup)
        warning = "History could not be loaded. A backup was saved alongside history.json. Capture is paused."
      } catch {
        storageReady = false
        warning = "History could not be loaded or backed up. Capture is paused; changes cannot be saved. The existing file is untouched."
      }
    }
    lastSnapshot = entityData()
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    guard startMonitoring else { return }
    status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    status?.button?.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipShelf")
    let menu = NSMenu()
    menu.addItem(withTitle: "Open ClipShelf   ⌥⌘V", action: #selector(show), keyEquivalent: "").target = self
    menu.addItem(withTitle: "Open floating panel", action: #selector(showFloating), keyEquivalent: "").target = self
    menu.addItem(withTitle: "Pause / resume capture", action: #selector(togglePause), keyEquivalent: "").target = self
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit ClipShelf", action: #selector(quit), keyEquivalent: "q").target = self
    statusMenu = menu
    status?.button?.target = self
    status?.button?.action = #selector(statusClicked)
    status?.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    status?.button?.toolTip = "ClipShelf — click to paste from history"
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
      guard let pointer = pointer else { return OSStatus(eventNotHandledErr) }
      let bridge = Unmanaged<ClipboardBridge>.fromOpaque(pointer).takeUnretainedValue()
      DispatchQueue.main.async { bridge.show() }
      return noErr
    }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    let result = RegisterEventHotKey(UInt32(kVK_ANSI_V), UInt32(cmdKey | optionKey),
      EventHotKeyID(signature: 0x434C4950, id: 1), GetApplicationEventTarget(), 0, &hotKey)
    if result != noErr { warning = "⌥⌘V is unavailable. Use the menu bar icon to open ClipShelf." }
    timer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { [weak self] _ in
      self?.refreshAccessibility()
      self?.capture()
      self?.refreshScreenshotFolderIfNeeded()
    }
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appResigned), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(refreshAccessibility), name: NSApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(panelBecameKey), name: NSWindow.didBecomeKeyNotification, object: window)
    rememberTarget()
    NotificationCenter.default.addObserver(self, selector: #selector(panelFocusMayHaveChanged), name: NSApplication.didResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(saveFloatingFrame), name: NSWindow.didMoveNotification, object: window)
    NotificationCenter.default.addObserver(self, selector: #selector(saveFloatingFrame), name: NSWindow.didEndLiveResizeNotification, object: window)
    NotificationCenter.default.addObserver(self, selector: #selector(appearanceSettingsChanged), name: NSColor.systemColorsDidChangeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appearanceSettingsChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    updateWidget()
    positionShelf()
    // Nib-driven startup shows this window without going through presentPanel().
    startOutsideClickMonitoring()
    DispatchQueue.main.async { [weak self] in
      guard let self = self, self.window?.isVisible == true else { return }
      self.startOutsideClickMonitoring()
    }
    configureScreenshots()
    if archive.syncEnabled == true { configureCloud() }
  }
  deinit {
    NotificationCenter.default.removeObserver(self)
    NSWorkspace.shared.notificationCenter.removeObserver(self)
    cloud?.stop()
    stopOutsideClickMonitoring()
    screenshotMonitor?.stop()
    screenshotScope?.stopAccessingSecurityScopedResource()
    timer?.invalidate()
    if let key = hotKey { UnregisterEventHotKey(key) }
    if let handler = handler { RemoveEventHandler(handler) }
  }
  @objc func appActivated(_ notification: Notification) {
    guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
    previousApp = app
    panelFocusMayHaveChanged()
    refreshAccessibility()
  }
  @objc func refreshAccessibility() {
    let granted = checkAccessibility()
    guard granted != accessibilityGranted else { return }
    accessibilityGranted = granted
    publish()
  }
  @objc func panelBecameKey() {
    refreshAccessibility()
    startOutsideClickMonitoring()
  }
  func startOutsideClickMonitoring() {
    if outsideClickMonitor == nil {
      outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
        guard let self = self, self.isOutsidePanel(at: NSEvent.mouseLocation) else { return }
        self.dismissIfTransient()
      }
    }
    if localClickMonitor == nil {
      localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
        self?.dragEvent = event
        if self?.isOutsidePanel(event) == true { self?.dismissIfTransient() }
        // Dismissal must not consume the click intended for another window.
        return event
      }
    }
  }
  func stopOutsideClickMonitoring() {
    if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor); outsideClickMonitor = nil }
    if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor); localClickMonitor = nil }
  }
  func isPanelWindow(_ candidate: NSWindow?) -> Bool {
    guard let panel = window, var candidate = candidate else { return false }
    var visited = Set<Int>()
    while visited.insert(candidate.windowNumber).inserted {
      if candidate === panel { return true }
      guard let parent = candidate.parent ?? candidate.sheetParent else { return false }
      candidate = parent
    }
    return false
  }
  func isOutsidePanel(at point: NSPoint) -> Bool {
    guard let panel = window, panel.isVisible else { return false }
    var ownedFrames = NSApp.windows.filter { $0.isVisible && isPanelWindow($0) }.map(\.frame)
    if let button = status?.button, let barWindow = button.window {
      ownedFrames.append(barWindow.convertToScreen(button.convert(button.bounds, to: nil)))
    }
    return PanelDismissalPolicy.isOutside(point, panelFrame: panel.frame, ownedFrames: ownedFrames)
  }
  func isOutsidePanel(_ event: NSEvent) -> Bool {
    if let clicked = event.window {
      if isPanelWindow(clicked) || clicked === status?.button?.window { return false }
      // Native menus can extend beyond the panel's frame.
      if clicked.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return false }
    }
    return isOutsidePanel(at: NSEvent.mouseLocation)
  }
  @objc func panelFocusMayHaveChanged() {
    let generation = panelGeneration
    // App activation is not key focus for a nonactivating NSPanel. Let AppKit finish
    // focus transfer before deciding, and never let an old notification hide a new session.
    DispatchQueue.main.async { [weak self] in
      guard let self = self, generation == self.panelGeneration,
        let panel = self.window, panel.isVisible else { return }
      let keyWindow = NSApp.keyWindow
      let ownsFocus = panel.isKeyWindow || self.isPanelWindow(keyWindow) ||
        (keyWindow?.level.rawValue ?? 0) >= NSWindow.Level.popUpMenu.rawValue
      if PanelDismissalPolicy.shouldDismissAfterFocusChange(ownsFocus: ownsFocus,
          presentation: self.presentation, pinned: self.floating.pinned) { self.dismissPanel() }
    }
  }
  func dismissIfTransient() {
    if FloatingPanelState.shouldDismiss(presentation: presentation, pinned: floating.pinned) { dismissPanel() }
  }
  @objc func saveFloatingFrame() {
    if presentation == "floating" { floating.frame = window?.frame }
  }
  @objc func showFloating() {
    rememberTarget()
    if presentation == "shelf" { shelfHeight = window?.frame.height ?? 430 }
    presentation = "floating"
    if let window = window, let screen = window.screen ?? NSScreen.main {
      window.minSize = NSSize(width: 360, height: 360)
      let saved = floating.frame
      let visible = NSScreen.screens.first { $0.visibleFrame.intersects(saved ?? .zero) }?.visibleFrame ?? screen.visibleFrame
      window.setFrame(FloatingPanelState.restoredFrame(saved, visible: visible), display: true)
    }
    presentPanel()
    channel.invokeMethod("opened", arguments: "floating")
    publish()
  }
  func dismissPanel() {
    let wasVisible = window?.isVisible == true
    panelGeneration += 1
    saveFloatingFrame()
    window?.orderOut(nil)
    stopOutsideClickMonitoring()
    if wasVisible { channel.invokeMethod("closed", arguments: nil) }
  }
  func presentPanel() {
    panelGeneration += 1
    refreshAccessibility()
    window?.makeKeyAndOrderFront(nil)
    if let window = window { window.makeFirstResponder((window as? MainFlutterWindow)?.flutterView ?? window.contentView) }
    startOutsideClickMonitoring()
  }
  func rememberTarget() {
    if let active = NSWorkspace.shared.frontmostApplication,
      active.processIdentifier != ProcessInfo.processInfo.processIdentifier { previousApp = active }
  }
  @objc func statusClicked() {
    rememberTarget()
    if NSApp.currentEvent?.type == .rightMouseUp, let button = status?.button, let menu = statusMenu {
      menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
      return
    }
    if presentation == "floating", window?.isVisible == true { presentPanel(); return }
    if presentation == "quick", window?.isVisible == true {
      dismissPanel(); return
    }
    showQuick()
  }
  static func quickFrame(anchor: NSRect, visible: NSRect) -> NSRect {
    let width = min(440, visible.width - 16)
    let height = min(560, visible.height - 16)
    let x = min(max(anchor.midX - width / 2, visible.minX + 8), visible.maxX - width - 8)
    let y = max(visible.minY + 8, min(anchor.minY - height - 8, visible.maxY - height - 8))
    return NSRect(x: x, y: y, width: width, height: height)
  }
  func showQuick() {
    saveFloatingFrame()
    rememberTarget()
    if presentation == "shelf" { shelfHeight = window?.frame.height ?? 430 }
    presentation = "quick"
    if let button = status?.button, let barWindow = button.window, let window = window {
      let anchor = barWindow.convertToScreen(button.convert(button.bounds, to: nil))
      let screen = barWindow.screen ?? NSScreen.main
      if let visible = screen?.visibleFrame {
        window.minSize = NSSize(width: 320, height: 320)
        window.setFrame(Self.quickFrame(anchor: anchor, visible: visible), display: true)
      }
    }
    presentPanel()
    channel.invokeMethod("opened", arguments: "quick")
    publish()
  }
  @objc func appResigned() { dismissIfTransient() }
  @objc func quit() { NSApp.terminate(nil) }
  @objc func togglePause() { archive.paused.toggle(); configureScreenshots(); persist(); publish() }
  @objc func show() {
    saveFloatingFrame()
    rememberTarget()
    let wasQuick = presentation != "shelf"
    presentation = "shelf"
    window?.minSize = NSSize(width: 880, height: 360)
    if wasQuick, let window = window {
      window.setContentSize(NSSize(width: 1120, height: shelfHeight))
    }
    positionShelf()
    presentPanel()
    channel.invokeMethod("opened", arguments: "shelf")
    publish()
  }
  func positionShelf() {
    guard let window = window,
      let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
    let visible = screen.visibleFrame
    let height = min(max(window.frame.height, 360), visible.height * 0.7)
    window.setFrame(NSRect(x: visible.minX + 12, y: visible.minY + 12,
      width: max(600, visible.width - 24), height: height), display: true)
  }
  func entityData() -> [String: Data] {
    var records: [String: Data] = [:]
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    for clip in archive.clips { records["clip-" + clip.id] = try? encoder.encode(clip) }
    for board in archive.boards ?? [] { records["board-" + board.id] = try? encoder.encode(board) }
    return records
  }
  func envelopes() -> [SyncEnvelope] {
    var versions = archive.versions ?? [:]
    for key in entityData().keys where versions[key] == nil {
      versions[key] = SyncStamp(time: Date().timeIntervalSince1970, author: deviceID, deleted: false)
    }
    archive.versions = versions
    return versions.map { key, stamp in
      SyncEnvelope(key: key, stamp: stamp,
        clip: archive.clips.first { "clip-" + $0.id == key },
        board: (archive.boards ?? []).first { "board-" + $0.id == key })
    }
  }
  func merge(_ records: [SyncEnvelope]) {
    var versions = archive.versions ?? [:]
    for record in records {
      guard versions[record.key].map({ $0 < record.stamp }) ?? true else { continue }
      if record.key.hasPrefix("clip-") {
        if !record.stamp.deleted {
          guard let clip = record.clip, record.key == "clip-" + clip.id,
            clip.size <= 10 * 1024 * 1024 else { continue }
        }
        archive.clips.removeAll { "clip-" + $0.id == record.key }
        if !record.stamp.deleted, let clip = record.clip { archive.clips.append(clip) }
      } else if record.key.hasPrefix("board-") {
        if !record.stamp.deleted {
          guard let board = record.board, record.key == "board-" + board.id,
            !board.name.isEmpty, board.name.count <= 48 else { continue }
        }
        var boards = archive.boards ?? []
        boards.removeAll { "board-" + $0.id == record.key }
        if !record.stamp.deleted, let board = record.board { boards.append(board) }
        archive.boards = boards
      } else { continue }
      versions[record.key] = record.stamp
    }
    archive.versions = versions
    archive.clips.sort { $0.date > $1.date }
    persist(trackChanges: false)
    var repaired = false
    for i in archive.clips.indices {
      if let boardID = archive.clips[i].boardID, versions["board-" + boardID]?.deleted == true {
        archive.clips[i].boardID = nil; repaired = true
      }
    }
    if repaired { persist() }
    // Enforce local limits after merging. Local retention is not a deletion on other Macs.
    trim(); persist(trackChanges: false)
    publish()
  }
  func configureCloud() {
    guard !cloudIdentifier.isEmpty else {
      archive.syncEnabled = false; cloudStatus = "This build needs iCloud provisioning"; return
    }
    cloud = CloudSync(identifier: cloudIdentifier,
      snapshot: { [weak self] in self?.envelopes() ?? [] },
      receive: { [weak self] records in self?.merge(records) },
      status: { [weak self] text in self?.cloudStatus = text; self?.publish() },
      accountChanged: { [weak self] in
        guard let self = self else { return }
        self.cloud?.stop(); self.cloud = nil; self.archive.syncEnabled = false
        self.cloudStatus = "iCloud account changed. Review your account, then enable sync again."
        self.persist(); self.publish()
      })
    _ = envelopes(); persist(); cloud?.schedule()
  }
  func persist(trackChanges: Bool = true) {
    guard storageReady else { return }
    let current = entityData()
    if trackChanges {
      var versions = archive.versions ?? [:]
      for key in Set(current.keys).union(lastSnapshot.keys) where current[key] != lastSnapshot[key] {
        let previous = versions[key]?.time ?? 0
        versions[key] = SyncStamp(time: max(Date().timeIntervalSince1970, previous + 0.001),
          author: deviceID, deleted: current[key] == nil)
      }
      archive.versions = versions
    }
    lastSnapshot = current
    do {
      let folder = location.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      let data = try JSONEncoder().encode(archive)
      try data.write(to: location, options: .atomic)
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: location.path)
    } catch { warning = "Changes are in memory only: local history could not be saved." }
    updateWidget()
    if trackChanges { cloud?.schedule() }
  }
  func state() -> [String: Any] {
    accessibilityGranted = checkAccessibility()
    return ["clips": archive.clips.map { clip -> [String: Any] in
      var value: [String: Any] = ["id": clip.id, "title": clip.title, "text": clip.text,
        "kind": clip.kind, "source": clip.source, "date": clip.date, "snippet": clip.snippet, "boardID": clip.boardID ?? "",
        "size": clip.size, "formats": Array(Set(clip.items.flatMap { $0.keys })).sorted()]
      if let preview = clip.preview { value["preview"] = FlutterStandardTypedData(bytes: preview) }
      return value
    }, "paused": archive.paused,
       "accessibility": accessibilityGranted, "warning": warning,
       "boards": (archive.boards ?? []).map { ["id": $0.id, "name": $0.name, "color": $0.color] as [String: Any] },
       "syncEnabled": archive.syncEnabled ?? false, "syncConfigured": !cloudIdentifier.isEmpty,
       "syncStatus": cloudStatus, "presentation": presentation,
       "floatingPinned": floating.pinned, "widgetConfigured": widgetStore.available,
       "widgetSharing": widgetSharing,
       "screenshotsEnabled": screenshotsEnabled, "screenshotsFolder": screenshotFolderPath,
       "screenshotsStatus": screenshotStatus, "screenshotsWatching": screenshotWatching,
       "accentColor": Self.accentARGB(), "reduceTransparency": NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency]
  }
  func publish() { channel.invokeMethod("changed", arguments: state()) }
  func quickUse(_ index: Int) { channel.invokeMethod("quickUse", arguments: index) }
  /// The user's macOS accent colour as 0xAARRGGBB, for the Flutter theme.
  static func accentARGB() -> Int {
    guard let color = NSColor.controlAccentColor.usingColorSpace(.sRGB) else { return 0xFF167D70 }
    func channel(_ value: CGFloat) -> Int { Int((value * 255).rounded()) & 0xFF }
    return channel(color.alphaComponent) << 24 | channel(color.redComponent) << 16
      | channel(color.greenComponent) << 8 | channel(color.blueComponent)
  }
  @objc func appearanceSettingsChanged() { publish() }
  func capture() {
    let board = pasteboard
    guard change != board.changeCount else { return }
    change = board.changeCount
    guard !archive.paused, let originals = board.pasteboardItems, !originals.isEmpty else { return }
    let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
      "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
    guard !originals.contains(where: { item in item.types.contains { privateTypes.contains($0.rawValue) } }) else { return }
    var total = 0
    var items: [[String: Data]] = []
    for original in originals {
      var item: [String: Data] = [:]
      for type in original.types {
        // File promises cannot be replayed after the source exits.
        if type.rawValue.lowercased().contains("promise") { continue }
        if let data = original.data(forType: type) {
          total += data.count
          guard total <= 10 * 1024 * 1024 else {
            warning = "The last copy exceeded 10 MB and was skipped."; publish(); return
          }
          item[type.rawValue] = data
        }
      }
      if !item.isEmpty { items.append(item) }
    }
    guard !items.isEmpty else { return }
    let text = board.string(forType: .string) ?? ""
    let file = board.string(forType: .fileURL)
    let image = board.image
    var preview: Data?
    if let image = image {
      let maxSide: CGFloat = 640
      let scale = min(1, maxSide / max(image.size.width, image.size.height, 1))
      let thumb = NSImage(size: NSSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale)))
      thumb.lockFocus(); image.draw(in: NSRect(origin: .zero, size: thumb.size)); thumb.unlockFocus()
      if let tiff = thumb.tiffRepresentation { preview = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) }
    }
    let kind = file != nil ? "file" : image != nil ? "image" : text.isEmpty ? "other" : "text"
    let title = file.flatMap { URL(string: $0)?.lastPathComponent } ?? (text.isEmpty ? (kind == "image" ? "Copied image" : "Clipboard content") : String(text.prefix(120)))
    let clip = Clip(id: UUID().uuidString, title: title, text: text, kind: kind,
      source: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown app",
      date: Date().timeIntervalSince1970, snippet: false, items: items, preview: preview)
    if let image = image {
      let fingerprint = ScreenshotImage.fingerprint(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
      if let fingerprint = fingerprint, fingerprint == recentImageFingerprint,
        Date().timeIntervalSince1970 - recentImageDate < 15, let id = recentImageID {
        archive.clips.removeAll { $0.id == id && !$0.retained }
      }
      recentImageFingerprint = fingerprint; recentImageID = clip.id; recentImageDate = clip.date
    }
    if let index = archive.clips.firstIndex(where: { !$0.retained && $0.items == items }) { archive.clips.remove(at: index) }
    archive.clips.insert(clip, at: 0)
    trim(); persist(); publish()
  }
  func trim() {
    while archive.clips.filter({ !$0.retained }).count > 200 || archive.clips.reduce(0, { $0 + $1.size }) > 100 * 1024 * 1024 {
      guard let index = archive.clips.lastIndex(where: { !$0.retained }) else { break }
      lastSnapshot.removeValue(forKey: "clip-" + archive.clips[index].id)
      archive.clips.remove(at: index)
    }
  }
  func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "state": result(state())
    case "screenshots":
      screenshotPreferences.set(args["value"] as? Bool ?? true, forKey: "copyScreenshots")
      configureScreenshots(); publish(); result(nil)
    case "screenshotFolder": chooseScreenshotFolder(result)
    case "systemScreenshotFolder":
      screenshotPreferences.removeObject(forKey: "screenshotFolderBookmark")
      configureScreenshots(); publish(); result(nil)
    case "showShelf": show(); result(nil)
    case "showFloating": showFloating(); result(nil)
    case "floatingPinned": floating.pinned = args["value"] as? Bool ?? true; publish(); result(nil)
    case "dragFloating":
      if presentation == "floating", let event = dragEvent, ProcessInfo.processInfo.systemUptime - event.timestamp < 1 { window?.performDrag(with: event) }
      result(nil)
    case "widgetSharing":
      let enabled = args["value"] as? Bool ?? false
      guard !enabled || widgetStore.available else {
        result(FlutterError(code: "widget", message: "Desktop Favorites requires an App Group-enabled signed build.", details: nil)); return
      }
      do {
        if widgetStore.available {
          let snapshot = WidgetLibraryExporter.snapshot(clips: archive.clips, boards: archive.boards ?? [], enabled: enabled)
          if try widgetStore.write(snapshot) { WidgetCenter.shared.reloadTimelines(ofKind: "ClipShelfFavorites") }
        }
        UserDefaults.standard.set(enabled, forKey: "widgetSharing")
        publish(); result(nil)
      } catch {
        result(FlutterError(code: "widget", message: "Favorites could not be updated. The sharing setting has not changed. Try again.", details: nil))
      }
    case "quit": quit(); result(nil)
    case "pause": togglePause(); result(nil)
    case "accessibility":
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
      let granted = AXIsProcessTrustedWithOptions(options)
      refreshAccessibility()
      result(granted)
    case "hide": dismissPanel(); result(nil)
    case "clear":
      let keep = Set(archive.clips.filter { $0.retained }.map { "clip-" + $0.id })
      var versions = archive.versions ?? [:]
      for (key, old) in versions where key.hasPrefix("clip-") && !keep.contains(key) && !old.deleted {
        versions[key] = SyncStamp(time: max(Date().timeIntervalSince1970, old.time + 0.001), author: deviceID, deleted: true)
      }
      archive.versions = versions
      archive.clips.removeAll { !$0.retained }; persist(); publish(); result(nil)
    case "delete": archive.clips.removeAll { $0.id == args["id"] as? String }; persist(); publish(); result(nil)
    case "sync":
      let enabled = args["value"] as? Bool ?? false
      if enabled && cloudIdentifier.isEmpty {
        result(FlutterError(code: "provisioning", message: "iCloud requires a provisioned build with your Apple Developer container.", details: nil)); return
      }
      archive.syncEnabled = enabled
      if enabled { configureCloud() } else { cloud?.stop(); cloud = nil; cloudStatus = "iCloud sync is off"; persist() }
      publish(); result(nil)
    case "syncNow": cloud?.schedule(immediate: true); result(nil)
    case "board":
      let name = (args["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty, name.count <= 48, (archive.boards ?? []).count < 30 else {
        result(FlutterError(code: "board", message: "Use a name of 1–48 characters. Up to 30 pinboards are supported.", details: nil)); return
      }
      var boards = archive.boards ?? []
      boards.append(Pinboard(id: UUID().uuidString, name: name, color: args["color"] as? Int ?? 0))
      archive.boards = boards; persist(); publish(); result(nil)
    case "deleteBoard":
      let id = args["id"] as? String ?? ""
      archive.boards?.removeAll { $0.id == id }
      for i in archive.clips.indices where archive.clips[i].boardID == id { archive.clips[i].boardID = nil }
      trim(); persist(); publish(); result(nil)
    case "pin":
      guard let index = archive.clips.firstIndex(where: { $0.id == args["id"] as? String }) else {
        result(FlutterError(code: "missing", message: "This item no longer exists.", details: nil)); return
      }
      let board = args["boardID"] as? String ?? ""
      guard board.isEmpty || (archive.boards ?? []).contains(where: { $0.id == board }) else {
        result(FlutterError(code: "board", message: "This pinboard no longer exists.", details: nil)); return
      }
      let retained = archive.clips.filter { $0.retained && $0.id != archive.clips[index].id }
      guard board.isEmpty || (retained.count < 500 && retained.reduce(0, { $0 + $1.size }) + archive.clips[index].size <= 50 * 1024 * 1024) else {
        result(FlutterError(code: "limit", message: "Saved items are limited to 500 entries within 50 MB.", details: nil)); return
      }
      archive.clips[index].boardID = board.isEmpty ? nil : board
      trim(); persist(); publish(); result(nil)
    case "snippet":
      let text = args["text"] as? String ?? ""
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf8.count <= 1_000_000 else {
        result(FlutterError(code: "text", message: "A snippet needs text and must be under 1 MB.", details: nil)); return
      }
      guard archive.clips.filter({ $0.retained }).count < 500 else {
        result(FlutterError(code: "limit", message: "You have reached the 500 snippet limit.", details: nil)); return
      }
      guard archive.clips.filter({ $0.retained }).reduce(0, { $0 + $1.size }) + text.utf8.count <= 50 * 1024 * 1024 else {
        result(FlutterError(code: "storage", message: "Saved items have reached their 50 MB storage limit.", details: nil)); return
      }
      let title = (args["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      archive.clips.insert(Clip(id: UUID().uuidString, title: title.isEmpty ? String(text.prefix(80)) : title,
        text: text, kind: "text", source: "Snippet", date: Date().timeIntervalSince1970,
        snippet: true, items: [[NSPasteboard.PasteboardType.string.rawValue: Data(text.utf8)]], preview: nil), at: 0)
      trim(); persist(); publish(); result(nil)
    case "copy":
      guard let clip = archive.clips.first(where: { $0.id == args["id"] as? String }) else {
        result(FlutterError(code: "missing", message: "This item no longer exists.", details: nil)); return
      }
      let board = pasteboard
      let plain = args["plain"] as? Bool ?? false
      let representations = plain && !clip.text.isEmpty
        ? [[NSPasteboard.PasteboardType.string.rawValue: Data(clip.text.utf8)]] : clip.items
      let items = representations.map { formats -> NSPasteboardItem in
        let item = NSPasteboardItem()
        for (type, data) in formats { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
        return item
      }
      board.clearContents()
      guard board.writeObjects(items) else {
        result(FlutterError(code: "write", message: "macOS could not restore this clipboard item.", details: nil)); return
      }
      change = board.changeCount
      let paste = args["paste"] as? Bool ?? false
      if paste {
        refreshAccessibility()
        guard accessibilityGranted else { result("Copied. Enable Accessibility for direct paste."); return }
        guard let target = previousApp, !target.isTerminated else { result("Copied. Switch to your app and press ⌘V."); return }
        if presentation == "floating" && floating.pinned {
          // Release the nonactivating panel's key-focus token, then show without taking focus.
          window?.orderOut(nil)
          window?.orderFrontRegardless()
        }
        else { dismissPanel() }
        if !target.isActive { target.activate(options: []) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          // Never inject a paste if focus moved somewhere else during activation.
          guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else { return }
          let source = CGEventSource(stateID: .combinedSessionState)
          let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
          let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
          down?.flags = .maskCommand; up?.flags = .maskCommand
          down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
        }
        result("Pasting into \(target.localizedName ?? "your app")")
      } else { result("Copied to clipboard") }
    default: result(FlutterMethodNotImplemented)
    }
  }
}

// Private CloudKit database. Network work is async; local changes are persisted before upload.
// Each entity has its own record and a deterministic last-write stamp, including deletions.
final class CloudSync {
  private let container: CKContainer
  private let zoneID = CKRecordZone.ID(zoneName: "ClipShelf")
  private let snapshot: () -> [SyncEnvelope]
  private let receive: ([SyncEnvelope]) -> Void
  private let status: (String) -> Void
  private let accountChanged: () -> Void
  private var timer: Timer?
  private var pending: DispatchWorkItem?
  private var observer: NSObjectProtocol?
  private var stopped = false
  private var working = false
  private var repeatAfterWork = false
  private var generation = UUID()
  private var retryNotBefore = Date.distantPast

  init(identifier: String, snapshot: @escaping () -> [SyncEnvelope],
       receive: @escaping ([SyncEnvelope]) -> Void, status: @escaping (String) -> Void,
       accountChanged: @escaping () -> Void) {
    container = CKContainer(identifier: identifier)
    self.snapshot = snapshot; self.receive = receive; self.status = status; self.accountChanged = accountChanged
    observer = NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
      self?.stop(); self?.accountChanged()
    }
    timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.schedule(immediate: true) }
  }
  deinit { timer?.invalidate(); pending?.cancel(); if let observer = observer { NotificationCenter.default.removeObserver(observer) } }
  func stop() {
    stopped = true; generation = UUID(); pending?.cancel(); timer?.invalidate()
    if let observer = observer { NotificationCenter.default.removeObserver(observer); self.observer = nil }
  }
  func schedule(immediate: Bool = false) {
    guard !stopped else { return }
    if working { repeatAfterWork = true; return }
    pending?.cancel()
    let item = DispatchWorkItem { [weak self] in
      Task { @MainActor [weak self] in await self?.perform() }
    }
    pending = item
    DispatchQueue.main.asyncAfter(deadline: .now() + max(immediate ? 0 : 1.5, retryNotBefore.timeIntervalSinceNow), execute: item)
  }
  @MainActor private func perform() async {
    guard !stopped, !working else { return }
    working = true; repeatAfterWork = false
    let run = generation
    defer {
      working = false
      if repeatAfterWork && !stopped { schedule() }
    }
    status("Checking iCloud…")
    do {
      let account = try await container.accountStatus()
      guard !stopped, run == generation else { return }
      guard account == .available else { status("Sign in to iCloud in System Settings to sync"); return }
      let database = container.privateCloudDatabase
      _ = try await database.save(CKRecordZone(zoneID: zoneID))
      guard !stopped, run == generation else { return }
      status("Syncing with iCloud…")
      let localVersions = Dictionary(uniqueKeysWithValues: snapshot().map { ($0.key, $0.stamp) })
      let query = CKQuery(recordType: "ClipShelfEntity", predicate: NSPredicate(value: true))
      var response = try await database.records(matching: query, inZoneWith: zoneID, desiredKeys: ["stamp"], resultsLimit: 100)
      var records: [String: CKRecord] = [:]
      var remote: [SyncEnvelope] = []
      while true {
        for (_, result) in response.matchResults {
          var record = try result.get()
          guard let stampData = record["stamp"] as? Data,
            var stamp = try? JSONDecoder().decode(SyncStamp.self, from: stampData) else { throw SyncError.invalidRecord }
          let key = record.recordID.recordName
          records[key] = record
          // Poll metadata only. Assets are downloaded only for new or changed remote items.
          if let localStamp = localVersions[key], !(localStamp < stamp) { continue }
          if !stamp.deleted {
            record = try await database.record(for: record.recordID)
            guard let latestData = record["stamp"] as? Data,
              let latest = try? JSONDecoder().decode(SyncStamp.self, from: latestData) else { throw SyncError.invalidRecord }
            stamp = latest
          }
          if stamp.deleted {
            remote.append(SyncEnvelope(key: key, stamp: stamp, clip: nil, board: nil))
          } else if let asset = record["payload"] as? CKAsset, let url = asset.fileURL {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 16 * 1024 * 1024 else { throw SyncError.invalidRecord }
            let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: Data(contentsOf: url))
            guard envelope.key == key, envelope.stamp == stamp else { throw SyncError.invalidRecord }
            remote.append(envelope)
          } else { throw SyncError.invalidRecord }
          records[key] = record
        }
        guard let cursor = response.queryCursor else { break }
        guard !stopped, run == generation else { return }
        response = try await database.records(continuingMatchFrom: cursor, desiredKeys: ["stamp"], resultsLimit: 100)
      }
      guard !stopped, run == generation else { return }
      receive(remote)
      let local = snapshot()
      var conflict = false
      for envelope in local {
        guard !stopped, run == generation else { return }
        if let old = records[envelope.key], let data = old["stamp"] as? Data,
          let stamp = try? JSONDecoder().decode(SyncStamp.self, from: data), !(stamp < envelope.stamp) { continue }
        let record = records[envelope.key] ?? CKRecord(recordType: "ClipShelfEntity",
          recordID: CKRecord.ID(recordName: envelope.key, zoneID: zoneID))
        record["stamp"] = try JSONEncoder().encode(envelope.stamp) as NSData
        var temporary: URL?
        if envelope.stamp.deleted {
          record["payload"] = nil
        } else {
          guard envelope.clip != nil || envelope.board != nil else { continue }
          let url = FileManager.default.temporaryDirectory.appendingPathComponent("clipshelf-upload-\(UUID().uuidString).json")
          temporary = url
          try JSONEncoder().encode(envelope).write(to: url, options: .atomic)
          try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
          record["payload"] = CKAsset(fileURL: url)
        }
        defer { if let temporary = temporary { try? FileManager.default.removeItem(at: temporary) } }
        do { _ = try await database.save(record) }
        catch let error as CKError where error.code == .serverRecordChanged {
          // Refetch the newer server version, merge it, then retry any remaining local changes.
          conflict = true
        }
      }
      guard !stopped, run == generation else { return }
      if conflict {
        status("Resolving changes from another Mac…"); repeatAfterWork = true
      } else {
        let formatter = DateFormatter(); formatter.timeStyle = .short
        status("Last checked at \(formatter.string(from: Date()))")
      }
    } catch {
      guard !stopped, run == generation else { return }
      // Honor CloudKit's backoff, while keeping the outgoing versions in the local archive.
      if let cloudError = error as? CKError, let delay = cloudError.userInfo[CKErrorRetryAfterKey] as? Double {
        retryNotBefore = Date().addingTimeInterval(delay)
      }
      status("Sync waiting: \(error.localizedDescription)")
    }
  }
  enum SyncError: LocalizedError {
    case invalidRecord
    var errorDescription: String? { "An iCloud item could not be read safely. Local items are unchanged." }
  }
}
