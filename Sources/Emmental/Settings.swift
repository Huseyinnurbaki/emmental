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

    /// Off until the user turns DPI control on, since it needs Input Monitoring.
    static var dpiEnabled: Bool {
        get { defaults.bool(forKey: "dpiEnabled") }
        set { defaults.set(newValue, forKey: "dpiEnabled") }
    }

    static var dpi: Int? {
        get { defaults.object(forKey: "dpi") as? Int }
        set { defaults.set(newValue, forKey: "dpi") }
    }

    /// nil until the user changes it, so the mouse keeps its own setting.
    static var smartShift: SmartShift? {
        get {
            guard let autoSwitch = defaults.object(forKey: "smartShiftAutoSwitch") as? Bool,
                  let threshold = defaults.object(forKey: "smartShiftThreshold") as? Int else { return nil }
            return SmartShift(autoSwitch: autoSwitch, threshold: threshold)
        }
        set {
            defaults.set(newValue?.autoSwitch, forKey: "smartShiftAutoSwitch")
            defaults.set(newValue?.threshold, forKey: "smartShiftThreshold")
        }
    }

    static var highResolutionScrolling: Bool? {
        get { defaults.object(forKey: "highResolutionScrolling") as? Bool }
        set { defaults.set(newValue, forKey: "highResolutionScrolling") }
    }

    private static func key(for control: SpeedControl) -> String {
        switch control {
        case .pointer: return "speed"
        case .scroll: return "scrollSpeed"
        }
    }
}
