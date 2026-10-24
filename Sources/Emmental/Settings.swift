import Foundation

/// The user's chosen speeds, persisted across launches. A speed is nil until the
/// user first moves its slider, so a fresh install never changes anything.
enum Settings {
    private static let defaults = UserDefaults.standard

    static func value(for control: SpeedControl) -> Double? {
        defaults.object(forKey: key(for: control)) as? Double
    }

    static func setValue(_ value: Double, for control: SpeedControl) {
        defaults.set(value, forKey: key(for: control))
    }

    private static func key(for control: SpeedControl) -> String {
        switch control {
        case .pointer: return "speed"
        case .scroll: return "scrollSpeed"
        }
    }
}
