import HandyCore
import SwiftUI

/// Live landmarks and features, for tuning and for seeing what the engine sees.
struct DebugOverlayView: View {
    let tracking: LiveTracking

    private static let bones: [(Joint, Joint)] =
        Finger.allCases.flatMap { finger in
            let chain = [Joint.wrist] + finger.joints
            return zip(chain, chain.dropFirst()).map { ($0, $1) }
        } + [(.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                guard let frame = tracking.debugFrame else { return }
                let scale = min(size.width / frame.aspect, size.height)
                func project(_ point: Point) -> CGPoint { CGPoint(x: point.x * scale, y: point.y * scale) }
                context.stroke(
                    Path(CGRect(x: 0, y: 0, width: frame.aspect * scale, height: scale)), with: .color(.secondary))
                for hand in frame.features.hands {
                    var bones = Path()
                    for (from, to) in Self.bones {
                        guard let a = hand[from], let b = hand[to] else { continue }
                        bones.move(to: project(a))
                        bones.addLine(to: project(b))
                    }
                    let color: Color = hand.chirality == .right ? .accentColor : .orange
                    context.stroke(bones, with: .color(color), lineWidth: 2)
                    let centroid = project(hand.palmCentroid)
                    context.fill(
                        Path(ellipseIn: CGRect(x: centroid.x - 5, y: centroid.y - 5, width: 10, height: 10)),
                        with: .color(color))
                }
                for raw in frame.landmarks.hands {
                    for case let sample? in raw.joints {
                        let p = project(sample.point)
                        context.fill(
                            Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
                            with: .color(.secondary.opacity(sample.confidence)))
                    }
                }
            }
            .aspectRatio(16.0 / 9, contentMode: .fit)
            .accessibilityLabel("Live hand landmarks")

            if let frame = tracking.debugFrame {
                ForEach(frame.features.hands, id: \.id) { hand in
                    Text(Self.describe(hand)).font(.caption.monospaced())
                }
                if let yaw = frame.features.face?.yaw {
                    Text("face yaw \(yaw, format: .number.precision(.fractionLength(0)))°").font(.caption.monospaced())
                }
            } else {
                Text(tracking.camera == .off ? "Camera is off. Start watching to see landmarks." : "No hands yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
        .onAppear { tracking.publishesDebugFrames = true }
        .onDisappear { tracking.publishesDebugFrames = false }
    }

    private static func describe(_ hand: HandFeatures) -> String {
        func f(_ value: Double?) -> String { value.map { String(format: "%.2f", $0) } ?? "—" }
        let reach = Finger.allCases.map { f(hand.reach[$0]) }.joined(separator: " ")
        return "#\(hand.id) \(hand.chirality.rawValue) scale \(f(hand.scale)) pinch \(f(hand.pinchIndex))/"
            + "\(f(hand.pinchMiddle)) reach [\(reach)] facing \(f(hand.palmFacing))"
    }
}
