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

import ArgumentParser


public struct Validator: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "SPI Validator",
        subcommands: [CheckDependencies.self, CheckRedirects.self, MergeLists.self, Version.self],
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
            print("Version: \(AppVersion)")
        }
    }
}
