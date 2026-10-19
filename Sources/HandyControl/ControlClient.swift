import Darwin
import Foundation

public enum ControlClient {
    /// Sends one request to the running app and waits for its reply.
    public static func send(
        _ request: ControlRequest, path: String = ControlSocket.defaultPath
    ) throws -> ControlResponse {
        let socket = try UnixSocket.make()
        defer { socket.close() }
        let status = try UnixSocket.withAddress(path) { connect(socket.fd, $0, $1) }
        guard status == 0 else { throw ControlSocketError.system("connect \(path)", errno) }
        guard socket.writeLine(try JSONEncoder().encode(request)) else {
            throw ControlSocketError.system("write", errno)
        }
        shutdown(socket.fd, SHUT_WR)
        guard let reply = socket.readLine() else { throw ControlSocketError.closedWithoutReply }
        return try JSONDecoder().decode(ControlResponse.self, from: reply)
    }
}
