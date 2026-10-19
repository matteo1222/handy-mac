import AppKit
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
        window.contentViewController = NSHostingController(rootView: CorpusRecorderView(model: recorder))
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
        window.contentViewController = NSHostingController(rootView: PointingTestView(model: PointingTestModel()))
        window.center()
        pointingWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
