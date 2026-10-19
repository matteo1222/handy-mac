import Foundation
import HandyCore
import Testing

private func load(_ name: String) throws -> UserSettings {
    let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: "json"))
    return try JSONDecoder().decode(UserSettings.self, from: Data(contentsOf: url))
}

@Test func decodesTheFrozenVersionOneFile() throws {
    let settings = try load("settings-v1")
    #expect(settings.preset == .couch)
    #expect(settings[.click] == 0.8)
    #expect(settings[.engage] == 0.25)
    #expect(settings[.scroll] == 0.5)
    #expect(settings.cameraID == "3642F2CD-E322-42E7-9360-19815B003AA6")
}

@Test func aSparseFileGetsDefaults() throws {
    #expect(try load("settings-v1-sparse") == UserSettings())
}

@Test func aNewerFileKeepsWhatItCanAndClampsTheRest() throws {
    let settings = try load("settings-v2-from-the-future")
    #expect(settings.preset == .desk, "an unknown preset falls back")
    #expect(settings[.click] == 1, "out-of-range values are clamped")
    #expect(settings.cameraID == "X")
}

@Test func roundTripsAndWritesTheCurrentVersion() throws {
    var settings = UserSettings(preset: .presenter, cameraID: "cam")
    settings[.flick] = 0.9
    let data = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(UserSettings.self, from: data) == settings)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(object["version"] as? Int == UserSettings.currentVersion)
}

@Test func presetsStoreDifferentFiltersAndThresholds() {
    let desk = Preset.desk.values
    let couch = Preset.couch.values
    let presenter = Preset.presenter.values
    #expect(couch.tracker.filter != desk.tracker.filter)
    #expect(couch.engine.pointer.slowGain > desk.engine.pointer.slowGain)
    #expect(presenter.engine.armHold > desk.engine.armHold)
    #expect(presenter.engine.pointer.deadband > desk.engine.pointer.deadband)
}

@Test func sensitivityMovesThresholdsTheRightWay() {
    var settings = UserSettings()
    let neutral = settings.tuning(calibration: nil).engine
    #expect(neutral == Preset.desk.values.engine, "0.5 everywhere is the preset itself")
    settings[.engage] = 1
    settings[.click] = 1
    settings[.flick] = 0
    let eager = settings.tuning(calibration: nil).engine
    #expect(eager.armHold < neutral.armHold)
    #expect(eager.click.press > neutral.click.press)
    let span = (eager.click.release - eager.click.press) - (neutral.click.release - neutral.click.press)
    #expect(abs(span) < 1e-9, "the hysteresis band keeps its width")
    #expect(eager.flick.distance > neutral.flick.distance)
}
