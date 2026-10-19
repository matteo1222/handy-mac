import HandyCore
import SwiftUI

/// The first-run tutorial window: one step at a time, each with a single clear instruction.
struct OnboardingView: View {
    let model: OnboardingModel
    var close: () -> Void = {}

    var body: some View {
        VStack(spacing: 18) {
            StepHeader(step: model.step)
            content
                .frame(maxWidth: .infinity, minHeight: 200)
            StepDots(current: model.step)
        }
        .padding(28)
        .frame(width: 520)
        .animation(.snappy, value: model.step)
    }

    @ViewBuilder
    private var content: some View {
        switch model.step {
        case .welcome:
            VStack(spacing: 16) {
                Text("Handy lets you point, click and scroll with your hand in front of the camera.")
                    .multilineTextAlignment(.center)
                Text("Nothing happens until you hold an open palm toward the camera. Frames never leave your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                PrimaryButton("Start tutorial") { Task { await model.start() } }
            }
        case .cameraPermission:
            PermissionStep(
                preview: .camera, granted: model.camera == .granted,
                explanation: "Handy needs the camera to see your hand. Frames are processed in memory and dropped.",
                actionTitle: "Open Camera Settings",
                action: {
                    if let url = Problem.Fix.openCameraSettings.settingsURL { NSWorkspace.shared.open(url) }
                },
                retry: { Task { await model.retryCamera() } })
        case .framing:
            VStack(spacing: 16) {
                Label(
                    model.advice.message, systemImage: model.advice == .good ? "checkmark.circle.fill" : "hand.raised"
                )
                .font(.title3)
                .foregroundStyle(model.advice == .good ? Color.green : Color.primary)
                Text("Sit comfortably with your elbow resting. Your hand should be at chest height.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                PrimaryButton("Continue", disabled: !model.canContinueFromFraming) { model.continueFromFraming() }
            }
        case .engage:
            Instruction(symbol: "hand.raised.fill", text: "Hold your open palm toward the camera until the ring fills.")
        case .move:
            VStack(spacing: 14) {
                Instruction(
                    symbol: "arrow.up.and.down.and.arrow.left.and.right",
                    text: "Move your open hand to move the pointer.")
                ProgressView(value: model.tutorial.progress ?? 0)
            }
        case .click:
            ClickStep(accessibilityGranted: model.accessibilityGranted)
        case .scroll:
            VStack(spacing: 10) {
                Instruction(symbol: "hand.point.up.fill", text: "Raise two fingers and move up or down to scroll.")
                ScrollPractice()
                ProgressView(value: model.tutorial.progress ?? 0)
            }
        case .disengage:
            Instruction(symbol: "hand.raised.slash.fill", text: "Make a fist, or lower your hand, to let go.")
        case .done:
            DoneStep(calibration: model.calibration, close: close)
        }
    }
}

private struct StepHeader: View {
    let step: Tutorial.Step

    var body: some View {
        Text(title)
            .font(.title2.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private var title: String {
        switch step {
        case .welcome: "Welcome to Handy"
        case .cameraPermission: "Camera access"
        case .framing: "Check your framing"
        case .engage: "Engage"
        case .move: "Move"
        case .click: "Click"
        case .scroll: "Scroll"
        case .disengage: "Let go"
        case .done: "You're set"
        }
    }
}

private struct StepDots: View {
    let current: Tutorial.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Tutorial.Step.allCases, id: \.self) { step in
                Circle()
                    .fill(step == current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct Instruction: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PermissionStep: View {
    let preview: LoopingPreview.Kind
    let granted: Bool
    let explanation: String
    let actionTitle: String
    let action: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            LoopingPreview(kind: preview)
            Text(explanation)
                .multilineTextAlignment(.center)
            if granted {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                HStack {
                    PrimaryButton(actionTitle, action: action)
                    Button("Try again", action: retry)
                }
            }
        }
    }
}

private struct ClickStep: View {
    let accessibilityGranted: Bool
    @State private var clicks = 0

    var body: some View {
        VStack(spacing: 14) {
            if accessibilityGranted {
                Instruction(symbol: "hand.pinch.fill", text: "Point at the target and pinch thumb and index to click.")
                Button(clicks == 0 ? "Click me" : "Clicked") { clicks += 1 }
                    .controlSize(.extraLarge)
                    .buttonStyle(.borderedProminent)
            } else {
                LoopingPreview(kind: .accessibility)
                Text(
                    "To click for you, Handy needs Accessibility permission. Turn on Handy in the window "
                        + "that opened; the tutorial continues by itself."
                )
                .multilineTextAlignment(.center)
                PrimaryButton("Open Accessibility Settings") {
                    if let url = Problem.Fix.openAccessibilitySettings.settingsURL { NSWorkspace.shared.open(url) }
                }
            }
        }
    }
}

private struct ScrollPractice: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(1...40, id: \.self) { row in
                    Text("Row \(row)")
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                    Divider()
                }
            }
        }
        .frame(height: 110)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DoneStep: View {
    let calibration: Calibration?
    let close: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Engage with an open palm, pinch to click, two fingers to scroll, a fist to let go.")
                .multilineTextAlignment(.center)
            if let calibration {
                Text(
                    "Tuned to your hand: pinch presses at "
                        + calibration.pinchPress.formatted(.number.precision(.fractionLength(2))) + "."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            PrimaryButton("Done", action: close)
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    init(_ title: String, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(disabled)
            .modifier(ProminentStyle())
    }
}

private struct ProminentStyle: ViewModifier {
    @Environment(\.drawsSolidPill) private var snapshot

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !snapshot {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
