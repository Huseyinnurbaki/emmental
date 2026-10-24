import AppKit

/// Emmental's Settings window: the set-and-forget options that don't need to
/// be one click away in the menu, plus the app's icon and version.
final class SettingsWindowController: NSWindowController {
    var onScrollSpeedChange: ((Double) -> Void)?
    var onSmartShiftToggle: ((Bool) -> Void)?
    var onThresholdChange: ((Int) -> Void)?
    var onHighResolutionChange: ((Bool) -> Void)?

    private static let width: CGFloat = 360
    private static let groupPadding: CGFloat = 14

    private let scrollSpeed: LabeledSliderView
    private let smartShiftRow = SwitchRowView(title: "SmartShift")
    private let smartShiftHint = SettingsWindowController.hintLabel(
        "Switches the wheel to free-spin when you flick it. The button under the wheel still switches by hand.")
    private let threshold: LabeledSliderView
    private let thresholdHint = SettingsWindowController.hintLabel("Lower switches to free-spin with a gentler flick.")
    private let highResolution = SwitchRowView(title: "High-resolution scrolling")
    private let highResolutionHint = SettingsWindowController.hintLabel(
        "Experimental. On macOS this may make scrolling much faster.")
    private let loginRow = SwitchRowView(title: "Open at login")
    private let content = NSView()

    init() {
        let scrollRange = SpeedControl.scroll.range
        scrollSpeed = LabeledSliderView(title: "Scroll speed", range: scrollRange,
                                        tickMarks: Int(scrollRange.upperBound) + 1,
                                        format: { String(format: "%.1f", $0) })
        let thresholds = SmartShift.thresholdRange
        threshold = LabeledSliderView(title: "Free-spin threshold",
                                      range: Double(thresholds.lowerBound)...Double(thresholds.upperBound),
                                      step: 1, format: { String(Int($0)) })

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "Emmental Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        scrollSpeed.onChange = { [weak self] in self?.onScrollSpeedChange?($0) }
        smartShiftRow.onToggle = { [weak self] in self?.onSmartShiftToggle?($0) }
        threshold.onChange = { [weak self] in self?.onThresholdChange?(Int($0)) }
        highResolution.onToggle = { [weak self] in self?.onHighResolutionChange?($0) }
        loginRow.onToggle = { [weak self] isOn in
            do {
                try LoginItem.setEnabled(isOn)
            } catch {
                NSSound.beep()
                self?.loginRow.isOn = LoginItem.isEnabled
            }
        }

        let stack = NSStackView(views: [
            Self.header(),
            Self.sectionTitle("Scrolling"),
            Self.group([scrollSpeed, smartShiftRow, smartShiftHint, threshold, thresholdHint,
                        highResolution, highResolutionHint]),
            Self.sectionTitle("General"),
            Self.group([loginRow]),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(22, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(18, after: stack.arrangedSubviews[2])
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: Self.width),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
        ])
        for view in stack.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        window.contentView = content
        setScrollSpeed(1)
        setSmartShift(nil)
        setHighResolution(nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        loginRow.isOn = LoginItem.isEnabled
        if window?.isVisible == false { window?.center() }
        // A menu bar app has no Dock icon, so bring it forward or the window opens behind others.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func setScrollSpeed(_ value: Double) {
        scrollSpeed.value = value
    }

    /// nil hides SmartShift, e.g. before Logitech features are turned on. The
    /// threshold is only adjustable while SmartShift is on.
    func setSmartShift(_ smartShift: SmartShift?) {
        for view in [smartShiftRow, smartShiftHint, threshold, thresholdHint] as [NSView] {
            view.isHidden = smartShift == nil
        }
        if let smartShift = smartShift {
            smartShiftRow.isOn = smartShift.autoSwitch
            threshold.value = Double(smartShift.threshold)
            threshold.isEnabled = smartShift.autoSwitch
        }
        resizeToFit()
    }

    /// nil hides the row, for mice without a high-resolution wheel.
    func setHighResolution(_ enabled: Bool?) {
        highResolution.isHidden = enabled == nil
        highResolutionHint.isHidden = enabled == nil
        highResolution.isOn = enabled ?? false
        resizeToFit()
    }

    /// Grows or shrinks the window as rows show and hide, keeping its top edge put.
    private func resizeToFit() {
        guard let window = window else { return }
        let size = content.fittingSize
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = window.frame.origin
        frame.origin.y += window.frame.height - frame.height
        window.setFrame(frame, display: true)
    }

    // MARK: Building blocks

    private static func header() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        let name = NSTextField(labelWithString: "Emmental")
        name.font = .systemFont(ofSize: 17, weight: .semibold)
        let info = Bundle.main.infoDictionary ?? [:]
        let version = NSTextField(labelWithString:
            "Version \(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))")
        version.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        version.textColor = .secondaryLabelColor
        let tagline = NSTextField(labelWithString: "Mouse tuning without the bloat.")
        tagline.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        tagline.textColor = .secondaryLabelColor

        let text = NSStackView(views: [name, version, tagline])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        let header = NSStackView(views: [icon, text])
        header.spacing = 14
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        return header
    }

    private static func sectionTitle(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        return label
    }

    /// A rounded group like System Settings, with its rows stacked inside.
    private static func group(_ rows: [NSView]) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderColor = .separatorColor
        box.borderWidth = 0.5
        box.cornerRadius = 8
        box.fillColor = NSColor.labelColor.withAlphaComponent(0.04)
        box.contentViewMargins = .zero

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        box.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: groupPadding),
            stack.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -groupPadding),
            stack.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
        ])
        for row in rows {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return box
    }

    private static func hintLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .tertiaryLabelColor
        // Window width minus the window and group margins, so fitting sizes wrap correctly.
        label.preferredMaxLayoutWidth = width - 48 - 2 * groupPadding
        return label
    }
}
