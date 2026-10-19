import AppKit
import HandyCore
import HandyReplay
import Observation
import SwiftUI

/// A guided corpus recording: prompts each gesture and everyday activity on a timer and writes the
/// landmark stream (numbers only) with labels from the prompt times.
@MainActor
@Observable
final class CorpusRecorderModel {
    enum Status: Equatable {
        case setup
        case recording(prompt: String, label: String, remaining: Double, progress: Double, reading: Bool)
        case finished(path: String)
        case failed(String)
    }

    var conditions = CorpusConditions(participant: "p01", lighting: .office, distance: .near)
    private(set) var status = Status.setup
    @ObservationIgnored private var session = CorpusSession()
    @ObservationIgnored private var writer: LandmarkStreamWriter?
    @ObservationIgnored private var url: URL?
    @ObservationIgnored private var origin: Double?
    @ObservationIgnored private let begin: () -> Void
    @ObservationIgnored private let end: () -> Void

    /// `begin` turns tracking on and output to record-only; `end` restores it.
    init(begin: @escaping () -> Void, end: @escaping () -> Void) {
        self.begin = begin
        self.end = end
    }

    var isRecording: Bool {
        if case .recording = status { return true }
        return false
    }

    func start() {
        session = CorpusSession()
        let folder = AppPaths.data.appending(path: "Corpus")
        let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
            .replacingOccurrences(of: ":", with: "")
        let url = folder.appending(path: "\(conditions.slug)-\(stamp).lmk")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            writer = try LandmarkStreamWriter(
                url: url, header: .init(source: "corpus", labels: session.labels, meta: conditions.meta))
            self.url = url
            origin = nil
            status = .recording(prompt: "Get ready", label: "", remaining: session.gap, progress: 0, reading: true)
            begin()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func observe(_ frame: LandmarkFrame) {
        guard isRecording, let writer else { return }
        let origin = self.origin ?? frame.t
        self.origin = origin
        var shifted = frame
        shifted.t = frame.t - origin
        do {
            try writer.append(shifted)
        } catch {
            stop(failed: error.localizedDescription)
            return
        }
        let progress = shifted.t / session.totalSeconds
        switch session.phase(at: shifted.t) {
        case .reading(let next, let remaining):
            let prompt = session.prompts[next]
            status = .recording(
                prompt: prompt.instruction, label: prompt.label, remaining: remaining, progress: progress, reading: true
            )
        case .doing(let index, let remaining):
            let prompt = session.prompts[index]
            status = .recording(
                prompt: prompt.instruction, label: prompt.label, remaining: remaining, progress: progress,
                reading: false)
        case .finished:
            stop(failed: nil)
        }
    }

    func stop(failed: String? = nil) {
        try? writer?.close()
        writer = nil
        end()
        if let failed {
            status = .failed(failed)
        } else if let url {
            status = .finished(path: url.path(percentEncoded: false))
        }
    }
}

struct CorpusRecorderView: View {
    @Bindable var model: CorpusRecorderModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch model.status {
            case .setup, .failed, .finished:
                setup
            case .recording(let prompt, _, let remaining, let progress, let reading):
                VStack(spacing: 16) {
                    Text(reading ? "Next" : "Now").font(.headline).foregroundStyle(.secondary)
                    Text(prompt)
                        .font(.title.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Text(remaining, format: .number.precision(.fractionLength(0)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(reading ? Color.secondary : Color.accentColor)
                    ProgressView(value: min(progress, 1))
                    Button("Stop Recording") { model.stop() }
                }
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    @ViewBuilder
    private var setup: some View {
        Text("Record a corpus session").font(.title2.weight(.semibold))
        Text(
            "About 9 minutes: Handy asks for each gesture a few times, then everyday activity. Only hand landmark "
                + "numbers are saved, never video. Nothing you do is sent to your Mac as input while recording."
        )
        .foregroundStyle(.secondary)
        Form {
            TextField("Participant", text: $model.conditions.participant)
            Picker("Lighting", selection: $model.conditions.lighting) {
                ForEach(CorpusConditions.Lighting.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Picker("Distance", selection: $model.conditions.distance) {
                ForEach(CorpusConditions.Distance.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Skin tone (optional)", selection: $model.conditions.skinTone) {
                Text("Not given").tag(String?.none)
                ForEach(["I", "II", "III", "IV", "V", "VI"], id: \.self) { Text("Type \($0)").tag(Optional($0)) }
            }
            TextField(
                "Background (optional)",
                text: Binding(
                    get: { model.conditions.background ?? "" },
                    set: { model.conditions.background = $0.isEmpty ? nil : $0 }))
        }
        if case .finished(let path) = model.status {
            Label("Saved \(URL(filePath: path).lastPathComponent)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        if case .failed(let message) = model.status {
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        Button("Start Recording") { model.start() }
            .buttonStyle(.borderedProminent)
            .disabled(model.conditions.participant.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
