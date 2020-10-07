import ArgumentParser
import Foundation


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Option(name: .shortAndLong, help: "Package url to check")
        var packageURL: URL

        mutating func run() throws {
            print("Checking \(packageURL) for redirects ...")
            switch resolveRedirects(for: packageURL) {
                case .initial:
                    print("\(packageURL) unchanged")
                case .redirected(let url):
                    print("\(packageURL) -> \(url)")
            }
        }
    }
}
