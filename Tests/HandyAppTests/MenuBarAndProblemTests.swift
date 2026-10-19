import HandyCore
import Testing

@testable import HandyApp

@MainActor
@Test func menuBarIconIsDistinctWhenTheCameraIsLive() {
    let live = Engine.Mode.allCases.map { MenuBarSymbol(mode: $0, cameraLive: true).name }
    let notLive = Engine.Mode.allCases.filter { $0 != .off }.map { MenuBarSymbol(mode: $0, cameraLive: false).name }
    #expect(Set(live.dropFirst()).isDisjoint(with: Set(notLive)))
    #expect(MenuBarSymbol(mode: .off, cameraLive: false).name == "hand.raised.slash")
    #expect(MenuBarSymbol(mode: .watching, cameraLive: true).accessibilityLabel.contains("camera on"))
}

@MainActor
@Test func everyCameraProblemSaysWhatHappenedAndOffersAFix() {
    let problems: [Problem] = [
        .cameraInUse, .cameraDisconnected, .noCamera, .cameraPermissionDenied, .accessibilityNeeded,
    ]
    for problem in problems {
        let hud = HUDState.make(status: .init(mode: .watching, progress: nil), lastAction: nil, problem: problem)
        #expect(hud.title == problem.message)
        #expect(hud.fix != nil, "\(problem) has a one-click fix")
        #expect(hud.tone == .warning)
    }
    #expect(Problem.tooDark.fix == nil)
}
