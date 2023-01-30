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
    var run: (ShellOutCommand, String, FileHandle?, FileHandle?) throws -> String

    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") throws -> String {
        return try run(command, path, nil, nil)
    }

    static let live: Self = .init(run: { cmd, path, stdout, stderr in
        try ShellOut.shellOut(to: cmd,
                              at: path,
                              outputHandle: stdout,
                              errorHandle: stderr)
    })

    static let mock: Self = .init(
        run: { _, _, _, _ in fatalError("not implemented") }
    )
}
