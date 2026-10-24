import AppKit

/// A menu row with a title and a switch, laid out like the slider sections
/// instead of a plain checkmark item.
final class SwitchMenuView: NSView {
    var onToggle: ((Bool) -> Void)?

    var isOn: Bool {
        get { toggle.state == .on }
        set { toggle.state = newValue ? .on : .off }
    }

    private let toggle = NSSwitch()

    init(title: String) {
        super.init(frame: .zero)

        toggle.controlSize = .mini
        toggle.target = self
        toggle.action = #selector(toggled)

        let row = NSStackView(views: [NSTextField(labelWithString: title), NSView(), toggle])
        row.edgeInsets = NSEdgeInsets(top: 4, left: 20, bottom: 4, right: 16)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            widthAnchor.constraint(equalToConstant: 260),
        ])
        setFrameSize(fittingSize)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func toggled() {
        onToggle?(isOn)
    }
}
