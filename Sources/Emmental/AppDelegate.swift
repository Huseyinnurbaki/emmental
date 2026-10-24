import AppKit

/// The menu holds what you change often (speed, acceleration, scroll speed)
/// and the Settings window holds the set-and-forget options.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let headerView = MenuHeaderView()
    private let dpiView = DPIMenuView()
    private let accelerationView = AccelerationMenuView()
    private let scrollView = LabeledSliderView(title: "Scroll speed", range: SpeedControl.scroll.range,
                                               tickMarks: Int(SpeedControl.scroll.range.upperBound) + 1,
                                               format: { String(format: "%.1f", $0) })
    private let logitechMice = LogitechMice()
    private var settingsWindow: SettingsWindowController?
    private var watcher: DeviceWatcher?
    private var isMenuOpen = false
    /// The latest SmartShift state, from the user or the mouse, so the switch
    /// and the threshold in Settings can each change their half of it.
    private var smartShift: SmartShift?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.image = WedgeIcon.image()
        statusItem.button?.toolTip = "Emmental"
        statusItem.menu = makeMenu()

        accelerationView.onChange = { [weak self] value in
            Settings.setValue(value, for: .pointer)
            self?.applySpeeds()
        }
        scrollView.onChange = { [weak self] value in
            Settings.setValue(value, for: .scroll)
            self?.applySpeeds()
        }
        dpiView.onChange = { [weak self] dpi in
            Settings.dpi = dpi
            self?.logitechMice.mice.forEach { $0.setDPI(dpi) }
        }
        dpiView.onAction = { [weak self] action in self?.handle(action) }
        // Mice behind a receiver show up asynchronously, and wake up without the
        // device watcher noticing; both arrive here.
        logitechMice.onMouseAvailable = { [weak self] mouse in
            guard let self = self else { return }
            self.apply(to: mouse)
            if self.isMenuOpen { self.refreshLogitech() }
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
        headerView.update(mice: mice)
        func saved(_ control: SpeedControl) -> Double {
            Settings.value(for: control) ?? mice.first.flatMap { MouseSpeed.value(of: control, on: $0) } ?? 1
        }
        accelerationView.update(value: saved(.pointer), enabled: !mice.isEmpty)
        scrollView.value = saved(.scroll)
        scrollView.isEnabled = !mice.isEmpty
        refreshLogitech()
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        func addView(_ view: NSView, top: CGFloat = 6, bottom: CGFloat = 6) -> NSMenuItem {
            let item = NSMenuItem()
            item.view = MenuItemContainer(view, top: top, bottom: bottom)
            menu.addItem(item)
            return item
        }

        _ = addView(headerView, top: 6, bottom: 4)
        let dpiItem = addView(dpiView)
        dpiView.onResize = { (dpiItem.view as? MenuItemContainer)?.fitToContent() }
        _ = addView(accelerationView)
        _ = addView(scrollView)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit Emmental", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    // MARK: Settings window

    @objc private func showSettings() {
        let window = settingsWindow ?? makeSettingsWindow()
        settingsWindow = window
        window.setSmartShift(nil)
        window.setHighResolution(nil)
        window.show()

        guard let mouse = readyLogitechMouse() else { return }
        mouse.readSmartShift { [weak self] current in
            guard let self = self else { return }
            self.smartShift = Settings.smartShift ?? current
            self.settingsWindow?.setSmartShift(self.smartShift)
        }
        mouse.readHighResolutionScrolling { [weak self] current in
            self?.settingsWindow?.setHighResolution(current.map { Settings.highResolutionScrolling ?? $0 })
        }
    }

    private func makeSettingsWindow() -> SettingsWindowController {
        let window = SettingsWindowController()
        window.onSmartShiftToggle = { [weak self] isOn in
            guard let self = self, let current = self.smartShift else { return }
            self.changeSmartShift(SmartShift(autoSwitch: isOn, threshold: current.threshold))
        }
        window.onThresholdChange = { [weak self] threshold in
            guard let self = self, let current = self.smartShift else { return }
            self.changeSmartShift(SmartShift(autoSwitch: current.autoSwitch, threshold: threshold))
        }
        window.onHighResolutionChange = { [weak self] enabled in
            Settings.highResolutionScrolling = enabled
            self?.logitechMice.mice.forEach { $0.setHighResolutionScrolling(enabled) }
        }
        return window
    }

    // MARK: Logitech features

    /// The first Logitech mouse, if HID++ is turned on, permitted and connected.
    private func readyLogitechMouse() -> LogitechMouse? {
        guard Settings.dpiEnabled, InputMonitoring.isGranted else { return nil }
        return logitechMice.refresh().mice.first
    }

    /// Speed and battery go through HID++, so they share one opt-in and one
    /// permission check (with SmartShift and high-res scrolling in Settings).
    private func refreshLogitech() {
        guard Settings.dpiEnabled else { return dpiView.show(.off) }
        guard InputMonitoring.isGranted else { return dpiView.show(.needsPermission) }
        let (mice, blocked) = logitechMice.refresh()
        guard let mouse = mice.first else { return dpiView.show(blocked ? .needsRelaunch : .noMouse) }

        mouse.readBattery { [weak self] battery in self?.headerView.setBattery(battery) }

        // Saved values win over what's read, in case a control moved meanwhile.
        dpiView.show(.ready(dpi: Settings.dpi, range: .fallback))
        mouse.readDPI { [weak self] current, range in
            self?.dpiView.show(.ready(dpi: Settings.dpi ?? current, range: range))
        }
    }

    /// Saves and applies a SmartShift change from Settings.
    private func changeSmartShift(_ smartShift: SmartShift) {
        self.smartShift = smartShift
        Settings.smartShift = smartShift
        logitechMice.mice.forEach { $0.setSmartShift(smartShift) }
        settingsWindow?.setSmartShift(smartShift)
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

    // MARK: Applying settings

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
