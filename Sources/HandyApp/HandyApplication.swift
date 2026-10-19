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
            let symbol = MenuBarSymbol(mode: delegate.model.mode, cameraLive: delegate.model.tracking.camera.isLive)
            Image(systemName: symbol.name)
                .accessibilityLabel(symbol.accessibilityLabel)
        }
        .menuBarExtraStyle(.menu)

        Window("Handy Debug Overlay", id: WindowID.debugOverlay) {
            DebugOverlayView(tracking: delegate.model.tracking)
        }
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(model: delegate.model)
        }
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
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text("Handy is \(model.mode.title)")
        if let problem = model.problem {
            Text(problem.message)
            if let fix = problem.fix {
                Button(fix.title) { model.apply(fix) }
            }
        }
        Button(model.mode == .off ? "Start Watching" : "Stop") { model.send(.toggle) }
        Text("Stop from anywhere: \(GlobalHotKey.stopDisplay)")
        Divider()
        Menu("Actions") {
            ForEach(ActionMenu.items, id: \.self) { action in
                Button {
                    model.perform(action)
                } label: {
                    Label(action.title, systemImage: action.symbol)
                }
            }
        }
        Button("Cheat Sheet (\(GlobalHotKey.cheatSheetDisplay))") { model.toggleCheatSheet() }
        Button("Tutorial…") { model.showOnboarding() }
        Button("Settings…") {
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Show Debug Overlay") {
            NSApplication.shared.activate()
            openWindow(id: WindowID.debugOverlay)
        }
        Button("Accidental-Action Log (\(model.oopsCount))…") {
            NSWorkspace.shared.open(AppPaths.accidentalActionLog)
        }
        .disabled(model.oopsCount == 0)
        Button(model.tracking.recordingURL == nil ? "Start Recording Landmarks" : "Stop Recording Landmarks") {
            try? model.tracking.setRecording(model.tracking.recordingURL == nil)
        }
        Divider()
        Button("Quit Handy") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// The menu-bar icon: a distinct, filled-circle hand whenever the camera is live.
struct MenuBarSymbol: Equatable {
    let mode: Engine.Mode
    let cameraLive: Bool

    var name: String {
        switch (mode, cameraLive) {
        case (.off, _): "hand.raised.slash"
        case (.engaged, true), (.dragging, true), (.scrolling, true), (.zooming, true), (.palette, true):
            "hand.raised.circle.fill"
        case (_, true): "hand.raised.circle"
        case (_, false): "hand.raised"
        }
    }

    var accessibilityLabel: String {
        cameraLive ? "Handy, \(mode.title), camera on" : "Handy, \(mode.title)"
    }
}

extension Engine.Mode {
    var title: String {
        switch self {
        case .off: "Off"
        case .watching: "Watching"
        case .arming: "Arming"
        case .engaged: "Engaged"
        case .dragging: "Dragging"
        case .scrolling: "Scrolling"
        case .zooming: "Zooming"
        case .palette: "Palette"
        }
    }
}

/// The menu bar's projection of the action catalog.
enum ActionMenu {
    static let items = NamedAction.allCases
}
