// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
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
import Foundation


enum Output: ExpressibleByArgument {
    case file(URL)
    case stdout

    init?(argument: String) {
        switch argument {
            case "-":
                self = .stdout
            default:
                let url = URL(fileURLWithPath: argument)
                self = .file(url)
        }
    }

    func process(packageURLs: [String]) throws {
        switch self {
            case .file(let url):
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                let data = try encoder.encode(packageURLs)
                print("saving to \(url.path)...")
                try data.write(to: url)
            case .stdout:
                for url in packageURLs {
                    print(url)
                }
        }
    }
}
