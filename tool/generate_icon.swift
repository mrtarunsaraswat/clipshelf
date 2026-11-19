import Cocoa
let folder = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "macos/Runner/Assets.xcassets/AppIcon.appiconset"
for size in [16, 32, 64, 128, 256, 512, 1024] {
  let image = NSImage(size: NSSize(width: size, height: size))
  image.lockFocus()
  let scale = CGFloat(size) / 1024
  let transform = NSAffineTransform()
  transform.scale(by: scale)
  transform.concat()
  NSColor(calibratedRed: 0.09, green: 0.43, blue: 0.37, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 220, yRadius: 220).fill()
  NSColor(calibratedRed: 0.67, green: 0.81, blue: 0.68, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: 254, y: 212, width: 558, height: 610), xRadius: 70, yRadius: 70).fill()
  NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.89, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: 208, y: 260, width: 542, height: 596), xRadius: 70, yRadius: 70).fill()
  NSColor(calibratedRed: 0.09, green: 0.43, blue: 0.37, alpha: 1).setFill()
  NSBezierPath(roundedRect: NSRect(x: 352, y: 786, width: 250, height: 104), xRadius: 38, yRadius: 38).fill()
  for y in [620, 500, 380] {
    NSBezierPath(roundedRect: NSRect(x: 316, y: y, width: y == 380 ? 208 : 324, height: 32), xRadius: 16, yRadius: 16).fill()
  }
  image.unlockFocus()
  let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
  try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(folder)/app_icon_\(size).png"))
}
