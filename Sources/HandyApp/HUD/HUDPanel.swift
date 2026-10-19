import AppKit
import SwiftUI

/// A borderless, non-activating panel at the top centre of the active screen. It lets clicks
/// through except while it offers a one-click fix. `sharingType = .none` keeps it out of
/// screenshots, screen recordings and screen shares.
@MainActor
final class HUDPanel {
    private let panel: NSPanel
    private let host: NSHostingView<HUDView>
    private let onFix: (Problem.Fix) -> Void

    static let title = "Handy HUD"

    init(state: HUDState, onFix: @escaping (Problem.Fix) -> Void) {
        self.onFix = onFix
        host = NSHostingView(rootView: HUDView(state: state))
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: host.fittingSize),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.title = Self.title
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.sharingType = .none
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    var isVisible: Bool { panel.isVisible }
    var windowNumber: Int { panel.windowNumber }

    func show(_ state: HUDState) {
        let onFix = onFix
        host.rootView = HUDView(state: state, onFix: state.fix.map { fix in { onFix(fix) } })
        panel.ignoresMouseEvents = state.fix == nil
        let size = host.fittingSize
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2, y: frame.maxY - size.height - 8, width: size.width, height: size.height),
            display: true)
        if !panel.isVisible { panel.orderFrontRegardless() }
    }

    func hide() {
        panel.orderOut(nil)
    }
}
