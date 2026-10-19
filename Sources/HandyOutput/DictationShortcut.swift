import Carbon.HIToolbox
import Foundation
import HandyCore

/// How the user starts Dictation, read from System Settings → Keyboard → Dictation.
public enum DictationShortcut: Sendable, Equatable {
    /// "Press <modifier> twice" (Control, Command or Option, as macOS offers).
    case doubleTap(Modifier)
    /// A custom shortcut.
    case chord(KeyChord)
    /// "Press 🎤" or "Press Globe twice": the default when no shortcut is stored.
    case globe

    public var description: String {
        switch self {
        case .doubleTap(let modifier): "\(modifier.symbol) twice"
        case .chord(let chord): chord.description
        case .globe: "🌐 twice"
        }
    }

    /// Nil when Dictation is off or its shortcut is turned off, which the user must fix in System Settings.
    public static func current(
        hotKeys: [String: Any]? = SymbolicHotKeys.currentTable(),
        dictationEnabled: Bool = UserDefaults(suiteName: "com.apple.assistant.support")?.bool(
            forKey: "Dictation Enabled") ?? false
    ) -> DictationShortcut? {
        guard dictationEnabled else { return nil }
        guard let entry = hotKeys?["164"] as? [String: Any] else { return .globe }
        guard (entry["enabled"] as? Bool) ?? true else { return nil }
        // Parameters can exceed Int (the side-of-keyboard mask is an unsigned 64-bit value), so read NSNumbers.
        guard let value = entry["value"] as? [String: Any], let numbers = value["parameters"] as? [NSNumber] else {
            return .globe
        }
        let parameters = numbers.map { Int(truncatingIfNeeded: $0.int64Value) }
        switch value["type"] as? String {
        case "modifier":
            let modifiers = SymbolicHotKeys.modifiers(parameters.first ?? 0)
            return modifiers.first.map(DictationShortcut.doubleTap) ?? .globe
        case "standard" where parameters.count == 3:
            return .chord(
                KeyChord(SymbolicHotKeys.key(forCode: parameters[1]), SymbolicHotKeys.modifiers(parameters[2])))
        default:
            return .globe
        }
    }

    /// System Settings → Keyboard, where Dictation and its shortcut live.
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
}
