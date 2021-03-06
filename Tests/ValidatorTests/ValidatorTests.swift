import XCTest

import AsyncHTTPClient
import Foundation
import NIO
@testable import ValidatorCore


final class ValidatorTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        Current = .mock
    }

    func test_mergingWithExisting() throws {
        XCTAssertEqual(["a"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
        XCTAssertEqual(["a", "A"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingWithExisting(urls: ["A"].asURLs)
                        .map(\.absoluteString), ["A"])
        XCTAssertEqual(["A", "a", "A"].asURLs.mergingWithExisting(urls: ["a"].asURLs)
                        .map(\.absoluteString), ["a"])
    }

    func test_Github_packageList() throws {
        XCTAssertFalse(try Github.packageList().isEmpty)
    }

    func test_appendingGitExtension() throws {
        let s = "https://github.com/weichsel/ZIPFoundation/"
        XCTAssertEqual(PackageURL(rawValue: URL(string: s)!).appendingGitExtension().absoluteString,
                       "https://github.com/weichsel/ZIPFoundation.git")
    }

    func test_PackageURL_owner_repository() throws {
        do {
            let p = PackageURL.init(argument: "https://github.com/stephencelis/SQLite.swift.git")
            XCTAssertEqual(p?.owner, "stephencelis")
            XCTAssertEqual(p?.repository, "SQLite.swift")
        }
        do {
            let p = PackageURL.init(argument: "https://github.com/stephencelis/SQLite.swift")
            XCTAssertEqual(p?.owner, "stephencelis")
            XCTAssertEqual(p?.repository, "SQLite.swift")
        }
    }

    func test_getManifestURL() throws {
        // setup
        let pkgURL = PackageURL(argument: "https://github.com/foo/bar")!
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        defer { try? client.syncShutdown() }

        // MUT
        let url = try Package.getManifestURL(client: client,
                                             packageURL: pkgURL).wait()

        // validate
        XCTAssertEqual(url,
                       .init("https://raw.githubusercontent.com/foo/bar/main/Package.swift"))
    }

    func test_findDependencies() throws {
        // Basic findDependencies test
        // setup
        Current.decodeManifest = { url in .init(
            name: "bar",
            products: [
                .init(name: "prod")
            ],
            dependencies: [
                .init(name: "a",
                      url: PackageURL(argument: "https://github.com/dep/A")!)
            ]) }

        // MUT
        let url = PackageURL(argument: "https://github.com/foo/bar")!
        let urls = try findDependencies(packageURL: url, waitIfRateLimited: false, retries: 0)

        // validate
        XCTAssertEqual(urls,
                       [PackageURL(argument: "https://github.com/dep/A.git")!])
    }

    func test_expandDependencies() throws {
        // Test case preservation when dependencies are package list item. For instance:
        // A -> dependencies x, y
        // B -> dependencies z, a
        // this will expand into [A, x, y, B, z, a] before uniquing and sorting.
        // We want to avoid uniquing [A, a] into [a] and this is what this test is
        // about

        // setup
        let A = PackageURL(argument: "https://github.com/foo/A.git")!
        let B = PackageURL(argument: "https://github.com/foo/B.git")!
        let x = PackageURL(argument: "https://github.com/foo/x.git")!
        let y = PackageURL(argument: "https://github.com/foo/y.git")!
        let z = PackageURL(argument: "https://github.com/foo/z.git")!
        let a = PackageURL(argument: "https://github.com/foo/a.git")!
        Current.decodeManifest = { url in
            switch url {
                case .init("https://raw.githubusercontent.com/foo/A/main/Package.swift"):
                    return .mock(dependencyURLs: [x, y])
                case .init("https://raw.githubusercontent.com/foo/B/main/Package.swift"):
                    return .mock(dependencyURLs: [z, a])
                default:
                    return .mock(dependencyURLs: [])
            }
        }

        // MUT
        let urls = try expandDependencies(inputURLs: [A, B], retries: 0)

        // validate
        XCTAssertEqual(urls, [A, B, x, y, z])
    }

    func test_expandDependencies_normalising() throws {
        // Ensure dependency URLs are properly normalised and case preserving
        // setup
        let A = PackageURL(argument: "https://github.com/foo/A.git")!
        let B = PackageURL(argument: "https://github.com/foo/B.git")!
        let x = PackageURL(argument: "https://github.com/foo/x")!
        let Y = PackageURL(argument: "https://github.com/foo/Y")!
        let z = PackageURL(argument: "https://github.com/foo/z")!
        let a = PackageURL(argument: "https://github.com/foo/a")!
        let x_git = PackageURL(argument: "https://github.com/foo/x.git")!
        let Y_git = PackageURL(argument: "https://github.com/foo/Y.git")!
        let z_git = PackageURL(argument: "https://github.com/foo/z.git")!
        Current.decodeManifest = { url in
            switch url {
                case .init("https://raw.githubusercontent.com/foo/A/main/Package.swift"):
                    return .mock(dependencyURLs: [x, Y])
                case .init("https://raw.githubusercontent.com/foo/B/main/Package.swift"):
                    return .mock(dependencyURLs: [z, a])
                default:
                    return .mock(dependencyURLs: [])
            }
        }

        // MUT
        let urls = try expandDependencies(inputURLs: [A, B], retries: 0)

        // validate
        XCTAssertEqual(urls, [A, B, x_git, Y_git, z_git])
    }

    func test_issue_917() throws {
        // Ensure we don't change existing package's capitalisation
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/917
        // setup
        let p1 = PackageURL(argument:
                                "https://github.com/1fr3dg/ResourcePackage.git")!
        let dep = PackageURL(argument:
                                "https://github.com/1Fr3dG/SimpleEncrypter.git")!
        let p2 = PackageURL(argument:
                                "https://github.com/1fr3dg/SimpleEncrypter.git")!
        Current.decodeManifest = { url in
            url == .init("https://raw.githubusercontent.com/1fr3dg/ResourcePackage/main/Package.swift")
            ? .mock(dependencyURLs: [dep])
            : .mock(dependencyURLs: [])
        }

        // MUT
        let urls = try expandDependencies(inputURLs: [p1, p2], retries: 0)

        // validate
        XCTAssertEqual(urls, [p1, p2])
    }
}


extension Package {
    static func mock(dependencyURLs: [PackageURL]) -> Self {
        .init(name: "",
              products: [.mock],
              dependencies: dependencyURLs.map { .init(name: "",
                                                       url: $0) } )
    }
}


extension Package.Product {
    static let mock: Self = .init(name: "product")
}


private extension Array where Element == String {
    var asURLs: [PackageURL] {
        compactMap(URL.init(string:))
            .map(PackageURL.init(rawValue:))
    }
}


private extension Package.ManifestURL {
    init(_ urlString: String) {
        self.init(rawValue: URL(string: urlString)!)
    }
}
