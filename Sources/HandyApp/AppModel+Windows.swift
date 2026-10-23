import AppKit
import HandyControl
import HandyCore
import HandyOutput
import SwiftUI

// MARK: Onboarding

extension AppModel {

    static let onboardedKey = "onboarded"

    /// Opens the tutorial window; shown automatically on first launch.
    func showOnboarding() {
        let onboarding =
            onboarding
            ?? OnboardingModel(
                startTracking: { [weak self] in self?.send(.start) },
                finish: { [weak self] calibration in self?.finishOnboarding(calibration) })
        self.onboarding = onboarding
        let window =
            onboardingWindow
            ?? NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to Handy"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(model: onboarding) { [weak self] in self?.closeOnboarding() })
        window.center()
        onboardingWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        onboarding = nil
    }

    func finishOnboarding(_ calibration: Calibration?) {
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
        guard let calibration else { return }
        do {
            try CalibrationStore.save(calibration)
        } catch {
            Self.log.error("saving calibration failed: \(error.localizedDescription)")
        }
        self.calibration = calibration
        applyTuning()
    }

    var needsOnboarding: Bool { !UserDefaults.standard.bool(forKey: Self.onboardedKey) }
}

extension AppModel {
    /// Opens the guided corpus recorder (TASK-17). While it records, Handy's output is captured, not posted.
    func showCorpusRecorder() {
        let recorder =
            corpusRecorder
            ?? CorpusRecorderModel(
                begin: { [weak self] in
                    guard let self else { return }
                    self.outputBeforeCorpus = self.output
                    self.output = OutputDriver(sink: RecordingSink(), environment: VirtualPointerEnvironment())
                    if self.mode == .off { self.send(.start) }
                },
                end: { [weak self] in
                    guard let self, let live = self.outputBeforeCorpus else { return }
                    self.output = live
                    self.outputBeforeCorpus = nil
                })
        corpusRecorder = recorder
        let window =
            corpusWindow
            ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Record Corpus Session"
        window.isReleasedWhenClosed = false
        window.contentViewController = Self.fixedSize(CorpusRecorderView(model: recorder))
        window.center()
        corpusWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens the ISO 9241-411 pointing test (TASK-28).
    func showPointingTest() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Pointing Test"
        window.isReleasedWhenClosed = false
        window.contentViewController = Self.fixedSize(PointingTestView(model: PointingTestModel()))
        window.center()
        pointingWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Opens a window the menu-bar menu would, so `handyctl open` works when the icon is hidden.
    func open(_ window: HandyWindow) {
        NSApplication.shared.activate()
        switch window {
        case .corpus: showCorpusRecorder()
        case .pointingTest: showPointingTest()
        case .tutorial: showOnboarding()
        case .cheatSheet: toggleCheatSheet()
        case .settings: NSApplication.shared.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    /// A hosting controller sized once from its content. Letting SwiftUI resize a zero-sized window
    /// while it lays out re-enters layout, and on macOS 26 AppKit aborts the app (the corpus recorder
    /// crashed on open).
    static func fixedSize<Content: View>(_ view: Content) -> NSViewController {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = []
        controller.preferredContentSize = controller.view.fittingSize
        return controller
    }
}
