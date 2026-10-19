import AppKit
import HandyCore
import SwiftUI

/// The menu-bar app. The Tuist app target's entry point calls `HandyApplication.main()`.
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
    }
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

    var body: some View {
        Text("Handy is \(model.mode.title)")
        Button(model.mode == .off ? "Start Watching" : "Stop") { model.send(.toggle) }
        Text("Stop from anywhere: \(GlobalHotKey.stopDisplay)")
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
