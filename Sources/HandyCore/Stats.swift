/// Summary statistics over a sample of measurements.
public struct Summary: Sendable, Hashable, Codable {
    public var count: Int
    public var mean: Double
    public var p50: Double
    public var p95: Double
    public var max: Double

    public init(_ values: [Double]) {
        let sorted = values.sorted()
        count = sorted.count
        mean = sorted.isEmpty ? 0 : sorted.reduce(0, +) / Double(sorted.count)
        p50 = Self.percentile(sorted, 0.5)
        p95 = Self.percentile(sorted, 0.95)
        max = sorted.last ?? 0
    }

    /// Nearest-rank percentile of an already sorted array.
    static func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let rank = Int((fraction * Double(sorted.count)).rounded(.up)) - 1
        return sorted[Swift.max(0, Swift.min(sorted.count - 1, rank))]
    }

    public func rounded(_ places: Double = 1000) -> Summary {
        var copy = self
        copy.mean = (mean * places).rounded() / places
        copy.p50 = (p50 * places).rounded() / places
        copy.p95 = (p95 * places).rounded() / places
        copy.max = (max * places).rounded() / places
        return copy
    }
}

/// A fixed-size window of recent measurements, for live stats.
public struct RollingWindow: Sendable {
    public let capacity: Int
    private var values: [Double] = []
    private var next = 0

    public init(capacity: Int = 300) {
        self.capacity = capacity
    }

    public mutating func append(_ value: Double) {
        if values.count < capacity {
            values.append(value)
        } else {
            values[next] = value
        }
        next = (next + 1) % capacity
    }

    public var summary: Summary { Summary(values) }
}
