import Foundation


enum AppError: Error {
    case decodingError(Error, json: String)
    case dumpPackageError(String)
    case ioError(String)
    case noData(URL)
}
