import Foundation
import Observation

@Observable
@MainActor
final class StorageScanner {
    var result = ScanResult()
    var isScanning = false
    var scanProgress: String = ""
    var isDeleting = false
    var deleteLog: [String] = []

    private let home = FileManager.default.homeDirectoryForCurrentUser.path()

    func scan() async {
        isScanning = true
        result = ScanResult()
        deleteLog = []

        let scanners: [(String, () async -> [StorageItem])] = [
            ("Docker", scanDocker),
            ("Xcode", scanXcode),
            ("Node.js", scanNode),
            ("Flutter", scanFlutter),
            ("Gradle", scanGradle),
            ("AIツール", scanAITools),
            ("システムキャッシュ", scanSystemCaches),
            ("一時ファイル", scanTmpFiles),
            ("APFSスナップショット", scanAPFSSnapshots),
        ]

        for (name, scanner) in scanners {
            scanProgress = "\(name) をスキャン中..."
            let items = await scanner()
            result.items.append(contentsOf: items)
        }

        // Auto-select safe items
        for i in result.items.indices {
            if result.items[i].safety == .safe {
                result.items[i].isSelected = true
            }
        }

        scanProgress = ""
        isScanning = false
    }

    func deleteSelected() async {
        isDeleting = true
        deleteLog = []
        let selected = result.items.filter(\.isSelected)
        let fm = FileManager.default

        for item in selected {
            do {
                if fm.fileExists(atPath: item.path) {
                    try fm.removeItem(atPath: item.path)
                    deleteLog.append("削除完了: \(item.name) (\(item.formattedSize))")
                }
            } catch {
                deleteLog.append("削除失敗: \(item.name) - \(error.localizedDescription)")
            }
        }

        // Re-scan
        await scan()
        isDeleting = false
    }

    func toggleItem(_ id: UUID) {
        if let idx = result.items.firstIndex(where: { $0.id == id }) {
            result.items[idx].isSelected.toggle()
        }
    }

