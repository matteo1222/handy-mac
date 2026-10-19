import AppIntents
import HandyCore

/// The catalog as an App Intents enum, so Shortcuts and Spotlight can run any Handy action.
enum HandyActionEnum: String, AppEnum {
    case newTab, closeTab, switchApp, copy, paste, undo, redo, find, space, tab, returnKey, escape
    case missionControl, previousSpace, nextSpace, dictation, zoomIn, zoomOut

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Handy Action"

    /// A literal, because Apple's App Intents metadata extractor reads it at build time. The projection
    /// test checks each title against `NamedAction.title`.
    static let caseDisplayRepresentations: [HandyActionEnum: DisplayRepresentation] = [
        .newTab: "New Tab",
        .closeTab: "Close Tab",
        .switchApp: "Switch App",
        .copy: "Copy",
        .paste: "Paste",
        .undo: "Undo",
        .redo: "Redo",
        .find: "Find",
        .space: "Play/Pause",
        .tab: "Tab",
        .returnKey: "Return",
        .escape: "Escape",
        .missionControl: "Mission Control",
        .previousSpace: "Previous Space",
        .nextSpace: "Next Space",
        .dictation: "Dictation",
        .zoomIn: "Zoom In",
        .zoomOut: "Zoom Out",
    ]

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
