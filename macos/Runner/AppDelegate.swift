import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(openURL(_:reply:)),
      forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
  }
  @objc private func openURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
    guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
      let url = URL(string: raw), url.scheme == "clipshelf", url.host == "open" else { return }
    DispatchQueue.main.async {
      (NSApp.windows.first { $0 is MainFlutterWindow } as? MainFlutterWindow)?.openClipShelfURL(url)
    }
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
