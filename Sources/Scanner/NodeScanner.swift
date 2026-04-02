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

        // Detect node_modules in all immediate subdirectories of home
        // Scan common project directories dynamically
        let projectDirs = ["\(home)/workspace", "\(home)/Projects", "\(home)/Developer", "\(home)/repos"]
        let fm = FileManager.default
        for dir in projectDirs {
            guard let projects = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for project in projects {
                let nmPath = "\(dir)/\(project)/node_modules"
                if let size = shell.directorySize(nmPath), size > 100_000_000 {
                    items.append(StorageItem(
                        name: "\(project)/node_modules",
                        path: nmPath,
                        size: size,
                        category: .nodePackages,
                        safety: .safe,
                        detail: "npm install / pnpm install で再生成"
                    ))
                }
            }
        }

        return items
    }
}
