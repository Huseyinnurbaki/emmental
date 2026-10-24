import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let speedView = SpeedMenuView()
    private let dpiView = DPIMenuView()
    private let wheelView = WheelMenuView()
    private let wheelItem = NSMenuItem()
    private let logitechMice = LogitechMice()
    private lazy var aboutWindow = AboutWindowController()
    private var watcher: DeviceWatcher?
    private var isMenuOpen = false

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
        wheelView.onSmartShiftChange = { [weak self] smartShift in
            Settings.smartShift = smartShift
            self?.logitechMice.mice.forEach { $0.setSmartShift(smartShift) }
        }
        wheelView.onHighResolutionChange = { [weak self] enabled in
            Settings.highResolutionScrolling = enabled
            self?.logitechMice.mice.forEach { $0.setHighResolutionScrolling(enabled) }
        }
        // Mice behind a receiver show up asynchronously, and wake up without the
        // device watcher noticing; both arrive here.
        logitechMice.onMouseAvailable = { [weak self] mouse in
            guard let self = self else { return }
            self.apply(to: mouse)
            if self.isMenuOpen { self.refreshLogitechViews() }
        }

        LoginItem.refreshIfEnabled()
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
        isMenuOpen = true
        let mice = MouseSpeed.connectedMice()
        var values: [SpeedControl: Double] = [:]
        for control in SpeedControl.allCases {
            values[control] = Settings.value(for: control) ?? mice.first.flatMap { MouseSpeed.value(of: control, on: $0) }
        }
        speedView.update(mice: mice, values: values)
        refreshLogitechViews()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
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
        wheelItem.view = wheelView
        wheelItem.isHidden = true
        menu.addItem(wheelItem)
        menu.addItem(.separator())
        let aboutItem = NSMenuItem(title: "About Emmental", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        // macOS adds icons to standard items like Quit; a custom About needs its own.
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)
        menu.addItem(NSMenuItem(title: "Quit Emmental", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func showAbout() {
        aboutWindow.show()
    }

    /// The DPI, battery and wheel controls all go through HID++, so they share
    /// one opt-in and one permission check.
    private func refreshLogitechViews() {
        wheelItem.isHidden = true
        guard Settings.dpiEnabled else { return dpiView.show(.off) }
        guard InputMonitoring.isGranted else { return dpiView.show(.needsPermission) }
        let (mice, blocked) = logitechMice.refresh()
        guard let mouse = mice.first else { return dpiView.show(blocked ? .needsRelaunch : .noMouse) }

        mouse.readBattery { [weak self] battery in self?.speedView.setBattery(battery) }

        // Saved values win over what's read, in case a slider moved meanwhile.
        dpiView.show(.ready(dpi: Settings.dpi, range: .fallback))
        mouse.readDPI { [weak self] current, range in
            self?.dpiView.show(.ready(dpi: Settings.dpi ?? current, range: range))
        }
        mouse.readSmartShift { [weak self] current in
            guard let self = self else { return }
            self.wheelView.showSmartShift(Settings.smartShift ?? current)
            self.wheelItem.isHidden = false
        }
        mouse.readHighResolutionScrolling { [weak self] current in
            self?.wheelView.showHighResolution(current.map { Settings.highResolutionScrolling ?? $0 })
        }
    }

    private func handle(_ action: DPIMenuView.Action) {
        switch action {
        case .turnOn:
            Settings.dpiEnabled = true
            if InputMonitoring.isGranted { applyLogitech() } else { InputMonitoring.request() }
        case .openSettings:
            // Requesting again lists this exact build in Settings. A rebuild signed
            // ad hoc doesn't match the entry an older build left there.
            InputMonitoring.request()
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
        applyLogitech()
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

    private func applyLogitech() {
        guard Settings.dpiEnabled, InputMonitoring.isGranted else { return }
        logitechMice.refresh().mice.forEach(apply(to:))
    }

    /// Sends every saved HID++ setting to one mouse; unset ones are left alone.
    private func apply(to mouse: LogitechMouse) {
        guard Settings.dpiEnabled, InputMonitoring.isGranted else { return }
        if let dpi = Settings.dpi { mouse.setDPI(dpi) }
        if let smartShift = Settings.smartShift { mouse.setSmartShift(smartShift) }
        if let highResolution = Settings.highResolutionScrolling { mouse.setHighResolutionScrolling(highResolution) }
    }
}
