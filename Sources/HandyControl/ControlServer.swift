import Darwin
import Foundation
import os

/// Serves control requests from `handyctl` on a Unix-domain socket only the current user can open.
public final class ControlServer: Sendable {
    public typealias Handler = @Sendable (ControlRequest) async -> ControlResponse

    private let listener: UnixSocket
    private let path: String
    private let handler: Handler
    private static let log = Logger(subsystem: "dev.handy", category: "control")

    public init(path: String = ControlSocket.defaultPath, handler: @escaping Handler) throws {
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        unlink(path)
        let listener = try UnixSocket.make()
        let bound = try UnixSocket.withAddress(path) { bind(listener.fd, $0, $1) }
        guard bound == 0 else { throw ControlSocketError.system("bind \(path)", errno) }
        chmod(path, 0o600)
        guard listen(listener.fd, 8) == 0 else { throw ControlSocketError.system("listen", errno) }
        self.listener = listener
        self.path = path
        self.handler = handler
        Thread.detachNewThread { [self] in acceptLoop() }
    }

    deinit {
        listener.close()
        unlink(path)
    }

    private func acceptLoop() {
        while true {
            let fd = accept(listener.fd, nil, nil)
            guard fd >= 0 else {
                if errno == EINTR { continue }
                return
            }
            let connection = UnixSocket(fd: fd)
            let handler = handler
            Task.detached {
                defer { connection.close() }
                let response: ControlResponse
                if let line = connection.readLine(),
                    let request = try? JSONDecoder().decode(ControlRequest.self, from: line)
                {
                    response = await handler(request)
                } else {
                    response = ControlResponse(ok: false, error: "malformed request")
                }
                do {
                    _ = connection.writeLine(try JSONEncoder().encode(response))
                } catch {
                    Self.log.error("encode reply failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
