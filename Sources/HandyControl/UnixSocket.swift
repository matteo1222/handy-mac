import Darwin
import Foundation

public enum ControlSocketError: Error, Equatable {
    case pathTooLong
    case system(String, Int32)
    case closedWithoutReply
}

/// Thin POSIX wrapper over a stream Unix-domain socket. Blocking by design: the client is a CLI,
/// and the server runs its accept loop on a dedicated thread.
struct UnixSocket {
    let fd: Int32

    static func make() throws(ControlSocketError) -> UnixSocket {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw .system("socket", errno) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        return UnixSocket(fd: fd)
    }

    static func withAddress<T>(
        _ path: String, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T
    ) throws(ControlSocketError) -> T {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw .pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            bytes.withUnsafeBytes { raw.copyMemory(from: $0) }
        }
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    func readLine(limit: Int = 64 << 20) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while data.count < limit {
            let count = read(fd, &buffer, buffer.count)
            if count <= 0 { return data.isEmpty ? nil : data }
            if let newline = buffer[0..<count].firstIndex(of: UInt8(ascii: "\n")) {
                data.append(contentsOf: buffer[0..<newline])
                return data
            }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    func writeLine(_ data: Data) -> Bool {
        var payload = data
        payload.append(UInt8(ascii: "\n"))
        return payload.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = write(fd, raw.baseAddress?.advanced(by: offset), raw.count - offset)
                if written <= 0 { return false }
                offset += written
            }
            return true
        }
    }

    func close() {
        Darwin.close(fd)
    }
}
