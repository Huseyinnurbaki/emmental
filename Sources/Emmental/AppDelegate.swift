import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speedView = SpeedMenuView()
    private let dpiView = DPIMenuView()
    private let logitechMice = LogitechMice()
    private var watcher: DeviceWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = WedgeIcon.image()
        statusItem.button?.toolTip = "Emmental"
        statusItem.menu = makeMenu()

        speedView.onChange = { [weak self] control, value in
            Settings.setValue(value, for: control)
            self?.applySpeeds()
        }
        dpiView.onChange = { [weak self] dpi in
            Settings.dpi = dpi
            self?.logitechMice.mice.forEach { $0.setDPI(dpi) }
        }
        dpiView.onAction = { [weak self] action in self?.handle(action) }

        applyAll()
        // A reconnecting mouse comes back with defaults; give its HID service a
        // moment to register before reapplying.
        watcher = DeviceWatcher { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.applyAll() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.applyAll() }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let mice = MouseSpeed.connectedMice()
        var values: [SpeedControl: Double] = [:]
        for control in SpeedControl.allCases {
            values[control] = Settings.value(for: control) ?? mice.first.flatMap { MouseSpeed.value(of: control, on: $0) }
        }
        speedView.update(mice: mice, values: values)
        refreshDPIView()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        let speedItem = NSMenuItem()
        speedItem.view = speedView
        menu.addItem(speedItem)
        menu.addItem(.separator())
        let dpiItem = NSMenuItem()
        dpiItem.view = dpiView
        menu.addItem(dpiItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Emmental", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func refreshDPIView() {
        guard Settings.dpiEnabled else { return dpiView.show(.off) }
        guard InputMonitoring.isGranted else { return dpiView.show(.needsPermission) }
        let (mice, blocked) = logitechMice.refresh()
        guard let mouse = mice.first else { return dpiView.show(blocked ? .needsRelaunch : .noMouse) }

        dpiView.show(.ready(dpi: Settings.dpi, range: .fallback))
        mouse.readDPI { [weak self] current, range in
            // If the slider moved while we were reading, keep the user's value.
            self?.dpiView.show(.ready(dpi: Settings.dpi ?? current, range: range))
        }
    }

    private func handle(_ action: DPIMenuView.Action) {
        switch action {
        case .turnOn:
            Settings.dpiEnabled = true
            if InputMonitoring.isGranted { applyDPI() } else { InputMonitoring.request() }
        case .openSettings:
            InputMonitoring.openSettings()
        case .relaunch:
            // Input Monitoring only takes effect in a fresh process.
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 0.5; open \"$0\"", Bundle.main.bundlePath]
            try? relaunch.run()
            NSApp.terminate(nil)
        }
    }

    private func applyAll() {
        applySpeeds()
        applyDPI()
    }

    /// Pushes the saved speeds to every connected mouse. A speed the user hasn't
    /// picked yet is left alone, so first launch leaves the system untouched.
    private func applySpeeds() {
        let mice = MouseSpeed.connectedMice()
        for control in SpeedControl.allCases {
            guard let value = Settings.value(for: control) else { continue }
            for mouse in mice {
                MouseSpeed.set(value, for: control, on: mouse)
            }
        }
    }

    private func applyDPI() {
        guard Settings.dpiEnabled, let dpi = Settings.dpi, InputMonitoring.isGranted else { return }
        logitechMice.refresh().mice.forEach { $0.setDPI(dpi) }
    }
}
