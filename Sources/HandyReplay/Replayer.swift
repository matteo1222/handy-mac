import Foundation
import HandyCore

/// Runs a landmark stream through a headless `Session` and compares the events it emits.
public enum Replayer {
    public static func run(_ stream: LandmarkStream, session: Session = Session()) -> [TimedEvent] {
        var session = session
        return stream.frames.flatMap { session.process($0) }
    }

    public static func encode(_ events: [TimedEvent]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(events) + Data("\n".utf8)
    }

    public static func decode(_ data: Data) throws -> [TimedEvent] {
        try JSONDecoder().decode([TimedEvent].self, from: data)
    }
}

/// A difference between expected and actual events, by position.
public struct EventDiff: Sendable, Equatable, Codable {
    public var index: Int
    public var expected: TimedEvent?
    public var actual: TimedEvent?

    public init(index: Int, expected: TimedEvent?, actual: TimedEvent?) {
        self.index = index
        self.expected = expected
        self.actual = actual
    }
}

extension Replayer {
    /// Positional diff. Numbers compare with a tolerance so a recorded expectation survives
    /// floating-point differences between machines.
    public static func diff(expected: [TimedEvent], actual: [TimedEvent], tolerance: Double = 1e-6) -> [EventDiff] {
        (0..<max(expected.count, actual.count)).compactMap { index in
            let e = index < expected.count ? expected[index] : nil
            let a = index < actual.count ? actual[index] : nil
            if let e, let a, approximatelyEqual(e, a, tolerance: tolerance) { return nil }
            return EventDiff(index: index, expected: e, actual: a)
        }
    }

    static func approximatelyEqual(_ a: TimedEvent, _ b: TimedEvent, tolerance: Double) -> Bool {
        guard let left = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(a)),
            let right = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(b))
        else { return false }
        return approximatelyEqual(left, right, tolerance: tolerance)
    }

    private static func approximatelyEqual(_ a: Any, _ b: Any, tolerance: Double) -> Bool {
        switch (a, b) {
        case (let a as [String: Any], let b as [String: Any]):
            return a.keys.sorted() == b.keys.sorted()
                && a.keys.allSatisfy { key in
                    guard let left = a[key], let right = b[key] else { return false }
                    return approximatelyEqual(left, right, tolerance: tolerance)
                }
        case (let a as [Any], let b as [Any]):
            return a.count == b.count && zip(a, b).allSatisfy { approximatelyEqual($0, $1, tolerance: tolerance) }
        case (let a as NSNumber, let b as NSNumber):
            return abs(a.doubleValue - b.doubleValue) <= tolerance
        case (let a as String, let b as String):
            return a == b
        case (is NSNull, is NSNull):
            return true
        default:
            return false
        }
    }
}
