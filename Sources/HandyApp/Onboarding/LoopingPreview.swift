import SwiftUI

/// A short looping animation of what a permission enables. Static under Reduce Motion.
struct LoopingPreview: View {
    enum Kind {
        /// A hand moves and the pointer follows: what the camera is for.
        case camera
        /// A pinch clicks a button: what Accessibility is for.
        case accessibility
    }

    let kind: Kind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase =
                reduceMotion ? 0.5 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 5) / 5
            content(phase: phase)
        }
        .frame(width: 280, height: 120)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(kind == .camera ? "Your hand moves the pointer" : "A pinch clicks a button")
    }

    @ViewBuilder
    private func content(phase: Double) -> some View {
        let sway = sin(phase * 2 * .pi)
        switch kind {
        case .camera:
            HStack(spacing: 40) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 34))
                    .offset(x: sway * 18, y: cos(phase * 2 * .pi) * 8)
                Image(systemName: "cursorarrow")
                    .font(.system(size: 26))
                    .offset(x: sway * 30, y: cos(phase * 2 * .pi) * 14)
            }
            .foregroundStyle(Color.accentColor)
        case .accessibility:
            let pinched = phase > 0.45 && phase < 0.6
            HStack(spacing: 40) {
                Image(systemName: pinched ? "hand.pinch.fill" : "hand.pinch")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                Text("Click")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(pinched ? Color.accentColor : Color.secondary.opacity(0.2), in: Capsule())
                    .foregroundStyle(pinched ? Color.white : Color.primary)
                    .scaleEffect(pinched ? 0.94 : 1)
            }
        }
    }
}
