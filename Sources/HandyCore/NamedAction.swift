/// The catalog of actions a user can put on palette slots, run from the menu bar, call from
/// Shortcuts or trigger with `handyctl perform`. One typed value per action; every projection
/// iterates `allCases`, and a test fails if one is missing.
public enum NamedAction: String, Sendable, Codable, CaseIterable {
    case newTab
    case closeTab
    case switchApp
    case copy
    case paste
    case undo
    case redo
    case find
    case space
    case tab
    case returnKey
    case escape
    case missionControl
    case previousSpace
    case nextSpace
    case dictation
    case zoomIn
    case zoomOut

    public var action: Action {
        func key(_ character: String, _ modifiers: Set<Modifier> = [.command]) -> Action {
            .key(KeyChord(.character(character), modifiers))
        }
        return switch self {
        case .newTab: key("t")
        case .closeTab: key("w")
        case .switchApp: .key(KeyChord(.tab, [.command]))
        case .copy: key("c")
        case .paste: key("v")
        case .undo: key("z")
        case .redo: key("z", [.command, .shift])
        case .find: key("f")
        case .space: .key(KeyChord(.space))
        case .tab: .key(KeyChord(.tab))
        case .returnKey: .key(KeyChord(.returnKey))
        case .escape: .key(KeyChord(.escape))
        case .missionControl: .missionControl
        case .previousSpace: .previousSpace
        case .nextSpace: .nextSpace
        case .dictation: .toggleDictation
        case .zoomIn: key("=")
        case .zoomOut: key("-")
        }
    }

    public var title: String {
        switch self {
        case .newTab: "New Tab"
        case .closeTab: "Close Tab"
        case .switchApp: "Switch App"
        case .copy: "Copy"
        case .paste: "Paste"
        case .undo: "Undo"
        case .redo: "Redo"
        case .find: "Find"
        case .space: "Play/Pause"
        case .tab: "Tab"
        case .returnKey: "Return"
        case .escape: "Escape"
        case .missionControl: "Mission Control"
        case .previousSpace: "Previous Space"
        case .nextSpace: "Next Space"
        case .dictation: "Dictation"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        }
    }

    /// SF Symbol for the palette and menus.
    public var symbol: String {
        switch self {
        case .newTab: "plus.square.on.square"
        case .closeTab: "xmark.square"
        case .switchApp: "rectangle.2.swap"
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .find: "magnifyingglass"
        case .space: "playpause"
        case .tab: "arrow.right.to.line"
        case .returnKey: "return"
        case .escape: "escape"
        case .missionControl: "rectangle.3.group"
        case .previousSpace: "arrow.left.square"
        case .nextSpace: "arrow.right.square"
        case .dictation: "mic"
        case .zoomIn: "plus.magnifyingglass"
        case .zoomOut: "minus.magnifyingglass"
        }
    }
}

/// Eight palette slots, clockwise from the top. Nil leaves a slot empty.
public struct PaletteLayout: Sendable, Hashable, Codable {
    public static let slotCount = 8
    public var slots: [NamedAction?]

    public init(slots: [NamedAction?]) {
        self.slots = Array((slots + Array(repeating: nil, count: Self.slotCount)).prefix(Self.slotCount))
    }

    public static let standard = PaletteLayout(slots: [
        .newTab, .copy, .switchApp, .paste, .closeTab, .undo, .space, .missionControl,
    ])
}

/// The palette everywhere, with per-app layouts keyed by bundle identifier.
public struct PaletteBindings: Sendable, Hashable, Codable {
    public var standard: PaletteLayout
    public var perApp: [String: PaletteLayout]

    public init(standard: PaletteLayout = .standard, perApp: [String: PaletteLayout] = [:]) {
        self.standard = standard
        self.perApp = perApp
    }

    public func layout(for app: String?) -> PaletteLayout {
        app.flatMap { perApp[$0] } ?? standard
    }
}
