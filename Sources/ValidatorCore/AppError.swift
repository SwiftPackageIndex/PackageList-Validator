import Foundation


enum AppError: Error {
    case dumpPackageError(String)
    case noData(URL)
}
