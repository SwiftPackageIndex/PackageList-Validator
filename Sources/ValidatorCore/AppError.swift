import Foundation


enum AppError: Error {
    case decodingError(context: String, underlyingError: Error, json: String)
    case dumpPackageError(String)
    case ioError(String)
    case noData(URL)
    case rateLimited(until: Date)
    case retryLimitExceeded
    case runtimeError(String)
}
