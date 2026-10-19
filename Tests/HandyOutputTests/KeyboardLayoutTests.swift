import Carbon.HIToolbox
import HandyCore
import HandyOutput
import Testing

@MainActor
@Test func namedKeysUseFixedVirtualKeyCodes() {
    #expect(KeyboardLayout.keyCode(for: .returnKey) == CGKeyCode(kVK_Return))
    #expect(KeyboardLayout.keyCode(for: .escape) == CGKeyCode(kVK_Escape))
    #expect(KeyboardLayout.keyCode(for: .up) == CGKeyCode(kVK_UpArrow))
}

@MainActor
@Test func characterKeysResolveThroughTheCurrentLayout() throws {
    for letter in "abcdefghijklmnopqrstuvwxyz" {
        #expect(KeyboardLayout.keyCode(for: .character(String(letter))) != nil, "\(letter) has a key in this layout")
    }
    #expect(KeyboardLayout.keyCode(for: .character("Z")) == KeyboardLayout.keyCode(for: .character("z")))
}

@Test func chordsDescribeThemselvesLikeMenus() {
    #expect(KeyChord(.character("z"), [.command]).description == "⌘Z")
    #expect(KeyChord(.tab, [.command, .shift]).description == "⇧⌘Tab")
    #expect(KeyChord(.returnKey).description == "Return")
}
