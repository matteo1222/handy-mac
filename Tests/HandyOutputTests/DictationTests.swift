import Foundation
import HandyCore
import Testing

@testable import HandyOutput

@Test func readsTheDictationShortcutFromSystemSettings() {
    let controlTwice: [String: Any] = [
        "164": [
            "enabled": true,
            "value": [
                "type": "modifier",
                "parameters": [NSNumber(value: 262_144), NSNumber(value: UInt64(18_446_744_073_709_289_471))],
            ],
        ]
    ]
    #expect(DictationShortcut.current(hotKeys: controlTwice, dictationEnabled: true) == .doubleTap(.control))
    #expect(DictationShortcut.current(hotKeys: [:], dictationEnabled: true) == .globe)
    let custom: [String: Any] = [
        "164": ["enabled": true, "value": ["type": "standard", "parameters": [100, 2, 0x100000]]]
    ]
    #expect(
        DictationShortcut.current(hotKeys: custom, dictationEnabled: true) == .chord(KeyChord(.code(2), [.command])))
}

@Test func dictationOffOrShortcutOffIsUnavailable() {
    #expect(DictationShortcut.current(hotKeys: [:], dictationEnabled: false) == nil)
    let off: [String: Any] = ["164": ["enabled": false]]
    #expect(DictationShortcut.current(hotKeys: off, dictationEnabled: true) == nil)
}

@MainActor
@Test func toggleDictationSendsTheShortcutOrFlagsItMissing() {
    let sink = RecordingSink()
    let driver = OutputDriver(
        sink: sink, environment: VirtualPointerEnvironment(screens: [Rect(x: 0, y: 0, width: 100, height: 100)]))
    driver.dictation = { .doubleTap(.control) }
    driver.perform(.toggleDictation)
    #expect(sink.actions == [.modifierDoubleTap(.control)])
    driver.dictation = { nil }
    driver.perform(.toggleDictation)
    #expect(sink.actions.count == 1)
    #expect(driver.dictationUnavailable)
}
