import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speedView = SpeedMenuView()
    private var watcher: DeviceWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = WedgeIcon.image()
        statusItem.button?.toolTip = "Emmental"
        statusItem.menu = makeMenu()

        speedView.onChange = { control, value in
            Settings.setValue(value, for: control)
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
        var values: [SpeedControl: Double] = [:]
        for control in SpeedControl.allCases {
            values[control] = Settings.value(for: control) ?? mice.first.flatMap { MouseSpeed.value(of: control, on: $0) }
        }
        speedView.update(mice: mice, values: values)
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

    /// Pushes the saved speeds to every connected mouse. A speed the user hasn't
    /// picked yet is left alone, so first launch leaves the system untouched.
    private static func applySettings() {
        let mice = MouseSpeed.connectedMice()
        for control in SpeedControl.allCases {
            guard let value = Settings.value(for: control) else { continue }
            for mouse in mice {
                MouseSpeed.set(value, for: control, on: mouse)
            }
        }
    }
}
