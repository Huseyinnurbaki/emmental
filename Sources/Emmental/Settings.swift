import Foundation

/// The user's chosen speed, persisted across launches. `speed` is nil until the
/// user first touches the slider, so a fresh install never changes anything.
enum Settings {
    private static let defaults = UserDefaults.standard

    static var speed: Double? {
        get { defaults.object(forKey: "speed") as? Double }
        set { defaults.set(newValue, forKey: "speed") }
    }
}
