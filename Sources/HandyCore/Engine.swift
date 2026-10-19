/// The gesture engine: a pure reducer over explicit states.
///
/// It reads no clock. Every input carries its own timestamp, so a recorded stream replays
/// to the same events every time.
public struct Engine: Sendable {
    public private(set) var mode: Mode = .off

    public init(mode: Mode = .off) {
        self.mode = mode
    }

    public mutating func handle(_ input: Input) -> [Event] {
        switch input {
        case .command(let command):
            return handle(command)
        case .frame:
            return []
        }
    }

    private mutating func handle(_ command: Command) -> [Event] {
        let next: Mode
        switch command {
        case .start: next = mode == .off ? .watching : mode
        case .stop: next = .off
        case .toggle: next = mode == .off ? .watching : .off
        }
        return transition(to: next)
    }

    private mutating func transition(to next: Mode) -> [Event] {
        guard next != mode else { return [] }
        mode = next
        return [.modeChanged(next)]
    }
}

extension Engine {
    public enum Mode: String, Sendable, Codable, CaseIterable {
        case off
        case watching
    }

    /// User-level commands from the menu bar, the hotkey or handyctl.
    public enum Command: String, Sendable, Codable, CaseIterable {
        case start
        case stop
        case toggle
    }

    public enum Input: Sendable, Equatable {
        case command(Command)
        case frame(FrameFeatures)
    }

    public enum Event: Sendable, Equatable, Codable {
        case modeChanged(Mode)
    }
}
