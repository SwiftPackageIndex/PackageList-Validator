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

import Foundation
import ShellOut


struct Shell {
    var run: (ShellOutCommand, String, FileHandle?, FileHandle?) async throws -> (stdout: String, stderr: String)

    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") async throws -> (stdout: String, stderr: String) {
        try await run(command, path, nil, nil)
    }

    static var live: Self {
        .init(run: { cmd, path, stdout, stderr in
            try await ShellOut.shellOut(
                to: cmd,
                at: path,
                outputHandle: stdout,
                errorHandle: stderr,
                environment: ProcessInfo.processInfo.environment
                    .merging(["SPI_PROCESSING": "1"], uniquingKeysWith: { $1 })
            )
        })
    }

    static var mock: Self {
        .init(
            run: { _, _, _, _ in fatalError("not implemented") }
        )
    }
}
