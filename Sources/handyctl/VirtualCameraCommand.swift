import ArgumentParser
import CoreGraphics
import CoreVideo
import Foundation
import HandyCore
import HandyPerception
import HandyReplay
import ImageIO
import UniformTypeIdentifiers

/// A virtual camera: a scripted hand is drawn frame by frame, run through the real hand tracker, then
/// through the gesture engine, so a gesture can be tested end to end without anyone at the camera.
struct VirtualCameraCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "virtual-camera",
        abstract: "Draw a scripted hand, track it with the real backend and run the gesture engine on it.",
        discussion: """
            The script is the synth grammar (pose[:dur][@x,y][->x,y][~size][/roll][^pitch]). Frames are drawn
            as the camera sees them and mirrored like the live path. Prints the engine's events and how well
            the tracker saw the hand (found rate, joint error against the drawn joints, in hand lengths).
            A drawn hand does not tell trackers which side faces them as a real one does, so by default each
            tracked hand takes the drawn hand's chirality; --tracker-chirality keeps the tracker's label.
            """)

    @Option(help: "Script for the hand, e.g. \"relaxed:500ms openPalm:1s pinchMiddle:200ms openPalm:500ms\".")
    var script: String

    @Option(help: "Chirality of the hand.")
    var hand: Chirality = .right

    @Option(help: "Hand-pose backend: vision or coreml.")
    var backend = HandBackend.standard.rawValue

    @Flag(help: "Keep the tracker's left/right label instead of the drawn hand's.")
    var trackerChirality = false

    @Option(help: "Write the tracked landmarks to this .lmk for replay.")
    var output: String?

    @Option(help: "Save every Nth drawn frame as a PNG in this folder.")
    var frames: String?

    @Option(help: "With --frames, save every Nth frame.")
    var every = 15

    @Flag(help: "Print every event, not only the summary.")
    var events = false

    func run() throws {
        guard let handBackend = HandBackend(rawValue: backend) else {
            throw ValidationError("backend must be vision or coreml")
        }
        let track = try Clip.parseHand(script, chirality: hand)
        // Someone looking at the screen for the whole clip: the attention gate needs a face.
        let seconds = track.steps.reduce(0) { $0 + $1.duration }
        let clip = Clip(hands: [track], face: try Clip.parseFace("0:\(Int((seconds * 1000).rounded(.up)))ms"))
        if let frames { try FileManager.default.createDirectory(atPath: frames, withIntermediateDirectories: true) }
        var drawn: [VirtualCamera.Frame] = []
        var index = 0
        var thrown: (any Error)?
        Synthesizer.forEachScene(clip) { t, scene, face in
            defer { index += 1 }
            guard thrown == nil, let image = HandRenderer.image(scene) else { return }
            if let frames, index % every == 0 {
                do {
                    try Self.savePNG(
                        image, to: URL(filePath: frames).appending(path: String(format: "%05d.png", index)))
                } catch { thrown = error }
            }
            drawn.append(
                VirtualCamera.Frame(
                    t: t, image: image, truth: scene.map { $0.shape.pose(at: $0.placement) },
                    handLength: scene.first?.placement.size ?? 1, face: face))
        }
        if let thrown { throw thrown }
        let result = try VirtualCamera(provider: handBackend.makeProvider(), keepsTrackerChirality: trackerChirality)
            .track(drawn)
        let tracked = result.frames
        let stream = LandmarkStream(
            header: .init(source: "virtual-camera", meta: ["backend": handBackend.rawValue, "script": script]),
            frames: tracked)
        if let output { try stream.write(to: URL(filePath: output)) }
        let timed = Replayer.run(stream)
        let actions = timed.filter { !Self.isMotion($0.event) }
        if events {
            for event in actions { print(String(format: "%7.2f  %@", event.t, String(describing: event.event))) }
        }
        try printJSON(
            VirtualCameraReport(
                backend: handBackend.rawValue, frames: tracked.count, handFoundRate: Self.r(result.handFoundRate),
                jointError: Summary(result.jointErrors).rounded(1000),
                events: Dictionary(actions.map { (Self.kind($0.event), 1) }, uniquingKeysWith: +)))
    }

    static func r(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }

    static func isMotion(_ event: Engine.Event) -> Bool {
        switch event {
        case .moveCursor, .dragMoved: true
        case .scroll(_, _, let phase): phase != .began
        default: false
        }
    }

    /// The event's name with its main argument, e.g. click.right or modeChanged.engaged.
    static func kind(_ event: Engine.Event) -> String {
        let text = String(describing: event)
        let name = text.prefix { $0 != "(" }
        guard let open = text.firstIndex(of: "(") else { return String(name) }
        let inner = text[text.index(after: open)...].prefix { $0 != ")" && $0 != "," }
        let value = inner.split(separator: ":").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let clean = value.hasPrefix("HandyCore.") ? String(value.split(separator: ".").last ?? "") : value
        return clean.isEmpty || clean.first?.isNumber == true || clean.first == "-" ? String(name) : "\(name).\(clean)"
    }

    static func savePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw ValidationError("could not write \(url.path)") }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}

struct VirtualCameraReport: Encodable {
    let backend: String
    let frames: Int
    /// Tracked hands matched to a drawn hand, per drawn hand per frame.
    let handFoundRate: Double
    /// Mean joint distance from the drawn joints, in hand lengths.
    let jointError: Summary
    let events: [String: Int]
}
