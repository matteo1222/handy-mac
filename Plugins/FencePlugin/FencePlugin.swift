import PackagePlugin

/// Runs FenceCheck over the target's sources on every build that touches them.
/// A banned import fails the build with a compiler-style error at the import line.
@main
struct FencePlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let sources = target.sourceFiles(withSuffix: "swift").map(\.url)
        let stamp = context.pluginWorkDirectoryURL.appending(path: "FenceStamp.swift")
        return [
            .buildCommand(
                displayName: "Fence check \(target.name)",
                executable: try context.tool(named: "FenceCheck").url,
                arguments: [stamp.path(percentEncoded: false)] + sources.map { $0.path(percentEncoded: false) },
                inputFiles: sources,
                outputFiles: [stamp]
            )
        ]
    }
}
