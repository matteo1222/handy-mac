import HandyCore
import Testing

private func hand(at x: Double, _ chirality: Chirality = .right, confidence: Double = 0.9, missing: Int = 0) -> HandPose
{
    let joints: [JointSample?] = Joint.allCases.map { joint in
        guard joint.rawValue >= missing || joint == .wrist || joint == .middleMCP else { return nil }
        let offset = Double(joint.rawValue) * 0.005
        return JointSample(Point(x: x + offset, y: 0.8 - offset), confidence: confidence)
    }
    return HandPose(chirality: chirality, joints: joints)
}

@Test func jointsBelowThreeTenthsConfidenceAreDropped() {
    var tracker = HandTracker()
    var pose = hand(at: 0.5)
    pose[.indexTip] = JointSample(Point(x: 0.6, y: 0.6), confidence: 0.29)
    let tracks = tracker.update([pose], at: 0)
    #expect(tracks.count == 1)
    #expect(tracks[0][.indexTip] == nil)
    #expect(tracks[0][.wrist] != nil)
}

@Test func handsWithFewerThanFifteenValidJointsAreRejected() {
    var tracker = HandTracker()
    #expect(tracker.update([hand(at: 0.5, missing: 8)], at: 0).isEmpty, "13 joints left")
    #expect(tracker.update([hand(at: 0.5, missing: 6)], at: 0.033).count == 1, "15 joints left")
}

@Test func handsKeepTheirIdentityByNearestWrist() {
    var tracker = HandTracker()
    let first = tracker.update([hand(at: 0.3), hand(at: 1.2, .left)], at: 0)
    let second = tracker.update([hand(at: 1.25, .left), hand(at: 0.33)], at: 0.033)
    let idNear03 = first.first { $0.chirality == .right }?.id
    #expect(second.first { $0.chirality == .right }?.id == idNear03)
    #expect(Set(first.map(\.id)) == Set(second.map(\.id)))
}

@Test func filtersStartFreshAfterTheTrackIsLost() {
    var tracker = HandTracker()
    _ = tracker.update([hand(at: 0.3)], at: 0)
    let id = tracker.update([hand(at: 0.31)], at: 0.033).first?.id
    _ = tracker.update([], at: 0.5)
    let after = tracker.update([hand(at: 0.6)], at: 0.533)
    #expect(after.first?.id != id, "a new track after the grace period")
    #expect(after.first?[.wrist] == Point(x: 0.6, y: 0.8), "an unfiltered first sample: the filter was reset")
}
