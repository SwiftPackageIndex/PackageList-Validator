import Foundation
import ShellOut


struct Shell {
    var run: (ShellOutCommand, String, FileHandle?, FileHandle?) throws -> String

    @discardableResult
    func run(command: ShellOutCommand, at path: String = ".") throws -> String {
        return try run(command, path, nil, nil)
    }

    static let live: Self = .init(run: { cmd, path, stdout, stderr in
        try ShellOut.shellOut(to: cmd,
                              at: path,
                              outputHandle: stdout,
                              errorHandle: stderr)
    })

    static let mock: Self = .init(
        run: { _, _, _, _ in fatalError("not implemented") }
    )
}
