import ArgumentParser
import HandyControl
import HandyCore

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
