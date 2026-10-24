import Foundation
import Security
import os

private let log = Logger(subsystem: "app.emmental.Emmental", category: "Update")

/// Installs an update the user asked for in Settings: downloads the release
/// zip, checks it's genuinely Emmental, signed by the same identity and newer,
/// then swaps it in (the old copy goes to the Trash). Emmental downloads the
/// file itself, so macOS doesn't flag it as downloaded and there's no Open
/// Anyway step. Nothing here runs unless the user clicks Install Update.
enum Updater {
    enum Failure: Error {
        case download, unzip, notGenuine, wrongVersion, install
    }

    /// Calls back on the main queue with the installed app's location.
    static func install(from zip: URL, version: String, replacing app: URL,
                        completion: @escaping (Result<URL, Failure>) -> Void) {
        URLSession(configuration: .ephemeral).downloadTask(with: zip) { file, response, _ in
            // The downloaded file is deleted when this handler returns, so do
            // all the work in here.
            let result: Result<URL, Failure>
            if let file = file, (response as? HTTPURLResponse)?.statusCode == 200 {
                result = verifyAndSwap(downloaded: file, version: version, replacing: app)
            } else {
                result = .failure(.download)
            }
            if case let .failure(failure) = result {
                log.error("Update to \(version, privacy: .public) failed: \(String(describing: failure), privacy: .public)")
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func verifyAndSwap(downloaded zip: URL, version: String, replacing app: URL) -> Result<URL, Failure> {
        let files = FileManager.default
        let work = files.temporaryDirectory.appendingPathComponent("emmental-update-\(UUID().uuidString)")
        defer { try? files.removeItem(at: work) }
        guard (try? files.createDirectory(at: work, withIntermediateDirectories: true)) != nil,
              run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path]) else { return .failure(.unzip) }

        let update = work.appendingPathComponent("Emmental.app")
        guard isGenuine(update, comparedTo: app) else { return .failure(.notGenuine) }
        guard let newVersion = shortVersion(of: update), newVersion == version,
              UpdateCheck.isNewer(newVersion, than: shortVersion(of: app) ?? "0") else { return .failure(.wrongVersion) }

        // Trash the current copy rather than delete it, and put it back if the
        // new one can't take its place.
        var trashed: NSURL?
        do {
            try files.trashItem(at: app, resultingItemURL: &trashed)
            try files.moveItem(at: update, to: app)
        } catch {
            if let trashed = trashed as URL?, !files.fileExists(atPath: app.path) {
                try? files.moveItem(at: trashed, to: app)
            }
            return .failure(.install)
        }
        log.notice("Installed update \(version, privacy: .public)")
        return .success(app)
    }

    /// The update has to meet the installed app's own designated requirement:
    /// the same bundle ID, signed by the same certificate. A tampered zip, or
    /// anything signed by someone else, fails here and is never installed.
    private static func isGenuine(_ candidate: URL, comparedTo installed: URL) -> Bool {
        var installedCode: SecStaticCode?, candidateCode: SecStaticCode?, requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(installed as CFURL, [], &installedCode) == errSecSuccess,
              let installedCode = installedCode,
              SecCodeCopyDesignatedRequirement(installedCode, [], &requirement) == errSecSuccess,
              let requirement = requirement,
              SecStaticCodeCreateWithPath(candidate as CFURL, [], &candidateCode) == errSecSuccess,
              let candidateCode = candidateCode else { return false }
        let checks = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        return SecStaticCodeCheckValidity(candidateCode, checks, requirement) == errSecSuccess
    }

    private static func shortVersion(of app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }

    private static func run(_ tool: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
