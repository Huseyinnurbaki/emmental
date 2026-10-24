import AppKit
import os

private let log = Logger(subsystem: "app.emmental.Emmental", category: "App")

/// Offers to move Emmental into /Applications on launch. An app opened straight
/// from Downloads runs from a random read-only copy (App Translocation), so
/// open at login would point at a path that's gone by the next login. Anything
/// replaced goes to the Trash, never deleted outright.
enum MoveToApplications {
    private static let declinedKey = "declinedMoveToApplications"
    private static let destination = URL(fileURLWithPath: "/Applications/Emmental.app")

    /// Returns true when Emmental is moving and about to relaunch, so launch
    /// should stop here.
    static func offerIfNeeded() -> Bool {
        let current = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard needsMove(current), !UserDefaults.standard.bool(forKey: declinedKey) else { return false }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move Emmental to Applications?"
        alert.informativeText = "Emmental needs to live in Applications to open at login and keep your settings. It will move itself there and reopen."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Don't Move")
        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(true, forKey: declinedKey)
            return false
        }

        do {
            try move(from: current)
        } catch {
            log.error("Move to Applications failed: \(error.localizedDescription, privacy: .public)")
            let failed = NSAlert()
            failed.messageText = "Couldn't move Emmental"
            failed.informativeText = "Drag Emmental into your Applications folder in Finder, then open it from there."
            failed.runModal()
            return false
        }
        relaunch(destination)
        return true
    }

    /// Already in an Applications folder, or a local development build in
    /// build/, needs no move.
    static func needsMove(_ url: URL) -> Bool {
        let folder = url.deletingLastPathComponent()
        let applications = ["/Applications", NSHomeDirectory() + "/Applications"]
        let developmentBuild = ["build", "release"].contains(folder.lastPathComponent)
        return !applications.contains(folder.path) && !developmentBuild
    }

    private static func move(from current: URL) throws {
        let files = FileManager.default
        // Where the user actually put it, if macOS is running a translocated copy.
        let original = originalURL(ofTranslocated: current) ?? current

        if files.fileExists(atPath: destination.path) {
            try files.trashItem(at: destination, resultingItemURL: nil)
        }
        try files.copyItem(at: current, to: destination)
        // The user already approved this app (Open Anyway); clearing the
        // download flag on the moved copy keeps macOS from asking again.
        let clear = Process()
        clear.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        clear.arguments = ["-dr", "com.apple.quarantine", destination.path]
        try clear.run()
        clear.waitUntilExit()

        log.notice("Moved to Applications from \(original.path, privacy: .public)")
        if original != destination {
            try? files.trashItem(at: original, resultingItemURL: nil)
        }
    }

    private static func relaunch(_ app: URL) {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/bin/sh")
        open.arguments = ["-c", "sleep 0.5; open \"$0\"", app.path]
        try? open.run()
        NSApp.terminate(nil)
    }

    /// macOS has no public API for this; Security.framework exports it.
    private typealias OriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
    private static func originalURL(ofTranslocated url: URL) -> URL? {
        guard url.path.contains("/AppTranslocation/"),
              let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL") else { return nil }
        let original = unsafeBitCast(symbol, to: OriginalPath.self)
        return original(url as CFURL, nil)?.takeRetainedValue() as URL?
    }
}
