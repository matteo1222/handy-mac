import Foundation
import HandyControl
import Testing

@Test func clientReceivesTheServersReplyOverTheSocket() async throws {
    let path = "/tmp/handy-test-\(UUID().uuidString.prefix(8)).sock"
    let server = try ControlServer(path: path) { request in
        switch request {
        case .state: ControlResponse(state: AppStateSnapshot(mode: .watching, version: "test"))
        case .command: ControlResponse(ok: false, error: "unexpected")
        }
    }
    let reply = try await Task.detached { try ControlClient.send(.state, path: path) }.value
    #expect(reply == ControlResponse(state: AppStateSnapshot(mode: .watching, version: "test")))
    withExtendedLifetime(server) {}
}

@Test func clientReportsAMissingApp() {
    #expect(throws: ControlSocketError.self) {
        try ControlClient.send(.state, path: "/tmp/handy-no-such-\(UUID().uuidString.prefix(8)).sock")
    }
}
