import Foundation
import HandyCore
import HandyReplay
import Testing

func fixture(_ path: String) throws -> URL {
    try #require(Bundle.module.url(forResource: "Fixtures/\(path)", withExtension: nil))
}

@Test func decodesTheFrozenVersionOneFixture() throws {
    let stream = try LandmarkStream(contentsOf: fixture("format/v1-two-hands.lmk"))
    #expect(stream.header.format == "handy-landmarks")
    #expect(stream.header.version == 1)
    #expect(stream.header.source == "synth")
    #expect(stream.frames.map(\.t) == [0, 0.1, 0.2])
    #expect(stream.frames.map(\.face) == [FaceSample(yaw: 0), nil, FaceSample(yaw: nil)])
    #expect(stream.frames[0].hands.map(\.chirality) == [.right, .left])
    #expect(stream.frames[0].hands[0][.wrist] == JointSample(Point(x: 0.9, y: 0.75), confidence: 0.9))
    #expect(stream.frames[0].hands[0][.thumbCMC]?.confidence == 0.1)
    #expect(stream.frames[0].hands[1][.wrist]?.point == Point(x: 0.5, y: 0.75))
}

@Test func roundTripsThroughTheFileFormat() throws {
    let original = try LandmarkStream(contentsOf: fixture("format/v1-two-hands.lmk"))
    #expect(try LandmarkStream(data: original.encoded()) == original)
}

@Test func headerWithoutOptionalFieldsDecodes() throws {
    let data = Data(#"{"format":"handy-landmarks","version":1,"source":"vision"}"#.utf8)
    let stream = try LandmarkStream(data: data)
    #expect(stream.header.labels.isEmpty)
    #expect(stream.frames.isEmpty)
}

@Test func rejectsAnotherFormat() {
    let data = Data(#"{"format":"something-else","version":1,"source":"x"}"#.utf8)
    #expect(throws: LandmarkStreamError.notALandmarkStream("something-else")) { try LandmarkStream(data: data) }
}

@Test func rejectsAFutureVersion() {
    let data = Data(#"{"format":"handy-landmarks","version":99,"source":"x"}"#.utf8)
    #expect(throws: LandmarkStreamError.unsupportedVersion(99)) { try LandmarkStream(data: data) }
}

@Test func namesTheLineOfABadFrame() {
    let data = Data(
        """
        {"format":"handy-landmarks","version":1,"source":"x"}
        {"t":0,"hands":[]}
        {"t":0.1,"hands":[{"c":"right","j":[[0,0,1]]}]}
        """.utf8)
    #expect {
        try LandmarkStream(data: data)
    } throws: { error in
        guard case LandmarkStreamError.badFrame(line: 3, _) = error else { return false }
        return true
    }
}
