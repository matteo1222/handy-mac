import ApplicationServices

public enum AccessibilityPermission {
    /// Whether this process may post input events to other apps.
    public static var isGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to Privacy & Security, then returns the current state.
    @discardableResult
    public static func request() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
