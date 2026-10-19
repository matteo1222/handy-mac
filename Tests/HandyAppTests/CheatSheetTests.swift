import HandyCore
import Testing

@testable import HandyApp

/// The cheat sheet lists every gesture the engine knows, with a plain instruction and its effect.
@MainActor
@Test(arguments: HandyCore.Gesture.allCases)
func everyGestureIsOnTheCheatSheet(_ gesture: HandyCore.Gesture) {
    #expect(GestureGuide.guide[gesture] != nil, "\(gesture) has no cheat-sheet entry")
    let entry = GestureGuide.entry(for: gesture, bindings: .defaults, app: nil)
    #expect(!entry.how.isEmpty && !entry.does.isEmpty && !entry.symbol.isEmpty)
}

@MainActor
@Test func cheatSheetShowsTheCurrentBindings() {
    var bindings = Bindings.defaults
    bindings.oneShots[.thumbsUp] = .key(KeyChord(.tab))
    #expect(GestureGuide.entry(for: .thumbsUp, bindings: bindings, app: nil).does == "Tab")
    bindings.palette.perApp["com.apple.Safari"] = PaletteLayout(slots: [.find])
    #expect(GestureGuide.entry(for: .palette, bindings: bindings, app: "com.apple.Safari").does == "Find")
}
