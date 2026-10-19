import SwiftUI

/// The ambient pill: state, a progress ring while a hold is under way, and the last action.
struct HUDView: View {
    let state: HUDState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if let progress = state.progress {
                    Circle()
                        .stroke(.secondary.opacity(0.3), lineWidth: 2.5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 0.05), value: progress)
                }
                Image(systemName: state.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 24, height: 24)

            Text(state.title)
                .font(.callout.weight(.semibold))
            if let detail = state.detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .modifier(PillBackground())
        .fixedSize()
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var tint: Color {
        switch state.tone {
        case .quiet: .secondary
        case .active: .accentColor
        case .warning: .orange
        }
    }

    private var accessibilityText: String {
        ["Handy", state.title, state.detail].compactMap { $0 }.joined(separator: ", ")
    }
}

extension EnvironmentValues {
    /// Offscreen snapshots cannot composite glass or vibrancy, so they draw a solid pill instead.
    @Entry var drawsSolidPill = false
}

/// Liquid Glass on macOS 26, a material capsule before it.
private struct PillBackground: ViewModifier {
    @Environment(\.drawsSolidPill) private var drawsSolidPill

    func body(content: Content) -> some View {
        if drawsSolidPill {
            content.background(Color(nsColor: .controlBackgroundColor), in: Capsule())
        } else if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(.regularMaterial, in: Capsule())
        }
    }
}

#Preview("States") {
    VStack(spacing: 12) {
        HUDView(state: .make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: nil))
        HUDView(state: .make(status: .init(mode: .arming, progress: 0.6), lastAction: nil, problem: nil))
        HUDView(state: .make(status: .init(mode: .engaged, progress: nil), lastAction: "Left click", problem: nil))
        HUDView(state: .make(status: .init(mode: .off, progress: nil), lastAction: nil, problem: "Camera in use"))
    }
    .padding()
}
