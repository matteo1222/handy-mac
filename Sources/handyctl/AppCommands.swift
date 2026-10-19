import ArgumentParser
import Foundation
import HandyControl
import HandyCore
import HandyReplay

struct State: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print the running app's engine and HUD state.")

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() throws {
        try reply(to: .state, socket: socket)
    }
}

struct Send: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a user command (start, stop, toggle) to the running app.")

    @Argument(help: "start, stop or toggle")
    var command: Engine.Command

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() throws {
        try reply(to: .command(command), socket: socket)
    }
}

extension Engine.Command: ExpressibleByArgument {}

/// Prints the app's reply as JSON; exits 1 when the app is unreachable or reports an error.
func reply(to request: ControlRequest, socket: String) throws {
    let response: ControlResponse
    do {
        response = try ControlClient.send(request, path: socket)
    } catch {
        try printJSON(ControlResponse(ok: false, error: "Handy is not running or unreachable at \(socket): \(error)"))
        throw ExitCode.failure
    }
    try printJSON(response)
    if !response.ok { throw ExitCode.failure }
}

struct Record: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Start or stop recording the running app's live landmarks to a .lmk file.")

    @Argument(help: "start or stop")
    var action: String

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() throws {
        guard ["start", "stop"].contains(action) else { throw ValidationError("use start or stop") }
        try reply(to: .record(action == "start"), socket: socket)
    }
}

struct Screenshot: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Render one of Handy's own views to a PNG (hud, hud-gallery).")

    @Argument(help: "What to render.")
    var target: String

    @Argument(help: "Output .png path.")
    var output: String

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() throws {
        let path = URL(filePath: output).standardizedFileURL.path(percentEncoded: false)
        try reply(to: .screenshot(target: target, path: path), socket: socket)
    }
}

struct Inject: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Feed a .lmk clip into the running app in place of the camera.",
        discussion: "With --sink record, OS input is captured and printed instead of posted.")

    enum Sink: String, ExpressibleByArgument {
        case record
        case live
    }

    @Argument(help: "The .lmk clip.")
    var clip: String

    @Option(help: "record (capture, do not post) or live (post real input).")
    var sink: Sink = .record

    @Flag(help: "Pace frames by their timestamps so the HUD animates.")
    var realtime = false

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() async throws {
        let stream = try LandmarkStream(contentsOf: URL(filePath: clip))
        try reply(to: .inject(frames: stream.frames, record: sink == .record, realtime: realtime), socket: socket)
    }
}

struct Camera: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Stage a camera condition in the running app (inUse, disconnected, resumed, dark, bright) "
            + "or click the HUD's one-click fix (fix).")

    @Argument(help: "inUse, disconnected, resumed, dark, bright or fix")
    var event: String

    @Option(help: "Control socket path.")
    var socket = ControlSocket.defaultPath

    func run() throws {
        try reply(to: event == "fix" ? .applyFix : .simulateCamera(event: event), socket: socket)
    }
}
