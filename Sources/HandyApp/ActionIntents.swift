import AppIntents
import HandyCore

/// The catalog as an App Intents enum, so Shortcuts and Spotlight can run any Handy action.
enum HandyActionEnum: String, AppEnum {
    case newTab, closeTab, switchApp, copy, paste, undo, redo, find, space, tab, returnKey, escape
    case missionControl, previousSpace, nextSpace, dictation, zoomIn, zoomOut

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Handy Action"

    static let caseDisplayRepresentations: [HandyActionEnum: DisplayRepresentation] = Dictionary(
        uniqueKeysWithValues: allCases.compactMap { item in
            item.named.map { (item, DisplayRepresentation(title: "\($0.title)")) }
        })

    var named: NamedAction? { NamedAction(rawValue: rawValue) }
}

/// "Perform Handy Action" in Shortcuts.
struct PerformHandyActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Perform Handy Action"
    static let description = IntentDescription("Runs one of Handy's actions, as if its gesture fired.")

    @Parameter(title: "Action")
    var action: HandyActionEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        if let named = action.named { AppModel.current?.perform(named) }
        return .result()
    }
}
