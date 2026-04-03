import Foundation

protocol CategoryScanner: Sendable {
    var category: StorageCategory { get }
    func scan() async -> [StorageItem]
}

// MARK: - ShellExecuting Protocol for DI/Testing

protocol ShellExecuting: Sendable {
    func run(_ args: [String]) -> String?
    func directorySize(_ path: String) -> Int64?
}

// MARK: - Real Implementation

struct ShellExecutor: ShellExecuting, Sendable {
    static let shared = ShellExecutor()

    func run(_ args: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Read stdout BEFORE waitUntilExit to avoid pipe buffer deadlock.
            // If the child writes more than the pipe buffer (~64KB), it blocks
            // on write — and waitUntilExit would never return.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func directorySize(_ path: String) -> Int64? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        guard let output = run(["du", "-sk", path]) else { return nil }
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard let kb = Int64(parts.first ?? "") else { return nil }
        return kb * 1024
    }

    // Convenience variadic wrapper
    func run(_ args: String...) -> String? {
        run(args)
    }
}

// MARK: - System Info (dynamic paths)

struct SystemInfo: Sendable {
    static let shared = SystemInfo()

    let home: String = FileManager.default.homeDirectoryForCurrentUser.path()
    let uid: String = String(getuid())

    var claudeTmpPath: String { "/private/tmp/claude-\(uid)" }

    func bootDiskIdentifier() -> String? {
        let executor = ShellExecutor.shared
        guard let output = executor.run(["diskutil", "info", "/"]) else { return nil }
        // Find "Part of Whole: diskXsY" or "APFS Physical Store" line
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Part of Whole:") {
                let disk = trimmed.replacingOccurrences(of: "Part of Whole:", with: "").trimmingCharacters(in: .whitespaces)
                return "\(disk)s1"
            }
        }
        // Fallback: try to get from mount point
        guard let _ = executor.run(["diskutil", "apfs", "list", "-plist"]) else { return nil }
        return "disk3s1"
    }
}
