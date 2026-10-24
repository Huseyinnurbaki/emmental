import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speedView = SpeedMenuView()
    private var watcher: DeviceWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = WedgeIcon.image()
        statusItem.button?.toolTip = "Emmental"
        statusItem.menu = makeMenu()

        speedView.onChange = { speed in
            Settings.speed = speed
            Self.applySettings()
        }

        Self.applySettings()
        // A reconnecting mouse comes back with macOS defaults; give its HID
        // service a moment to register before reapplying.
        watcher = DeviceWatcher {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Self.applySettings() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in Self.applySettings() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let mice = MouseSpeed.connectedMice()
        let speed = Settings.speed ?? mice.first.flatMap(MouseSpeed.speed(of:)) ?? 1
        speedView.update(mice: mice, speed: speed)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let speedItem = NSMenuItem()
        speedItem.view = speedView
        menu.addItem(speedItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Emmental", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    /// Pushes the saved speed to every connected mouse. Does nothing until the
    /// user has picked a speed, so first launch leaves the system untouched.
    private static func applySettings() {
        guard let speed = Settings.speed else { return }
        for mouse in MouseSpeed.connectedMice() {
            MouseSpeed.setSpeed(speed, on: mouse)
        }
    }
}
