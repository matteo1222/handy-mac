/// A key on the keyboard, named by meaning. Character keys are resolved to key codes through the
/// user's current layout at the moment they are posted, so ⌘Z is ⌘Z on AZERTY too.
public enum Key: Sendable, Hashable, Codable {
    case returnKey
    case escape
    case tab
    case space
    case delete
    case up
    case down
    case left
    case right
    case character(String)
}

public enum Modifier: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case control
    case option
    case shift
    case command

    public static func < (a: Modifier, b: Modifier) -> Bool {
        allCases.firstIndex(of: a) ?? 0 < allCases.firstIndex(of: b) ?? 0
    }

    public var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }
}

/// A key plus modifiers, e.g. ⌘Z.
public struct KeyChord: Sendable, Hashable, Codable, CustomStringConvertible {
    public var key: Key
    public var modifiers: Set<Modifier>

    public init(_ key: Key, _ modifiers: Set<Modifier> = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public var description: String {
        let keyName: String =
            switch key {
            case .returnKey: "Return"
            case .escape: "Esc"
            case .tab: "Tab"
            case .space: "Space"
            case .delete: "Delete"
            case .up: "↑"
            case .down: "↓"
            case .left: "←"
            case .right: "→"
            case .character(let character): character.uppercased()
            }
        return modifiers.sorted().map(\.symbol).joined() + keyName
    }
}

/// Something Handy does on the user's behalf. One typed value per action, projected to gesture
/// bindings, the menu bar and handyctl.
public enum Action: Sendable, Hashable, Codable {
    case key(KeyChord)
}

extension Action: CustomStringConvertible {
    public var description: String {
        switch self {
        case .key(let chord): chord.description
        }
    }
}

/// Which action each one-shot gesture fires.
public struct Bindings: Sendable, Hashable, Codable {
    public var oneShots: [PoseClass: Action]
    public var flicks: [Direction: Action]

    public init(oneShots: [PoseClass: Action], flicks: [Direction: Action]) {
        self.oneShots = oneShots
        self.flicks = flicks
    }

    public static let defaults = Bindings(
        oneShots: [
            .thumbsUp: .key(KeyChord(.returnKey)),
            .thumbsDown: .key(KeyChord(.escape)),
        ],
        flicks: [
            .up: .key(KeyChord(.up)),
            .down: .key(KeyChord(.down)),
            .left: .key(KeyChord(.left)),
            .right: .key(KeyChord(.right)),
        ])
}
