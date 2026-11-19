import Cocoa
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

struct ScreenshotFile {
  let url: URL
  let key: String
  let size: Int
  let modified: Date
  let created: Date
  let marked: Bool
}

/// Wait for a marked screenshot to stop changing; never backfill a directory.
final class ScreenshotFileTracker {
  struct Pending {
    var file: ScreenshotFile
    var attempts: Int
    let clipboardVersion: Int
  }
  private var known = Set<String>()
  private var pending: [String: Pending] = [:]
  private var started = Date()
  var needsRetry: Bool { !pending.isEmpty }
  func reset(_ files: [ScreenshotFile], now: Date = Date()) {
    known = Set(files.map(\.key)); pending = [:]; started = now
  }
  func observe(_ files: [ScreenshotFile], clipboardVersion: () -> Int) -> [(ScreenshotFile, Int)] {
    let keys = Set(files.map(\.key))
    known.formIntersection(keys)
    pending = pending.filter { keys.contains($0.key) }
    var ready: [(ScreenshotFile, Int)] = []
    for file in files where !known.contains(file.key) {
      guard file.created >= started.addingTimeInterval(-1) else { known.insert(file.key); continue }
      if let previous = pending[file.key] {
        if file.marked && file.size > 0 && previous.file.size == file.size && previous.file.modified == file.modified {
          ready.append((file, previous.clipboardVersion)); known.insert(file.key); pending.removeValue(forKey: file.key)
        } else if previous.attempts >= 20 {
          known.insert(file.key); pending.removeValue(forKey: file.key)
        } else {
          pending[file.key] = Pending(file: file, attempts: previous.attempts + 1, clipboardVersion: previous.clipboardVersion)
        }
      } else {
        pending[file.key] = Pending(file: file, attempts: 0, clipboardVersion: clipboardVersion())
      }
    }
    return ready.sorted { $0.0.created < $1.0.created }
  }
}

struct ScreenshotImage {
  let png: Data
  let preview: Data
  let fingerprint: Data?
  let file: ScreenshotFile
  static let maximumBytes = 10 * 1024 * 1024
  static func load(_ file: ScreenshotFile) throws -> Self {
    guard file.size <= maximumBytes else { throw CaptureError.tooLarge }
    let data = try Data(contentsOf: file.url, options: .mappedIfSafe)
    guard data.count <= maximumBytes,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int,
      width > 0, height > 0, Double(width) * Double(height) <= 64_000_000,
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CaptureError.unreadable }
    let png = CGImageSourceGetType(source) as String? == UTType.png.identifier ? data : try encodePNG(image)
    guard png.count <= maximumBytes else { throw CaptureError.tooLarge }
    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: 640, kCGImageSourceCreateThumbnailWithTransform: true]
    guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw CaptureError.unreadable }
    return Self(png: png, preview: try encodePNG(thumb), fingerprint: fingerprint(image), file: file)
  }
  static func encodePNG(_ image: CGImage) throws -> Data {
    let data = NSMutableData()
    guard let writer = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { throw CaptureError.unreadable }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { throw CaptureError.unreadable }
    return data as Data
  }
  static func fingerprint(_ image: CGImage?) -> Data? {
    guard let image = image, image.width > 0, image.height > 0,
      Double(image.width) * Double(image.height) <= 64_000_000,
      let color = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
        bytesPerRow: image.width * 4, space: color,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return nil }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    guard let bytes = context.data else { return nil }
    return withExtendedLifetime(context) {
      Data(SHA256.hash(data: Data(bytesNoCopy: bytes, count: image.width * image.height * 4, deallocator: .none)))
    }
  }
  enum CaptureError: Error { case tooLarge, unreadable }
}

