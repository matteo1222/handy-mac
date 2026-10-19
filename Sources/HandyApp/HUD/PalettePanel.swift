import AppKit
import HandyCore
import SwiftUI

/// The command palette: eight slots in a ring around the cursor. Click-through and excluded from
/// screen capture, like the HUD.
@MainActor
final class PalettePanel {
    private let panel: NSPanel
    private let host: NSHostingView<PaletteView>
    private static let size = 320.0

    init() {
        host = NSHostingView(rootView: PaletteView(layout: .standard, highlighted: nil))
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.sharingType = .none
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    func show(layout: PaletteLayout, highlighted: Int?) {
        host.rootView = PaletteView(layout: layout, highlighted: highlighted)
        if !panel.isVisible {
            let mouse = NSEvent.mouseLocation
            panel.setFrameOrigin(NSPoint(x: mouse.x - Self.size / 2, y: mouse.y - Self.size / 2))
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel.orderOut(nil)
    }
}

struct PaletteView: View {
    let layout: PaletteLayout
    let highlighted: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<PaletteLayout.slotCount, id: \.self) { slot in
                PaletteSlot(action: layout.slots[slot], highlighted: slot == highlighted)
                    .offset(offset(for: slot))
            }
            Image(systemName: "hand.pinch.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 320, height: 320)
        .animation(reduceMotion ? nil : .snappy(duration: 0.15), value: highlighted)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Command palette")
    }

    private func offset(for slot: Int) -> CGSize {
        let angle = Double(slot) * .pi / 4
        return CGSize(width: sin(angle) * 115, height: -cos(angle) * 115)
    }
}

private struct PaletteSlot: View {
    let action: NamedAction?
    let highlighted: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: action?.symbol ?? "circle.dashed")
                .font(.system(size: 18, weight: .semibold))
            Text(action?.title ?? "Empty")
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .frame(width: 96, height: 58)
        .foregroundStyle(highlighted ? Color.white : Color.primary)
        .modifier(SlotBackground(highlighted: highlighted))
        .scaleEffect(highlighted ? 1.12 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(highlighted ? .isSelected : [])
    }
}

private struct SlotBackground: ViewModifier {
    let highlighted: Bool
    @Environment(\.drawsSolidPill) private var snapshot

    func body(content: Content) -> some View {
        if highlighted {
            content.background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
        } else if #available(macOS 26, *), !snapshot {
            content.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            content.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
