import AppKit
import HandyCore
import SwiftUI

/// One row of the cheat sheet: how to make a gesture and what it does now.
struct GuideEntry: Identifiable {
    let gesture: HandyCore.Gesture
    let how: String
    let does: String
    let symbol: String
    var id: HandyCore.Gesture { gesture }
}

/// The cheat sheet's content for the frontmost app. Every `Gesture` case has an entry (tested).
enum GestureGuide {
    static func entries(bindings: Bindings, app: String?) -> [GuideEntry] {
        HandyCore.Gesture.allCases.map { entry(for: $0, bindings: bindings, app: app) }
    }

    static func entry(for gesture: HandyCore.Gesture, bindings: Bindings, app: String?) -> GuideEntry {
        let text = guide[gesture] ?? GuideText(how: "\(gesture)", symbol: "hand.raised", does: { _, _ in "" })
        return GuideEntry(gesture: gesture, how: text.how, does: text.does(bindings, app), symbol: text.symbol)
    }

    struct GuideText: Sendable {
        let how: String
        let symbol: String
        /// What it does under these bindings in this app.
        let does: @Sendable (Bindings, String?) -> String
    }

    private static func fixed(_ how: String, _ symbol: String, _ does: String) -> GuideText {
        GuideText(how: how, symbol: symbol) { _, _ in does }
    }

    private static func bound(
        _ how: String, _ symbol: String, _ pick: @escaping @Sendable (Bindings) -> Action?
    ) -> GuideText {
        GuideText(how: how, symbol: symbol) { bindings, _ in pick(bindings)?.description ?? "Nothing" }
    }

    static let guide: [HandyCore.Gesture: GuideText] = [
        .engage: fixed("Hold an open palm toward the camera", "hand.raised.fill", "Start controlling"),
        .disengage: fixed("Make a fist or lower your hand", "hand.raised.slash", "Let go"),
        .moveCursor: fixed("Move your open hand", "cursorarrow.motionlines", "Move the pointer"),
        .click: fixed("Pinch thumb and index", "hand.pinch", "Click"),
        .rightClick: fixed("Pinch thumb and middle finger", "hand.pinch", "Right click"),
        .drag: fixed("Pinch and hold, then move", "hand.pinch.fill", "Drag"),
        .doubleClick: fixed("Pinch twice quickly", "hand.pinch", "Double click"),
        .scroll: fixed("Raise two fingers and move", "arrow.up.and.down", "Scroll"),
        .hardStop: fixed("Cross both hands for a second", "xmark.octagon", "Turn Handy off"),
        .thumbsUp: bound("Thumbs up, hold", "hand.thumbsup") { $0.oneShots[.thumbsUp] },
        .thumbsDown: bound("Thumbs down, hold", "hand.thumbsdown") { $0.oneShots[.thumbsDown] },
        .flickUp: bound("Point, flick your wrist up", "arrow.up") { $0.flicks[.up] },
        .flickDown: bound("Point, flick your wrist down", "arrow.down") { $0.flicks[.down] },
        .flickLeft: bound("Point, flick your wrist left", "arrow.left") { $0.flicks[.left] },
        .flickRight: bound("Point, flick your wrist right", "arrow.right") { $0.flicks[.right] },
        .swipeLeft: bound("Swipe an open palm left", "arrow.left.square") { $0.swipes[.left] },
        .swipeRight: bound("Swipe an open palm right", "arrow.right.square") { $0.swipes[.right] },
        .swipeUp: bound("Swipe an open palm up", "rectangle.3.group") { $0.swipes[.up] },
        .zoomIn: bound("Pinch with both hands, spread", "plus.magnifyingglass") { $0.zooms[.zoomIn] },
        .zoomOut: bound("Pinch with both hands, close", "minus.magnifyingglass") { $0.zooms[.zoomOut] },
        .dictation: bound("Shaka 🤙, hold", "mic") { $0.oneShots[.shaka] },
        .oops: bound("Point and wag your finger", "arrow.uturn.backward") { $0.oops },
        .palette: GuideText(how: "Other hand pinch-holds, then move", symbol: "circle.grid.cross") { bindings, app in
            bindings.palette.layout(for: app).slots.compactMap { $0?.title }.joined(separator: ", ")
        },
    ]
}

struct CheatSheetView: View {
    let entries: [GuideEntry]
    let appName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appName.map { "Gestures in \($0)" } ?? "Gestures")
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                ForEach(entries) { entry in
                    GridRow {
                        Image(systemName: entry.symbol)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                            .accessibilityHidden(true)
                        Text(entry.how)
                        Text(entry.does).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .font(.callout)
            Text("Close with ⌃⌥⌘/ or lower your other hand.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 560)
        .modifier(SheetBackground())
    }
}

private struct SheetBackground: ViewModifier {
    @Environment(\.drawsSolidPill) private var snapshot

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !snapshot {
            content.glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content.background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

/// A non-activating panel in the middle of the screen; it never takes focus from the app below.
@MainActor
final class CheatSheetPanel {
    private let panel: NSPanel
    private let host: NSHostingView<CheatSheetView>

    init() {
        host = NSHostingView(rootView: CheatSheetView(entries: [], appName: nil))
        panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.sharingType = .none
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.setAccessibilityLabel("Handy cheat sheet")
    }

    var isVisible: Bool { panel.isVisible }

    func show(entries: [GuideEntry], appName: String?) {
        host.rootView = CheatSheetView(entries: entries, appName: appName)
        let size = host.fittingSize
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrame(
                NSRect(
                    x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width,
                    height: size.height),
                display: true)
        }
        panel.orderFrontRegardless()
        NSAccessibility.post(
            element: panel, notification: .announcementRequested,
            userInfo: [.announcement: "Handy cheat sheet shown", .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func hide() {
        panel.orderOut(nil)
    }
}
