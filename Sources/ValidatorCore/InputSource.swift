import Foundation


enum InputSource {
    case file(String)
    case invalid
    case packageList
    case packageURLs([PackageURL])

    func packageURLs() throws -> [PackageURL] {
        switch self {
            case .file(let path):
                let fileURL = URL(fileURLWithPath: path)
                return try JSONDecoder().decode([PackageURL].self,
                                                from: Data(contentsOf: fileURL))
            case .invalid:
                throw AppError.runtimeError("invalid input source")
            case .packageList:
                return try Github.packageList()
            case .packageURLs(let urls):
                return urls
        }
    }
}


