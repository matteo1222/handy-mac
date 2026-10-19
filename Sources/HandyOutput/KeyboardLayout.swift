import Carbon.HIToolbox
import HandyCore

/// Resolves keys to virtual key codes. Named keys have fixed codes; character keys are looked up
/// in the user's current keyboard layout, so a shortcut lands on the right key on any layout.
@MainActor
public enum KeyboardLayout {
    public static func keyCode(for key: Key) -> CGKeyCode? {
        switch key {
        case .returnKey: CGKeyCode(kVK_Return)
        case .escape: CGKeyCode(kVK_Escape)
        case .tab: CGKeyCode(kVK_Tab)
        case .space: CGKeyCode(kVK_Space)
        case .delete: CGKeyCode(kVK_Delete)
        case .up: CGKeyCode(kVK_UpArrow)
        case .down: CGKeyCode(kVK_DownArrow)
        case .left: CGKeyCode(kVK_LeftArrow)
        case .right: CGKeyCode(kVK_RightArrow)
        case .character(let character): currentLayoutTable()[character.lowercased()]
        }
    }

    /// Character → key code for every key in the current layout, without modifiers.
    static func currentLayoutTable() -> [String: CGKeyCode] {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return [:] }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        var table: [String: CGKeyCode] = [:]
        data.withUnsafeBytes { raw in
            guard let layout = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var characters = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, UInt16(code), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
                guard status == noErr, length > 0 else { continue }
                let string = String(utf16CodeUnits: characters, count: length).lowercased()
                if table[string] == nil { table[string] = CGKeyCode(code) }
            }
        }
        return table
    }
}
