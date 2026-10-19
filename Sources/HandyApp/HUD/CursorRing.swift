import AppKit
import SwiftUI

/// The pinch preview: a ring around the cursor that tightens as the fingers close and fills
/// when the press registers. Click-through and excluded from screen capture, like the HUD.
@MainActor
final class CursorRingPanel {
    private let panel: NSPanel
    private let host: NSHostingView<CursorRingView>
    private static let size = 56.0

    init() {
        host = NSHostingView(rootView: CursorRingView(closeness: 0, pressed: false))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.sharingType = .none
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    /// Centres the ring on the cursor. `closeness` nil hides it.
    func update(closeness: Double?, pressed: Bool) {
        guard let closeness else {
            panel.orderOut(nil)
            return
        }
        host.rootView = CursorRingView(closeness: closeness, pressed: pressed)
        let mouse = NSEvent.mouseLocation
        panel.setFrameOrigin(NSPoint(x: mouse.x - Self.size / 2, y: mouse.y - Self.size / 2))
        if !panel.isVisible { panel.orderFrontRegardless() }
    }
}

struct CursorRingView: View {
    let closeness: Double
    let pressed: Bool

    var body: some View {
        let diameter = 44 - 26 * closeness
        Circle()
            .strokeBorder(Color.accentColor.opacity(0.35 + 0.65 * closeness), lineWidth: pressed ? 3 : 2)
            .background(Circle().fill(Color.accentColor.opacity(pressed ? 0.35 : 0)))
            .frame(width: diameter, height: diameter)
            .frame(width: 56, height: 56)
            .accessibilityHidden(true)
    }
}
