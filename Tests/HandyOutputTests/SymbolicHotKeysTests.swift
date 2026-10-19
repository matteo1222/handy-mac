import HandyCore
import Testing

@testable import HandyOutput

@Test func missingOrDisabledShortcutsFallBackToTheSystemDefaults() {
    #expect(SymbolicHotKeys.chord(for: .nextSpace, in: [:]) == KeyChord(.right, [.control]))
    let disabled: [String: Any] = ["79": ["enabled": false, "value": ["parameters": [65535, 123, 262144]]]]
    #expect(SymbolicHotKeys.chord(for: .previousSpace, in: disabled) == KeyChord(.left, [.control]))
    #expect(SymbolicHotKeys.chord(for: .missionControl, in: nil) == KeyChord(.up, [.control]))
}

@Test func customShortcutsAreReadFromSystemSettings() {
    // ⌥⌘← as "Move left a space": key code 123, option (0x80000) + command (0x100000).
    let custom: [String: Any] = ["79": ["enabled": true, "value": ["parameters": [65535, 123, 0x180000]]]]
    #expect(SymbolicHotKeys.chord(for: .previousSpace, in: custom) == KeyChord(.left, [.option, .command]))
    let f3: [String: Any] = ["32": ["enabled": true, "value": ["parameters": [65535, 160, 0]]]]
    #expect(SymbolicHotKeys.chord(for: .missionControl, in: f3) == KeyChord(.code(160)))
}
