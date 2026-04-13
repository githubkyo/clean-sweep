import Foundation

struct NodeScanner: CategoryScanner {
    let category = StorageCategory.nodePackages
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        var items: [StorageItem] = []

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/.npm", L("node.npm"), .safe, L("node.npm.detail")),
            ("\(home)/Library/Caches/Yarn", L("node.yarn"), .safe, L("node.yarn.detail")),
            ("\(home)/Library/pnpm", L("node.pnpm.store"), .safe, L("node.pnpm.store.detail")),
            ("\(home)/Library/Caches/pnpm", L("node.pnpm.cache"), .safe, L("node.pnpm.cache.detail")),
            ("\(home)/.nvm", L("node.nvm"), .caution, L("node.nvm.detail")),
        ]

        for (path, name, safety, detail) in targets {
            if let size = shell.directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .nodePackages, safety: safety, detail: detail))
            }
        }

        let activeProjectDirs = detectActiveProjectDirs()

        let projectDirs = ["\(home)/workspace", "\(home)/Projects", "\(home)/Developer", "\(home)/repos"]
        let fm = FileManager.default
        for dir in projectDirs {
            guard let projects = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for project in projects {
                let nmPath = "\(dir)/\(project)/node_modules"
                if let size = shell.directorySize(nmPath), size > 100_000_000 {
                    let projectDir = "\(dir)/\(project)"
                    let isActive = activeProjectDirs.contains(where: { projectDir.hasPrefix($0) })
                    items.append(StorageItem(
                        name: "\(project)/node_modules",
                        path: nmPath,
                        size: size,
                        category: .nodePackages,
                        safety: isActive ? .caution : .safe,
                        detail: isActive
                            ? L("node.active.detail")
                            : L("node.modules.detail")
                    ))
                }
            }
        }

        return items
    }

    /// Detect project directories that have running Node/Docker processes.
    private func detectActiveProjectDirs() -> Set<String> {
        var dirs = Set<String>()

        // Check for running node processes and their working directories
        if let output = shell.run(["lsof", "-c", "node", "-a", "-d", "cwd", "-Fn"]) {
            for line in output.split(separator: "\n") where line.hasPrefix("n/") {
                let path = String(line.dropFirst())
                // Skip root "/" — some node processes have cwd "/"
                if path.count > 1 {
                    dirs.insert(path)
                }
            }
        }

        // Check for running Docker containers — extract project names from container names
        // Container names follow the pattern: projectname-service-N (e.g., "autonomos-worker-1")
        if let output = shell.run(["docker", "ps", "--format", "{{.Names}}"]) {
            let containerNames = output.split(separator: "\n").map(String.init)
            // Extract unique project prefixes (everything before the last two "-service-N" parts)
            for name in containerNames {
                let parts = name.split(separator: "-")
                guard parts.count >= 2 else { continue }
                // Project name is the first segment(s) before the service name
                let projectName = String(parts[0])
                // Match against workspace directories (case-insensitive)
                let projectDirs = ["\(home)/workspace", "\(home)/Projects", "\(home)/Developer", "\(home)/repos"]
                for base in projectDirs {
                    let candidate = "\(base)/\(projectName)"
                    if FileManager.default.fileExists(atPath: candidate) {
                        dirs.insert(candidate)
                    }
                    // Also try case-insensitive match
                    if let entries = try? FileManager.default.contentsOfDirectory(atPath: base) {
                        for entry in entries where entry.lowercased() == projectName.lowercased() {
                            dirs.insert("\(base)/\(entry)")
                        }
                    }
                }
            }
        }

        return dirs
    }
}
