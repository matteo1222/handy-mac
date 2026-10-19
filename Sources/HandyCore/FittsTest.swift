import Foundation

/// The ISO 9241-411 multi-directional tapping task: targets on a circle, selected in an order that
/// crosses the circle each time, under several amplitude and width conditions. Throughput uses the
/// effective width and amplitude (MacKenzie's method), in bits per second.
public struct FittsTest: Sendable, Equatable {
    public struct Condition: Sendable, Hashable, Codable {
        /// Circle diameter in points.
        public var amplitude: Double
        /// Target diameter in points.
        public var width: Double

        public init(amplitude: Double, width: Double) {
            self.amplitude = amplitude
            self.width = width
        }

        public var nominalDifficulty: Double { log2(amplitude / width + 1) }
    }

    /// One selection: where the movement started, where the click landed, the target's centre, how long it took.
    public struct Trial: Sendable, Hashable, Codable {
        public var from: Point
        public var selection: Point
        public var target: Point
        public var seconds: Double

        public init(from: Point, selection: Point, target: Point, seconds: Double) {
            self.from = from
            self.selection = selection
            self.target = target
            self.seconds = seconds
        }
    }

    public struct ConditionResult: Sendable, Hashable, Codable {
        public var condition: Condition
        public var trials: Int
        public var errorRate: Double
        public var movementTime: Double
        public var effectiveWidth: Double
        public var effectiveAmplitude: Double
        public var effectiveDifficulty: Double
        public var throughput: Double
    }

    public struct Result: Sendable, Hashable, Codable {
        public var input: String
        public var conditions: [ConditionResult]
        /// Mean of the per-condition throughputs, bits per second.
        public var throughput: Double
    }

    public static let targetCount = 13
    public static let standardConditions = [
        Condition(amplitude: 300, width: 40), Condition(amplitude: 300, width: 80),
        Condition(amplitude: 520, width: 40), Condition(amplitude: 520, width: 80),
    ]

    public let conditions: [Condition]
    public private(set) var conditionIndex = 0
    public private(set) var step = 0
    public private(set) var trials: [[Trial]]

    public init(conditions: [Condition] = FittsTest.standardConditions) {
        self.conditions = conditions
        trials = conditions.map { _ in [] }
    }

    public var isFinished: Bool { conditionIndex >= conditions.count }
    public var condition: Condition? { isFinished ? nil : conditions[conditionIndex] }

    /// The target to select now: the standard order jumps across the circle (0, 7, 1, 8, ...).
    public var targetIndex: Int { (step * (Self.targetCount + 1) / 2) % Self.targetCount }

    /// Centre of target `index` for a circle around `center`.
    public static func position(of index: Int, condition: Condition, center: Point) -> Point {
        let angle = Double(index) / Double(targetCount) * 2 * .pi - .pi / 2
        return Point(
            x: center.x + condition.amplitude / 2 * cos(angle), y: center.y + condition.amplitude / 2 * sin(angle))
    }

    /// Records a selection. The first click of each condition only starts the clock and is not scored.
    public mutating func select(_ trial: Trial?) {
        guard !isFinished else { return }
        if let trial, step > 0 { trials[conditionIndex].append(trial) }
        step += 1
        if step >= Self.targetCount {
            conditionIndex += 1
            step = 0
        }
    }

    public func result(input: String) -> Result {
        let results = zip(conditions, trials).compactMap { condition, trials in Self.score(condition, trials) }
        let throughput = results.isEmpty ? 0 : results.map(\.throughput).reduce(0, +) / Double(results.count)
        return Result(input: input, conditions: results, throughput: (throughput * 100).rounded() / 100)
    }

    static func score(_ condition: Condition, _ trials: [Trial]) -> ConditionResult? {
        guard trials.count >= 2 else { return nil }
        // Project each selection onto its task axis: signed distance past the target along from -> target.
        let projections = trials.map { trial -> (dx: Double, distance: Double) in
            let axis = trial.target - trial.from
            let length = max(axis.length, 1e-9)
            let unit = axis / length
            let offset = trial.selection - trial.target
            let dx = offset.x * unit.x + offset.y * unit.y
            return (dx, length + dx)
        }
        let mean = projections.map(\.dx).reduce(0, +) / Double(projections.count)
        let variance = projections.map { ($0.dx - mean) * ($0.dx - mean) }.reduce(0, +) / Double(projections.count - 1)
        let effectiveWidth = 4.133 * variance.squareRoot()
        let effectiveAmplitude = projections.map(\.distance).reduce(0, +) / Double(projections.count)
        let effectiveDifficulty = log2(effectiveAmplitude / max(effectiveWidth, 1e-9) + 1)
        let movementTime = trials.map(\.seconds).reduce(0, +) / Double(trials.count)
        let misses = trials.filter { $0.selection.distance(to: $0.target) > condition.width / 2 }.count
        func round(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        return ConditionResult(
            condition: condition, trials: trials.count, errorRate: round(Double(misses) / Double(trials.count)),
            movementTime: round(movementTime), effectiveWidth: round(effectiveWidth),
            effectiveAmplitude: round(effectiveAmplitude), effectiveDifficulty: round(effectiveDifficulty),
            throughput: round(effectiveDifficulty / max(movementTime, 1e-9)))
    }
}
