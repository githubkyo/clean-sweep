import Foundation
@testable import CleanSweep

/// Mock shell executor for testing scanners without real filesystem access
final class MockShellExecutor: ShellExecuting, @unchecked Sendable {
    var commandResults: [String: String] = [:]
    var directorySizes: [String: Int64] = [:]
    var executedCommands: [[String]] = []

    func run(_ args: [String]) -> String? {
        executedCommands.append(args)
        let key = args.joined(separator: " ")
        return commandResults[key]
    }

    func directorySize(_ path: String) -> Int64? {
        directorySizes[path]
    }
}