    func selectAll(in category: StorageCategory) {
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = true
        }
    }

    func deselectAll(in category: StorageCategory) {
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = false
        }
    }

    // MARK: - Scanners

    private func scanDocker() async -> [StorageItem] {
        var items: [StorageItem] = []

        // Docker disk usage via docker system df
        guard let output = runCommand("docker", "system", "df", "--format", "{{.Type}}\t{{.Size}}\t{{.Reclaimable}}") else {
            return items
        }

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            let typeName = String(parts[0])
            let reclaimableStr = String(parts[2])
            let bytes = parseDockerSize(reclaimableStr)
            guard bytes > 10_000_000 else { continue } // >10MB

            items.append(StorageItem(
                name: "Docker \(typeName) (回収可能)",
                path: "docker-\(typeName.lowercased())",
                size: bytes,
                category: .docker,
                safety: .safe,
                detail: "docker system prune で削除"
            ))
        }

        // Docker disk image
        let dockerPath = "\(home)/Library/Containers/com.docker.docker"
        if let size = directorySize(dockerPath) {
            items.append(StorageItem(
                name: "Docker ディスクイメージ",
                path: dockerPath,
                size: size,
                category: .docker,
                safety: .dangerous,
                detail: "Docker全体のディスクイメージ（削除するとDocker再セットアップが必要）"
            ))
        }

        return items
    }

    private func scanXcode() async -> [StorageItem] {
        var items: [StorageItem] = []
        let xcodeBase = "\(home)/Library/Developer/Xcode"

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(xcodeBase)/DerivedData", "Xcode DerivedData", .safe, "ビルドキャッシュ（ビルド時に再生成）"),
            ("\(xcodeBase)/Archives", "Xcode Archives", .caution, "過去のアーカイブ（App Store提出済みなら不要）"),
            ("\(xcodeBase)/iOS DeviceSupport", "iOS DeviceSupport", .caution, "デバイスシンボル（接続時に再DL）"),
            ("\(home)/Library/Developer/CoreSimulator", "iOS Simulator", .caution, "シミュレータデータ"),
            ("/Library/Developer/CommandLineTools", "Command Line Tools", .dangerous, "開発ツール"),
        ]

        for (path, name, safety, detail) in targets {
            if let size = directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .xcode, safety: safety, detail: detail))
            }
        }

        return items
    }

    private func scanNode() async -> [StorageItem] {
        var items: [StorageItem] = []

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/.npm", "npm キャッシュ", .safe, "npm cache clean --force で再生成"),
            ("\(home)/Library/Caches/Yarn", "Yarn キャッシュ", .safe, "yarn cache clean で再生成"),
            ("\(home)/Library/pnpm", "pnpm ストア", .safe, "pnpm store prune で最適化"),
            ("\(home)/Library/Caches/pnpm", "pnpm キャッシュ", .safe, "パッケージキャッシュ"),
            ("\(home)/.nvm", "nvm (Node バージョン)", .caution, "未使用バージョンを削除可能"),
        ]

        for (path, name, safety, detail) in targets {
            if let size = directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .nodePackages, safety: safety, detail: detail))
            }
        }

        // Find large node_modules in workspace
        if let workspaceModules = findNodeModules("\(home)/workspace") {
            items.append(contentsOf: workspaceModules)
        }

        return items
    }

    private func scanFlutter() async -> [StorageItem] {
        var items: [StorageItem] = []

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/.pub-cache", "Flutter pub キャッシュ", .safe, "dart pub cache repair で再生成"),
            ("\(home)/Library/Caches/CocoaPods", "CocoaPods キャッシュ", .safe, "pod cache clean --all で再生成"),
        ]

        for (path, name, safety, detail) in targets {
            if let size = directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .flutter, safety: safety, detail: detail))
            }
        }

        return items
    }

    private func scanGradle() async -> [StorageItem] {
        var items: [StorageItem] = []
        let gradlePath = "\(home)/.gradle"
        if let size = directorySize(gradlePath), size > 100_000_000 {
            items.append(StorageItem(
                name: "Gradle キャッシュ",
                path: gradlePath,
                size: size,
                category: .gradle,
                safety: .safe,
                detail: "ビルド依存関係キャッシュ（ビルド時に再DL）"
            ))
        }
        return items
    }

    private func scanAITools() async -> [StorageItem] {
        var items: [StorageItem] = []

        let targets: [(String, String, SafetyLevel, String)] = [
            ("/private/tmp/claude-501", "Claude Code 一時ファイル", .safe, "ワークツリーと実行結果の一時データ"),
            ("\(home)/Library/Application Support/Claude", "Claude Desktop データ", .caution, "Claude Desktopの会話履歴等"),
            ("\(home)/Library/Caches/com.anthropic.claudefordesktop.ShipIt", "Claude Desktop 更新キャッシュ", .safe, "アップデートキャッシュ"),
            ("\(home)/Library/Application Support/Cursor", "Cursor データ", .caution, "Cursor設定・拡張データ"),
        ]

        for (path, name, safety, detail) in targets {
            if let size = directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .aiTools, safety: safety, detail: detail))
            }
        }

        return items
    }

    private func scanSystemCaches() async -> [StorageItem] {
        var items: [StorageItem] = []

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/Library/Caches/Google", "Google Chrome キャッシュ", .safe, "ブラウザキャッシュ"),
            ("\(home)/Library/Caches/Homebrew", "Homebrew キャッシュ", .safe, "brew cleanup で削除可能"),
            ("\(home)/Library/Caches/com.microsoft.VSCode.ShipIt", "VS Code 更新キャッシュ", .safe, "アップデートキャッシュ"),
            ("\(home)/Library/Caches/ms-playwright", "Playwright ブラウザ", .safe, "テスト用ブラウザバイナリ"),
            ("\(home)/Library/Caches/pip", "pip キャッシュ", .safe, "Pythonパッケージキャッシュ"),
        ]

        for (path, name, safety, detail) in targets {
            if let size = directorySize(path), size > 30_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .systemCaches, safety: safety, detail: detail))
            }
        }

        return items
    }

    private func scanTmpFiles() async -> [StorageItem] {
        var items: [StorageItem] = []
        let fm = FileManager.default
        let tmpPath = "/private/tmp"

        guard let contents = try? fm.contentsOfDirectory(atPath: tmpPath) else { return items }

        for entry in contents {
            let fullPath = "\(tmpPath)/\(entry)"
            if let size = directorySize(fullPath), size > 100_000_000 {
                items.append(StorageItem(
                    name: "tmp/\(entry)",
                    path: fullPath,
                    size: size,
                    category: .tmpFiles,
                    safety: .caution,
                    detail: "一時ファイル"
                ))
            }
        }

        return items
    }

    private func scanAPFSSnapshots() async -> [StorageItem] {
        var items: [StorageItem] = []

        guard let output = runCommand("diskutil", "apfs", "listSnapshots", "disk3s1") else {
            return items
        }

        var currentName: String?
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Name:") {
                currentName = String(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Purgeable:"), let name = currentName {
                items.append(StorageItem(
                    name: "スナップショット: \(name.prefix(40))...",
                    path: name,
                    size: 0, // Size not directly queryable
                    category: .apfsSnapshots,
                    safety: .caution,
                    detail: "sudo tmutil deletelocalsnapshots で削除（サイズ不明・数十GB の可能性）"
                ))
                currentName = nil
            }
        }

        return items
    }

    // MARK: - Helpers

    private func directorySize(_ path: String) -> Int64? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return nil }

        // Use du for accuracy and speed
        guard let output = runCommand("du", "-sk", path) else { return nil }
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard let kb = Int64(parts.first ?? "") else { return nil }
        return kb * 1024
    }

    private func findNodeModules(_ basePath: String) -> [StorageItem]? {
        let fm = FileManager.default
        guard let projects = try? fm.contentsOfDirectory(atPath: basePath) else { return nil }
        var items: [StorageItem] = []

        for project in projects {
            let nmPath = "\(basePath)/\(project)/node_modules"
            if let size = directorySize(nmPath), size > 100_000_000 {
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

        return items.isEmpty ? nil : items
    }

    private func runCommand(_ args: String...) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func parseDockerSize(_ str: String) -> Int64 {
        // Parse strings like "42.97GB (62%)" or "21.13GB"
        let cleaned = str.replacingOccurrences(of: #"\s*\(.*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let multipliers: [(String, Double)] = [
            ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("B", 1),
        ]
        for (suffix, mult) in multipliers {
            if cleaned.hasSuffix(suffix),
               let val = Double(cleaned.dropLast(suffix.count)) {
                return Int64(val * mult)
            }
        }
        return 0
    }
}
