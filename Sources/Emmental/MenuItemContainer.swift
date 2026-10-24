import AppKit

/// Wraps a view for use as a menu item's view: the menu's width, with the
/// same insets as standard menu items so custom rows line up with them.
final class MenuItemContainer: NSView {
    static let width: CGFloat = 260

    init(_ content: NSView, top: CGFloat = 6, bottom: CGFloat = 6) {
        super.init(frame: .zero)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.width),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: topAnchor, constant: top),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -bottom),
        ])
        fitToContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Call after the content's height changes, e.g. when rows show or hide.
    func fitToContent() {
        setFrameSize(fittingSize)
    }
}
