import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIO
import NIOHTTP1


extension Validator {
    struct CheckDependencies: ParsableCommand {
        @Argument(help: "Package urls to check")
        var packageURLs: [URL]

        mutating func run() throws {
            print("Checking dependencies ...")
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try? client.syncShutdown() }

            try packageURLs.forEach { packageURL in
                print("- \(packageURL) ...")
                try findDependencies(client: client, url: packageURL)
                    .wait()
                    .forEach { url in
                        print("  - \(url)")
                }
            }
        }
    }
}


struct Product: Decodable {
    let name: String
}


struct Dependency: Decodable, Hashable {
    let name: String
    let url: URL
}


struct Package: Decodable {
    let name: String
    let products: [Product]
    let dependencies: [Dependency]
}


func dumpPackage(manifestURL: URL) throws -> [URL] {
    try withTempDir { tempDir -> [URL] in
        let fileURL = URL(fileURLWithPath: tempDir).appendingPathComponent("Package.swift")
        let data = try Data(contentsOf: manifestURL)
        guard Current.fileManager.createFile(fileURL.path, data, nil) else {
            throw AppError.dumpPackageError("failed to save manifest \(manifestURL.absoluteString) to temp directory \(fileURL.absoluteString)")
        }
        guard let pkgJSON = try Current.shell.run(command: .packageDump, at: tempDir)
                .data(using: .utf8) else {
            throw AppError.dumpPackageError("package dump did not return data")
        }
        let pkg = try JSONDecoder().decode(Package.self, from: pkgJSON)
        return pkg.dependencies.map(\.url)
    }
}


func findDependencies(client: HTTPClient, url: URL) throws -> EventLoopFuture<[URL]> {
    getManifestURL(client: client, url: url)
        .flatMapThrowing {
            try dumpPackage(manifestURL: $0)
        }
}


func fetch<T: Decodable>(_ type: T.Type, client: HTTPClient, url: URL) -> EventLoopFuture<T> {
    let eventLoop = client.eventLoopGroup.next()
    let headers = HTTPHeaders([("User-Agent", "SPI-Validator"),])
    do {
        let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)
        return client.execute(request: request)
            .flatMap { response in
                guard let body = response.body else {
                    return eventLoop.makeFailedFuture(AppError.noData(url))
                }
                do {
                    let content = try JSONDecoder().decode(type, from: body)
                    return eventLoop.makeSucceededFuture(content)
                } catch {
                    //  print(body.getString(at: 0, length: body.readableBytes) ?? "-")
                    return eventLoop.makeFailedFuture(error)
                }
            }
    } catch {
        return eventLoop.makeFailedFuture(error)
    }
}


func getDefaultBranch(client: HTTPClient, owner: String, repository: String) -> EventLoopFuture<String> {
    let url = URL(string: "https://api.github.com/repos/\(owner)/\(repository)")!

    struct Repository: Decodable {
        let default_branch: String
    }
    return fetch(Repository.self, client: client, url: url)
        .map(\.default_branch)
}


func getManifestURL(client: HTTPClient, url: URL) -> EventLoopFuture<URL> {
    let repository = url.deletingPathExtension().lastPathComponent
    let owner = url.deletingLastPathComponent().lastPathComponent
    return getDefaultBranch(client: client, owner: owner, repository: repository)
        .map { defaultBranch in
            URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(defaultBranch)/Package.swift")!
        }
}
