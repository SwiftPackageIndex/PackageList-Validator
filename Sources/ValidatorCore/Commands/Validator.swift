import ArgumentParser


public struct Validator: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "SPI Validator",
        subcommands: [CheckRedirects.self]
    )
    public mutating func run() throws {}
    public init() {}
}
