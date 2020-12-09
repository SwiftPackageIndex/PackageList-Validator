import Foundation


enum Retry {
    static func backedOffDelay(baseDelay: Double, retryCount: Int) -> UInt32 {
        (pow(2, max(0, retryCount - 1)) * Decimal(baseDelay) as NSDecimalNumber).uint32Value
    }

    static func attempt<T>(_ label: String,
                           delay: Double = 5,
                           retries: Int = 5,
                           _ block: () throws -> T) throws -> T {
        var currentTry = 1
        while currentTry <= retries {
            if currentTry > 1 {
                print("\(label) (attempt \(currentTry))")
            }
            do {
                return try block()
            } catch {
                let delay = backedOffDelay(baseDelay: delay, retryCount: currentTry)
                print("Retrying in \(delay) seconds ...")
                sleep(delay)
                currentTry += 1
            }
        }
        throw AppError.retryLimitExceeded
    }
}
