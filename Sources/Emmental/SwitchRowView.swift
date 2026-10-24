import AppKit

/// A title on the left and a switch on the right. The caller sets its width.
final class SwitchRowView: NSView {
    var onToggle: ((Bool) -> Void)?

    var isOn: Bool {
        get { toggle.state == .on }
        set { toggle.state = newValue ? .on : .off }
    }

    private let toggle = NSSwitch()

    init(title: String) {
        super.init(frame: .zero)

        toggle.controlSize = .small
        toggle.target = self
        toggle.action = #selector(toggled)

        let row = NSStackView(views: [NSTextField(labelWithString: title), NSView(), toggle])
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func toggled() {
        onToggle?(isOn)
    }
}
