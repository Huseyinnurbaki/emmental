import AppKit

extension NSApplication {
    /// Opens `app` a moment after this copy quits, so the two don't overlap.
    /// Used after granting Input Monitoring, moving to Applications and updating.
    func relaunch(_ app: URL = Bundle.main.bundleURL) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/bin/sh")
        open.arguments = ["-c", "sleep 0.5; open \"$0\"", app.path]
        try? open.run()
        terminate(nil)
    }
}
