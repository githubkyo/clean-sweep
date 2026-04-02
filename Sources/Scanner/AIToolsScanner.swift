import Foundation

struct AIToolsScanner: CategoryScanner {
    let category = StorageCategory.aiTools
    let shell: ShellExecuting
    let home: String
    let claudeTmpPath: String

    init(
        shell: ShellExecuting = ShellExecutor.shared,
        home: String = SystemInfo.shared.home,
        claudeTmpPath: String = SystemInfo.shared.claudeTmpPath
    ) {
        self.shell = shell
        self.home = home
        self.claudeTmpPath = claudeTmpPath
    }

    func scan() async -> [StorageItem] {
        var items: [StorageItem] = []

        let fm = FileManager.default
        if let entries = try? fm.contentsOfDirectory(atPath: claudeTmpPath) {
            for entry in entries {
                let fullPath = "\(claudeTmpPath)/\(entry)"
                if let size = shell.directorySize(fullPath), size > 50_000_000 {
                    items.append(StorageItem(
                        name: "Claude Code: \(entry)",
                        path: fullPath,
                        size: size,
                        category: .aiTools,
                        safety: .safe,
                        detail: "ワークツリーと実行結果の一時データ"
                    ))
                }
            }
        }

        let otherTargets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/Library/Application Support/Claude", "Claude Desktop データ", .caution, "会話履歴等"),
            ("\(home)/Library/Caches/com.anthropic.claudefordesktop.ShipIt", "Claude Desktop 更新キャッシュ", .safe, "アップデートキャッシュ"),
            ("\(home)/Library/Application Support/Cursor", "Cursor データ", .caution, "設定・拡張データ"),
        ]

        for (path, name, safety, detail) in otherTargets {
            if let size = shell.directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .aiTools, safety: safety, detail: detail))
            }
        }

        return items
    }
}
