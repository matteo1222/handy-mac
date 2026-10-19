import Foundation
import HandyCore

/// A synthetic clip: one script per hand plus an optional face-yaw script, sampled at `fps`.
///
/// A hand script is a list of steps separated by spaces:
///
///     pose[:duration][@x,y][->x,y][~size]
///
/// - `pose` is a `PoseName` raw value, or `none` for no hand.
/// - `duration` is `300ms` or `0.3s` (default 300ms).
/// - `@x,y` sets the wrist position at the start of the step; `->x,y` moves it linearly to that
///   position by the end. Positions are in frame-height units; the default is the previous end.
/// - `~size` sets the hand size (wrist to middle MCP, frame heights).
///
/// The shape blends from the previous step's pose over `transition`, then holds.
/// A face script is the same with yaw degrees in place of the pose: `0:1s 45:500ms none:300ms`.
public struct Clip: Sendable, Equatable {
    public struct Step: Sendable, Equatable {
        public var pose: PoseName?
        public var duration: Double
        public var start: Point?
        public var end: Point?
        public var size: Double?
    }

    public struct HandTrack: Sendable, Equatable {
        public var chirality: Chirality
        public var steps: [Step]
    }

    public struct FaceStep: Sendable, Equatable {
        public var yaw: Double?
        public var duration: Double
    }

    public var hands: [HandTrack]
    public var face: [FaceStep]
    public var fps: Double
    public var aspect: Double
    public var transition: Double

    public init(
        hands: [HandTrack], face: [FaceStep] = [], fps: Double = 30, aspect: Double = 16.0 / 9,
        transition: Double = 0.08
    ) {
        self.hands = hands
        self.face = face
        self.fps = fps
        self.aspect = aspect
        self.transition = transition
    }

    public var duration: Double {
        let handDurations = hands.map { $0.steps.reduce(0) { $0 + $1.duration } }
        let faceDuration = face.reduce(0) { $0 + $1.duration }
        return (handDurations + [faceDuration]).max() ?? 0
    }
}

public struct ClipParseError: Error, Equatable, CustomStringConvertible {
    public let description: String
}

extension Clip {
    public static func parseHand(_ script: String, chirality: Chirality) throws(ClipParseError) -> HandTrack {
        var steps: [Step] = []
        for token in script.split(whereSeparator: \.isWhitespace) {
            steps.append(try parseStep(String(token)))
        }
        guard !steps.isEmpty else { throw ClipParseError(description: "empty hand script") }
        return HandTrack(chirality: chirality, steps: steps)
    }

    public static func parseFace(_ script: String) throws(ClipParseError) -> [FaceStep] {
        try script.split(whereSeparator: \.isWhitespace).map { token throws(ClipParseError) in
            let parts = token.split(separator: ":", maxSplits: 1).map(String.init)
            let yaw: Double?
            if parts[0] == "none" {
                yaw = nil
            } else if let value = Double(parts[0]) {
                yaw = value
            } else {
                throw ClipParseError(description: "face step \"\(token)\": yaw must be degrees or none")
            }
            return FaceStep(yaw: yaw, duration: try parts.count > 1 ? parseDuration(parts[1]) : 0.3)
        }
    }

    private static func parseStep(_ token: String) throws(ClipParseError) -> Step {
        // Suffixes come in grammar order, so peel them off from the right.
        var rest = Substring(token)
        func split(_ marker: String) -> Substring? {
            guard let range = rest.range(of: marker, options: .backwards) else { return nil }
            defer { rest = rest[..<range.lowerBound] }
            return rest[range.upperBound...]
        }
        let size = try split("~").map { s throws(ClipParseError) in try number(s, in: token) }
        let end = try split("->").map { s throws(ClipParseError) in try point(s, in: token) }
        let start = try split("@").map { s throws(ClipParseError) in try point(s, in: token) }
        let parts = rest.split(separator: ":", maxSplits: 1).map(String.init)
        guard let name = parts.first else { throw ClipParseError(description: "empty step") }
        let pose: PoseName?
        if name == "none" {
            pose = nil
        } else if let known = PoseName(rawValue: name) {
            pose = known
        } else {
            let names = PoseName.allCases.map(\.rawValue).joined(separator: ", ")
            throw ClipParseError(description: "unknown pose \"\(name)\" in \"\(token)\"; known: none, \(names)")
        }
        let duration = try parts.count > 1 ? parseDuration(parts[1]) : 0.3
        return Step(pose: pose, duration: duration, start: start, end: end, size: size)
    }

    static func parseDuration(_ text: String) throws(ClipParseError) -> Double {
        if text.hasSuffix("ms"), let value = Double(text.dropLast(2)) { return value / 1000 }
        if text.hasSuffix("s"), let value = Double(text.dropLast()) { return value }
        throw ClipParseError(description: "duration \"\(text)\" must look like 300ms or 0.3s")
    }

    private static func number(_ text: Substring, in token: String) throws(ClipParseError) -> Double {
        guard let value = Double(text) else {
            throw ClipParseError(description: "bad number \"\(text)\" in \"\(token)\"")
        }
        return value
    }

    private static func point(_ text: Substring, in token: String) throws(ClipParseError) -> Point {
        let parts = text.split(separator: ",")
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else {
            throw ClipParseError(description: "bad position \"\(text)\" in \"\(token)\"; use x,y")
        }
        return Point(x: x, y: y)
    }
}
