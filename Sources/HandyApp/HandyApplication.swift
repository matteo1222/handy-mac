import AppKit
import HandyCore
import SwiftUI

/// The menu-bar app. The `Handy` executable's entry point calls `HandyApplication.main()`.
public struct HandyApplication: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarContent(model: delegate.model)
        } label: {
            Image(systemName: delegate.model.mode.menuBarSymbol)
                .accessibilityLabel("Handy, \(delegate.model.mode.title)")
        }
        .menuBarExtraStyle(.menu)

        Window("Handy Debug Overlay", id: WindowID.debugOverlay) {
            DebugOverlayView(tracking: delegate.model.tracking)
        }
        .windowResizability(.contentMinSize)
    }
}

enum WindowID {
    static let debugOverlay = "debug-overlay"
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.activate()
    }
}

struct MenuBarContent: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Handy is \(model.mode.title)")
        Button(model.mode == .off ? "Start Watching" : "Stop") { model.send(.toggle) }
        Text("Stop from anywhere: \(GlobalHotKey.stopDisplay)")
        Divider()
        Button("Show Debug Overlay") {
            NSApplication.shared.activate()
            openWindow(id: WindowID.debugOverlay)
        }
        Button(model.tracking.recordingURL == nil ? "Start Recording Landmarks" : "Stop Recording Landmarks") {
            try? model.tracking.setRecording(model.tracking.recordingURL == nil)
        }
        Divider()
        Button("Quit Handy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

extension Engine.Mode {
    var title: String {
        switch self {
        case .off: "Off"
        case .watching: "Watching"
        }
    }

    var menuBarSymbol: String {
        switch self {
        case .off: "hand.raised.slash"
        case .watching: "hand.raised"
        }
    }
}
