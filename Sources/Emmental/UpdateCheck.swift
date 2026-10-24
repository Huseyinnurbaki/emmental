import Foundation

/// The manual "Check for Updates" in Settings. It reads the website's
/// version.json and compares it with this build's version. It only runs when
/// clicked: no background checks, no cookies or cache, and nothing is sent
/// beyond the request itself. Installing is a separate click (see Updater).
enum UpdateCheck {
    enum Result {
        case upToDate(version: String)
        /// `page` is the website; `zip` is that version's release download,
        /// for Install Update.
        case available(version: String, page: URL, zip: URL?)
        case failed
    }

    static let feed = URL(string: "https://emmental.artichoke.monster/version.json")!
    static let site = URL(string: "https://emmental.artichoke.monster/")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    private struct Feed: Decodable {
        let version: String
        let url: String?
        let download: String?
    }

    static func run(_ completion: @escaping (Result) -> Void) {
        let request = URLRequest(url: feed, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        URLSession(configuration: .ephemeral).dataTask(with: request) { data, response, _ in
            let result: Result
            if (response as? HTTPURLResponse)?.statusCode == 200,
               let data = data, let latest = try? JSONDecoder().decode(Feed.self, from: data) {
                result = isNewer(latest.version, than: currentVersion)
                    ? .available(version: latest.version,
                                 page: latest.url.flatMap(URL.init(string:)) ?? site,
                                 zip: latest.download.flatMap(URL.init(string:)))
                    : .upToDate(version: currentVersion)
            } else {
                result = .failed
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    /// Compares dotted versions numerically, so 0.10.0 is newer than 0.9.0.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
