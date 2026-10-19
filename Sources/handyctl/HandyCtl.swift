import ArgumentParser

@main
struct HandyCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "handyctl",
        abstract: "Drive and prove Handy without a camera. Every command prints JSON.",
        subcommands: [
            // Environment
            Doctor.self,
            // The running app
            State.self,
            Send.self,
            Record.self,
            Screenshot.self,
            Windows.self,
            Inject.self,
            // Headless engine
            Synth.self,
            Replay.self,
            Features.self,
            BenchPerception.self,
            BenchCursor.self,
            TrainClassifier.self,
        ]
    )
}
