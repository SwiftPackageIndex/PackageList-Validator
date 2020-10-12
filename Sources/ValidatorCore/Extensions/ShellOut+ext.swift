import ShellOut


extension ShellOutCommand {
    static let packageDump = ShellOutCommand(string: "/usr/bin/xcrun swift package dump-package")
}
