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
            ("\(home)/.npm", "npm キャッシュ", .safe, "npm cache clean --force で再生成"),
            ("\(home)/Library/Caches/Yarn", "Yarn キャッシュ", .safe, "yarn cache clean で再生成"),
            ("\(home)/Library/pnpm", "pnpm ストア", .safe, "pnpm store prune で最適化"),
            ("\(home)/Library/Caches/pnpm", "pnpm キャッシュ", .safe, "パッケージキャッシュ"),
            ("\(home)/.nvm", "nvm (Node バージョン)", .caution, "未使用バージョンを削除可能"),
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
                            ? "⚠️ プロセス稼働中 — 削除するとサービスが停止します"
                            : "npm install / pnpm install で再生成"
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
            for line in output.split(separator: "\n") where line.hasPrefix("n") {
                dirs.insert(String(line.dropFirst()))
            }
        }

        // Check for docker-compose projects with running containers
        if let output = shell.run(["docker", "compose", "ls", "--format", "json"]) {
            // Each line is JSON: {"Name":"...","Status":"running(N)","ConfigFiles":"/.../docker-compose.yml"}
            for line in output.split(separator: "\n") {
                guard let data = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? {
                          // Single object fallback
                          if let single = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                              return [single]
                          }
                          return nil
                      }()
                else { continue }

                for entry in obj {
                    guard let status = entry["Status"] as? String, status.contains("running"),
                          let configFiles = entry["ConfigFiles"] as? String else { continue }
                    // ConfigFiles is the path to docker-compose.yml — get parent dir
                    let projectDir = (configFiles as NSString).deletingLastPathComponent
                    dirs.insert(projectDir)
                }
            }
        }

        return dirs
    }
}
