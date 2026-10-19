import ArgumentParser

@main
struct HandyCtl: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "handyctl",
        abstract: "Drive and prove Handy without a camera. Every command prints JSON.",
        subcommands: [Doctor.self, State.self, Send.self]
    )
}
