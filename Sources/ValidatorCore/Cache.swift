import Foundation


struct Cache<T: Codable> {
    struct Key<T: Codable>: Hashable, CustomStringConvertible {
        let string: String

        var description: String {
            "[\(T.self) \(string)]"
        }
    }
    var data: [Key<T>: Data] = [:]

    subscript(key: Key<T>) -> T? {
        get {
            if let data = data[key] {
                print("Cache hit: \(key)")
                return try? JSONDecoder().decode(T.self, from: data)
            }
            return nil
        }
        set {
            data[key] = try! JSONEncoder().encode(newValue)
        }
    }
}
