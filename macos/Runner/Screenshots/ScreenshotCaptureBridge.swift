import Cocoa
import FlutterMacOS

extension ClipboardBridge {
  var screenshotsEnabled: Bool { screenshotPreferences.object(forKey: "copyScreenshots") as? Bool ?? true }
  static func systemScreenshotFolder() -> URL {
    let domain = "com.apple.screencapture" as CFString
    CFPreferencesAppSynchronize(domain)
    if let path = CFPreferencesCopyAppValue("location" as CFString, domain) as? String, !path.isEmpty {
      if path.hasPrefix("file://"), let url = URL(string: path), url.isFileURL { return url.standardizedFileURL }
      if path.hasPrefix("/") || path.hasPrefix("~") {
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL
      }
    }
    return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
  }
  func configuredScreenshotFolder() -> URL {
    if let bookmark = screenshotPreferences.data(forKey: "screenshotFolderBookmark") {
      var stale = false
      if let folder = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale) {
        return folder
      }
    }
    return Self.systemScreenshotFolder()
  }
  func configureScreenshots() {
    guard monitoringEnabled else { return }
    screenshotRun = UUID(); screenshotMonitor?.stop(); screenshotMonitor = nil
    if let scoped = screenshotScope { scoped.stopAccessingSecurityScopedResource(); screenshotScope = nil }
    let folder = configuredScreenshotFolder()
    screenshotFolderPath = folder.path; screenshotWatching = false
    guard screenshotsEnabled, !archive.paused else {
      screenshotStatus = archive.paused ? "Screenshot copying is paused with clipboard capture." : "Automatic screenshot copying is off."
      return
    }
    if folder.startAccessingSecurityScopedResource() { screenshotScope = folder }
    screenshotStatus = "Starting automatic screenshot copying…"
    let run = screenshotRun
    let monitor = ScreenshotMonitor(clipboardVersion: { [weak self] in
      DispatchQueue.main.sync { self?.pasteboard.changeCount ?? -1 }
    }, receive: { [weak self] image, version in
      guard let self = self, self.screenshotRun == run, self.screenshotsEnabled, !self.archive.paused else { return }
      self.importScreenshot(image, clipboardVersion: version)
    }, status: { [weak self] watching, message in
      guard let self = self, self.screenshotRun == run else { return }
      self.screenshotWatching = watching; self.screenshotStatus = message; self.publish()
    })
    screenshotMonitor = monitor; monitor.start(folder)
  }
  func refreshScreenshotFolderIfNeeded() {
    screenshotPreferenceTicks += 1
    guard screenshotPreferenceTicks >= 10 else { return }
    screenshotPreferenceTicks = 0
    if configuredScreenshotFolder().path != screenshotFolderPath { configureScreenshots(); publish() }
  }
  func chooseScreenshotFolder(_ result: @escaping FlutterResult) {
    guard let window = window else { result(nil); return }
    let picker = NSOpenPanel()
    picker.canChooseFiles = false; picker.canChooseDirectories = true; picker.allowsMultipleSelection = false
    picker.prompt = "Watch screenshots"; picker.message = "Choose where macOS saves screenshots. Only newly saved images marked as screenshots will be copied."
    picker.directoryURL = configuredScreenshotFolder()
    picker.beginSheetModal(for: window) { [weak self] response in
      guard let self = self, response == .OK, let folder = picker.url else { result(nil); return }
      do {
        let bookmark = try folder.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        self.screenshotPreferences.set(bookmark, forKey: "screenshotFolderBookmark")
        self.screenshotPreferences.set(true, forKey: "copyScreenshots")
        self.configureScreenshots(); self.publish(); result(nil)
      } catch { result(FlutterError(code: "screenshot-folder", message: "The screenshot folder permission could not be saved. Please choose it again.", details: nil)) }
    }
  }
  func importScreenshot(_ image: ScreenshotImage, clipboardVersion: Int) {
    guard screenshotsEnabled, !archive.paused else { return }
    // Capture any intervening copy before considering an automatic clipboard write.
    capture()
    let mayCopy = pasteboard.changeCount == clipboardVersion
    if let fingerprint = image.fingerprint, fingerprint == recentImageFingerprint,
      Date().timeIntervalSince1970 - recentImageDate < 15, let id = recentImageID {
      archive.clips.removeAll { $0.id == id && !$0.retained }
    }
    let clip = Clip(id: UUID().uuidString, title: image.file.url.lastPathComponent, text: "", kind: "image",
      source: "Screenshot", date: image.file.created.timeIntervalSince1970, snippet: false,
      items: [[NSPasteboard.PasteboardType.png.rawValue: image.png]], preview: image.preview)
    let index = archive.clips.firstIndex { $0.date < clip.date } ?? archive.clips.endIndex
    archive.clips.insert(clip, at: index)
    recentImageFingerprint = image.fingerprint; recentImageID = clip.id; recentImageDate = Date().timeIntervalSince1970
    if mayCopy {
      let item = NSPasteboardItem(); item.setData(image.png, forType: .png)
      pasteboard.clearContents()
      if pasteboard.writeObjects([item]) {
        change = pasteboard.changeCount
        screenshotStatus = "Screenshot copied. Its original file was kept."
      } else { screenshotStatus = "Screenshot saved to history; macOS could not copy it to the clipboard." }
    } else { screenshotStatus = "Screenshot saved to history. Your newer clipboard copy was kept." }
    trim(); persist(); publish()
  }
}
