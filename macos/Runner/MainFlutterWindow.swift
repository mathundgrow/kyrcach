import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    self.setContentSize(NSSize(width: 1480, height: 920))
    self.minSize = NSSize(width: 1080, height: 680)
    self.center()
    self.title = "CodeGraph"
    self.titlebarAppearsTransparent = true
    self.backgroundColor = NSColor(calibratedRed: 0.055, green: 0.047, blue: 0.031, alpha: 1.0)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
