import Foundation


enum AppError: Error {
    case decodingError(context: String, underlyingError: Error, json: String)
    case dumpPackageError(String)
    case invalidPackage(url: PackageURL)
    case ioError(String)
    case noData(URL)
    case rateLimited(until: Date)
    case repositoryNotFound(owner: String, name: String)
    case requestFailed(URL, UInt)
    case retryLimitExceeded
    case runtimeError(String)
}
