import HandyCore
import Testing

@testable import HandyApp

/// Every catalog action must reach every surface: palette slots, the menu bar, Shortcuts and handyctl.
@MainActor
@Test(arguments: NamedAction.allCases)
func everyActionHasEveryProjection(_ action: NamedAction) {
    let intent = HandyActionEnum(rawValue: action.rawValue)
    #expect(intent != nil, "App Intent enum is missing \(action)")
    #expect(
        intent.flatMap { HandyActionEnum.caseDisplayRepresentations[$0] } != nil, "no Shortcuts title for \(action)")
    #expect(ActionMenu.items.contains(action), "menu bar is missing \(action)")
    #expect(PaletteEditor.options.contains(action), "palette editor is missing \(action)")
    #expect(NamedAction(rawValue: action.rawValue) == action, "handyctl cannot name \(action)")
    #expect(!action.title.isEmpty && !action.symbol.isEmpty)
}

@Test func theAppIntentEnumHasNothingTheCatalogLacks() {
    #expect(Set(HandyActionEnum.allCases.map(\.rawValue)) == Set(NamedAction.allCases.map(\.rawValue)))
}
