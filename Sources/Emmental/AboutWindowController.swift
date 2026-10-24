import AppKit

/// Emmental's About window: icon and version, plus app-level settings like
/// opening at login, which don't belong next to the mouse controls in the menu.
final class AboutWindowController: NSWindowController {
    private let loginRow = SwitchRowView(title: "Open at login")

    init() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        window.title = "About Emmental"
        window.isReleasedWhenClosed = false
        super.init(window: window)

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown

        let name = NSTextField(labelWithString: "Emmental")
        name.font = .systemFont(ofSize: 20, weight: .semibold)

        let info = Bundle.main.infoDictionary ?? [:]
        let version = NSTextField(labelWithString:
            "Version \(info["CFBundleShortVersionString"] ?? "?") (\(info["CFBundleVersion"] ?? "?"))")
        version.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        version.textColor = .secondaryLabelColor

        let tagline = NSTextField(labelWithString: "Mouse tuning without the bloat.")
        tagline.textColor = .secondaryLabelColor

        // Settings sit in a rounded group, like System Settings.
        let group = NSBox()
        group.boxType = .custom
        group.borderColor = .separatorColor
        group.borderWidth = 0.5
        group.cornerRadius = 8
        group.fillColor = NSColor.labelColor.withAlphaComponent(0.04)
        group.contentViewMargins = .zero
        loginRow.translatesAutoresizingMaskIntoConstraints = false
        group.contentView?.addSubview(loginRow)

        loginRow.onToggle = { [weak self] isOn in
            do {
                try LoginItem.setEnabled(isOn)
            } catch {
                NSSound.beep()
                self?.loginRow.isOn = LoginItem.isEnabled
            }
        }

        let stack = NSStackView(views: [icon, name, version, tagline, group])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.setCustomSpacing(12, after: icon)
        stack.setCustomSpacing(12, after: version)
        stack.setCustomSpacing(22, after: tagline)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // A stack view as the window's content view ignores its edge insets, so
        // pin it inside a plain container with explicit margins instead.
        let content = NSView()
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            content.widthAnchor.constraint(equalToConstant: 300),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            icon.widthAnchor.constraint(equalToConstant: 96),
            icon.heightAnchor.constraint(equalToConstant: 96),
            group.widthAnchor.constraint(equalTo: stack.widthAnchor),
            loginRow.leadingAnchor.constraint(equalTo: group.leadingAnchor, constant: 12),
            loginRow.trailingAnchor.constraint(equalTo: group.trailingAnchor, constant: -10),
            loginRow.topAnchor.constraint(equalTo: group.topAnchor, constant: 9),
            loginRow.bottomAnchor.constraint(equalTo: group.bottomAnchor, constant: -9),
        ])
        window.contentView = content
        window.setContentSize(content.fittingSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        loginRow.isOn = LoginItem.isEnabled
        if window?.isVisible == false { window?.center() }
        // A menu bar app has no Dock icon, so bring it forward or the window opens behind others.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