/// Directory events and bounded retries run off the UI thread. No screen capture API.
final class ScreenshotMonitor {
  private let queue = DispatchQueue(label: "clipshelf.screenshots", qos: .utility)
  private var source: DispatchSourceFileSystemObject?
  private var retry: DispatchWorkItem?
  private var tracker = ScreenshotFileTracker()
  private var generation = UUID()
  private var folder: URL?
  let clipboardVersion: () -> Int
  let receive: (ScreenshotImage, Int) -> Void
  let status: (Bool, String) -> Void
  init(clipboardVersion: @escaping () -> Int, receive: @escaping (ScreenshotImage, Int) -> Void,
       status: @escaping (Bool, String) -> Void) {
    self.clipboardVersion = clipboardVersion; self.receive = receive; self.status = status
  }
  deinit { source?.cancel(); retry?.cancel() }
  func start(_ folder: URL) {
    queue.async { [weak self] in
      guard let self = self else { return }
      self.stopOnQueue(); self.folder = folder
      do {
        self.tracker.reset(try Self.files(in: folder))
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { throw CocoaError(.fileReadNoPermission) }
        let token = self.generation
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd,
          eventMask: [.write, .extend, .attrib, .rename, .delete, .revoke], queue: self.queue)
        source.setCancelHandler { close(fd) }
        source.setEventHandler { [weak self, weak source] in
          guard let self = self, let source = source, token == self.generation else { return }
          if !source.data.intersection([.delete, .rename, .revoke]).isEmpty {
            self.stopOnQueue(); self.sendStatus(false, "Screenshot folder changed. Choose its current location.")
          } else { self.schedule(token) }
        }
        self.source = source; source.activate()
        self.sendStatus(true, "New screenshots are copied automatically. Original files stay in this folder.")
      } catch { self.sendStatus(false, "Choose the screenshot folder to allow access.") }
    }
  }
  func stop() { queue.async { [weak self] in self?.stopOnQueue() } }
  private func stopOnQueue() {
    generation = UUID(); retry?.cancel(); retry = nil; source?.cancel(); source = nil; folder = nil
  }
  private func sendStatus(_ watching: Bool, _ text: String) {
    DispatchQueue.main.async { [weak self] in self?.status(watching, text) }
  }
  private func schedule(_ token: UUID) {
    retry?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.scan(token) }
    retry = work; queue.asyncAfter(deadline: .now() + 0.35, execute: work)
  }
  private func scan(_ token: UUID) {
    guard token == generation, let folder = folder else { return }
    do {
      let ready = tracker.observe(try Self.files(in: folder), clipboardVersion: clipboardVersion)
      for (file, version) in ready {
        do {
          let image = try ScreenshotImage.load(file)
          guard token == generation else { return }
          DispatchQueue.main.async { [weak self] in self?.receive(image, version) }
        } catch ScreenshotImage.CaptureError.tooLarge {
          sendStatus(true, "A screenshot exceeded the 10 MB limit. Its original file was kept.")
        } catch {
          sendStatus(true, "A screenshot could not be imported. Its original file was kept.")
        }
      }
      if tracker.needsRetry { schedule(token) }
    } catch { sendStatus(false, "Screenshot folder is unavailable. Choose the folder again.") }
  }
  static func files(in folder: URL) throws -> [ScreenshotFile] {
    try FileManager.default.contentsOfDirectory(at: folder,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey, .fileResourceIdentifierKey],
      options: [.skipsHiddenFiles]).compactMap { url in
        guard ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif"].contains(url.pathExtension.lowercased()),
          let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .creationDateKey, .contentModificationDateKey, .fileResourceIdentifierKey]),
          values.isRegularFile == true, values.isSymbolicLink != true else { return nil }
        return ScreenshotFile(url: url, key: url.path + "#" + String(describing: values.fileResourceIdentifier),
          size: values.fileSize ?? 0, modified: values.contentModificationDate ?? .distantPast,
          created: values.creationDate ?? .distantPast, marked: isScreenshot(url))
      }
  }
  static func isScreenshot(_ url: URL) -> Bool {
    let key = "com.apple.metadata:kMDItemIsScreenCapture"
    let size = getxattr(url.path, key, nil, 0, 0, 0)
    guard size > 0 && size <= 1024 else { return false }
    var bytes = [UInt8](repeating: 0, count: size)
    guard getxattr(url.path, key, &bytes, size, 0, 0) == size,
      let value = try? PropertyListSerialization.propertyList(from: Data(bytes), options: [], format: nil) else { return false }
    return value as? Bool == true
  }
}
