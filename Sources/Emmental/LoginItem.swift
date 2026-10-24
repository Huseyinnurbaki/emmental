import Foundation

/// Starts Emmental at login with a per-user LaunchAgent. `SMAppService` needs the
/// macOS 13 SDK, so this writes the agent plist directly. The plist exists only
/// while the setting is on; turning it off removes the file entirely.
enum LoginItem {
    private static let label = Bundle.main.bundleIdentifier ?? "app.emmental.Emmental"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try writePlist()
        } else if isEnabled {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    /// Points the agent at wherever the app runs from now, so moving the app
    /// (say, from build/ into /Applications) doesn't leave a stale path behind.
    static func refreshIfEnabled() {
        guard isEnabled else { return }
        try? writePlist()
    }

    private static func writePlist() throws {
        guard let executable = Bundle.main.executablePath else { return }
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
            // Shows the job as Emmental in System Settings › Login Items.
            "AssociatedBundleIdentifiers": [label],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)
    }
}
