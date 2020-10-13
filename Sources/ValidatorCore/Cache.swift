import Foundation


struct Cache<T: Codable> {
    struct Key<T: Codable>: Hashable {
        let string: String
    }
    var data: [Key<T>: Data] = [:]

    subscript(key: Key<T>) -> T? {
        get {
            if let data = data[key] {
                // print("Cache hit for key \(key)")
                return try? JSONDecoder().decode(T.self, from: data)
            }
            return nil
        }
        set {
            data[key] = try! JSONEncoder().encode(newValue)
        }
    }
}
