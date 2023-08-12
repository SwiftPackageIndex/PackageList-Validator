//
//  RegressionTests.swift
// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

@testable import ValidatorCore


final class RegressionTests: XCTestCase {

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
        let urls = expandDependencies(inputURLs: [p1, p2], retries: 0)

        // validate
        XCTAssertEqual(urls, [p1, p2])
    }

    func test_issue_1449_DecodingError() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1449
        // also
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1461

        for toolsVersion in ["5.1", "5.2", "5.3", "5.4", "5.5"] {
            // setup
            let data = try fixtureData(for: "Issue1449-\(toolsVersion).json")

            // MUT
            let pkg = try JSONDecoder().decode(Package.self, from: data)

            // validate
            XCTAssertEqual(pkg.name, "ValidatorTest", "failed for: \(toolsVersion)")
            XCTAssertEqual(pkg.toolsVersion?._version, "\(toolsVersion).0",
                           "failed for: \(toolsVersion)")
        }
    }

    func test_issue_1618_DecodingError() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/1618

        // setup
        let data = try fixtureData(for: "Issue1618.json")

        // MUT
        let pkg = try JSONDecoder().decode(Package.self, from: data)

        // validate
        XCTAssertEqual(pkg.name, "Bow OpenAPI")
    }

    func test_issue_2551_DecodingError() throws {
        // https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2551

        //        try Validator.CheckDependencies.run(inputSource: .packageURLs([
        //            .init(argument: "https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server")!
        //        ]), retries: 0)

        // setup
        let data = try fixtureData(for: "Issue2551.json")

        // MUT
        let pkg = try JSONDecoder().decode(Package.self, from: data)

        // validate
        XCTAssertEqual(pkg.name, "SPI-Server")
        XCTAssertEqual(pkg.dependencies.count, 17)
        XCTAssertEqual(pkg.dependencies.first?.firstRemote,
                       .init(rawValue: URL(string: "https://github.com/JohnSundell/Ink.git")!))
    }

}
