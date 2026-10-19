import AppKit
import HandyCore
import Observation
import SwiftUI

/// Runs the ISO 9241-411 tapping task in a window and saves the throughput, so Handy can be compared
/// with the trackpad (beta exit: at least 2 bits/s at 0.6 m).
@MainActor
@Observable
final class PointingTestModel {
    var input = "Handy"
    private(set) var test = FittsTest()
    private(set) var result: FittsTest.Result?
    private(set) var savedTo: String?
    @ObservationIgnored private var lastSelection: (point: Point, at: ContinuousClock.Instant)?

    static let canvas = 640.0
    var center: Point { Point(x: Self.canvas / 2, y: Self.canvas / 2) }

    var currentTarget: Point? {
        test.condition.map { FittsTest.position(of: test.targetIndex, condition: $0, center: center) }
    }

    func restart() {
        test = FittsTest()
        result = nil
        savedTo = nil
        lastSelection = nil
    }

    func tap(at location: CGPoint) {
        guard let target = currentTarget else { return }
        let point = Point(x: location.x, y: location.y)
        let now = ContinuousClock.now
        let trial = lastSelection.map { last in
            let duration = last.at.duration(to: now)
            let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
            return FittsTest.Trial(from: last.point, selection: point, target: target, seconds: seconds)
        }
        let conditionBefore = test.conditionIndex
        test.select(trial)
        // Each condition starts afresh: its first click only starts the clock.
        lastSelection = test.conditionIndex == conditionBefore ? (point, now) : nil
        if test.isFinished { finish() }
    }

    private func finish() {
        let result = test.result(input: input)
        self.result = result
        let folder = AppPaths.data.appending(path: "PointingTests")
        let name = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "")
        let url = folder.appending(path: "\(name)-\(input.lowercased()).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(result).write(to: url)
            savedTo = url.path(percentEncoded: false)
        } catch {
            savedTo = nil
        }
    }
}

struct PointingTestView: View {
    @Bindable var model: PointingTestModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Input", selection: $model.input) {
                    ForEach(["Handy", "Trackpad", "Mouse"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                Spacer()
                Button("Restart") { model.restart() }
            }
            if let result = model.result {
                ResultView(result: result, savedTo: model.savedTo)
            } else {
                Text(instruction).foregroundStyle(.secondary)
                targets
            }
        }
        .padding(20)
        .frame(width: PointingTestModel.canvas + 40)
    }

    private var instruction: String {
        guard let condition = model.test.condition else { return "" }
        return "Click the highlighted circle each time, as fast and accurately as you can. "
            + "Set \(model.test.conditionIndex + 1) of \(model.test.conditions.count): "
            + "\(Int(condition.amplitude)) pt apart, \(Int(condition.width)) pt wide."
    }

    private var targets: some View {
        ZStack {
            Rectangle().fill(.background)
            if let condition = model.test.condition {
                ForEach(0..<FittsTest.targetCount, id: \.self) { index in
                    let point = FittsTest.position(of: index, condition: condition, center: model.center)
                    Circle()
                        .fill(index == model.test.targetIndex ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: condition.width, height: condition.width)
                        .position(x: point.x, y: point.y)
                        .accessibilityHidden(index != model.test.targetIndex)
                        .accessibilityLabel("Target")
                }
            }
        }
        .frame(width: PointingTestModel.canvas, height: PointingTestModel.canvas)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in model.tap(at: location) }
    }
}

private struct ResultView: View {
    let result: FittsTest.Result
    let savedTo: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Throughput: \(result.throughput, format: .number.precision(.fractionLength(2))) bits/s")
                .font(.title2.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Amplitude")
                    Text("Width")
                    Text("Time")
                    Text("Errors")
                    Text("bits/s")
                }
                .foregroundStyle(.secondary)
                ForEach(result.conditions, id: \.condition) { row in
                    GridRow {
                        Text("\(Int(row.condition.amplitude)) pt")
                        Text("\(Int(row.condition.width)) pt")
                        Text("\(Int(row.movementTime * 1000)) ms")
                        Text(row.errorRate, format: .percent.precision(.fractionLength(0)))
                        Text(row.throughput, format: .number.precision(.fractionLength(2)))
                    }
                }
            }
            .monospacedDigit()
            if let savedTo {
                Text("Saved to \(savedTo)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        }
    }
}
