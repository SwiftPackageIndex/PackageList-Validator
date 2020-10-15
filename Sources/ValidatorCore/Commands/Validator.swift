import ArgumentParser


public struct Validator: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "SPI Validator",
        subcommands: [CheckDependencies.self, CheckRedirects.self, Version.self],
        defaultSubcommand: Version.self
    )

    public mutating func run() throws {}

    public init() {}
}


extension Validator {
    struct Version: ParsableCommand {
        @Flag(name: [.customLong("version"), .customShort("v")],
              help: "Show version")
        var showVersion: Bool = false

        mutating func run() throws {
            print(AppVersion)
        }
    }
}
