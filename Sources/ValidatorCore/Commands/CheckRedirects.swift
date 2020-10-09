import ArgumentParser
import Foundation


extension Validator {
    struct CheckRedirects: ParsableCommand {
        @Argument(help: "Package urls to check")
        var packageUrls: [URL]

        mutating func run() throws {
            print("Checking for redirects ...")
            packageUrls.forEach { packageURL in
                switch resolveRedirects(for: packageURL) {
                    case .initial:
                        print("•  \(packageURL) unchanged")
                    case .redirected(let url):
                        print("↦  \(packageURL) -> \(url)")
                }
            }
        }
    }
}
