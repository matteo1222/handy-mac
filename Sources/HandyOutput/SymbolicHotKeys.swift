import Carbon.HIToolbox
import Foundation
import HandyCore

/// The user's own shortcuts for Spaces and Mission Control, read from System Settings
/// (com.apple.symbolichotkeys). Missing entries mean the system default; disabled ones fall back
/// to the default so the action still works.
public enum SymbolicHotKeys {
    /// Symbolic hotkey IDs: Mission Control 32, move left a space 79, move right a space 81.
    static let ids: [Action: Int] = [.missionControl: 32, .previousSpace: 79, .nextSpace: 81]

    static let defaults: [Action: KeyChord] = [
        .missionControl: KeyChord(.up, [.control]),
        .previousSpace: KeyChord(.left, [.control]),
        .nextSpace: KeyChord(.right, [.control]),
    ]

    public static func chord(for action: Action, in table: [String: Any]? = currentTable()) -> KeyChord? {
        guard let id = ids[action], let fallback = defaults[action] else { return nil }
        guard let entry = table?[String(id)] as? [String: Any],
            let value = entry["value"] as? [String: Any],
            let numbers = value["parameters"] as? [NSNumber], numbers.count == 3,
            (entry["enabled"] as? Bool) ?? true
        else { return fallback }
        let parameters = numbers.map { Int(truncatingIfNeeded: $0.int64Value) }
        return KeyChord(key(forCode: parameters[1]), modifiers(parameters[2]))
    }

    public static func currentTable() -> [String: Any]? {
        UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys")
    }

    static func modifiers(_ mask: Int) -> Set<Modifier> {
        var result: Set<Modifier> = []
        if mask & 0x20000 != 0 { result.insert(.shift) }
        if mask & 0x40000 != 0 { result.insert(.control) }
        if mask & 0x80000 != 0 { result.insert(.option) }
        if mask & 0x100000 != 0 { result.insert(.command) }
        return result
    }

    static func key(forCode code: Int) -> Key {
        switch code {
        case kVK_LeftArrow: .left
        case kVK_RightArrow: .right
        case kVK_UpArrow: .up
        case kVK_DownArrow: .down
        default: .code(code)
        }
    }
}
