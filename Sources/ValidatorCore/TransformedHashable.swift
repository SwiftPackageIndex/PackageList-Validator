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


#warning("add test")
@dynamicMemberLookup
struct TransformedHashable<Value, Hashed>: Equatable, Hashable where Hashed: Hashable {
    var value: Value
    var transformed: Hashed

    init(_ value: Value, transform: (Value) -> Hashed) {
        self.value = value
        self.transformed = transform(value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(transformed)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.transformed == rhs.transformed
    }

    subscript<Member>(dynamicMember keyPath: KeyPath<Value, Member>) -> Member {
        value[keyPath: keyPath]
    }
}
