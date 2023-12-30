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


extension URL {
    func appendingGitExtension() -> Self {
        let url = URL(string: absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")))!
        if url.pathExtension.lowercased() == "git" {
            return url.deletingPathExtension().appendingPathExtension("git")
        } else {
            if url.lastPathComponent.lowercased() == ".git" { // turn foo/.git into foo.git
                return URL(
                    string: url.deletingLastPathComponent()
                        .absoluteString
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                )!
                .appendingPathExtension("git")
            } else {
                return url.appendingPathExtension("git")
            }
        }
    }

    func deletingGitExtension() -> URL {
        if pathExtension.lowercased() == "git" {
            return deletingPathExtension()
        } else {
            if lastPathComponent.lowercased() == ".git" { // turn foo/.git into foo
                return URL(
                    string: deletingLastPathComponent()
                        .absoluteString
                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                )!
            } else {
                return self
            }
        }
    }
}
