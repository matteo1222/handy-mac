import Carbon.HIToolbox

/// A system-wide hotkey registered with Carbon, which needs no Accessibility permission.
/// The handler runs on the main thread.
@MainActor
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let id: UInt32
    private let action: @MainActor () -> Void
    private static var nextID: UInt32 = 1

    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // Every handler sees every hotkey press in the app; each answers only its own ID.
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData, let event else { return OSStatus(eventNotHandledErr) }
                var pressed = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &pressed)
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
                    hotKey.action()
                    return noErr
                }
            },
            1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        guard status == noErr else { return nil }
        let id = EventHotKeyID(signature: OSType(0x4844_4E59), id: id)
        let registered = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else { return nil }
    }

    isolated deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}

extension GlobalHotKey {
    /// ⌃⌥⌘H stops Handy from any state.
    static let stopKeyCode = UInt32(kVK_ANSI_H)
    static let stopModifiers = UInt32(controlKey | optionKey | cmdKey)
    static let stopDisplay = "⌃⌥⌘H"

    /// ⌃⌥⌘/ shows or hides the cheat sheet.
    static let cheatSheetKeyCode = UInt32(kVK_ANSI_Slash)
    static let cheatSheetDisplay = "⌃⌥⌘/"
}
