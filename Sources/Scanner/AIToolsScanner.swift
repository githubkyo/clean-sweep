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
                        name: L("ai.claude.code", entry),
                        path: fullPath,
                        size: size,
                        category: .aiTools,
                        safety: .safe,
                        detail: L("ai.claude.code.detail")
                    ))
                }
            }
        }

        let otherTargets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/Library/Application Support/Claude", L("ai.claude.desktop"), .caution, L("ai.claude.desktop.detail")),
            ("\(home)/Library/Caches/com.anthropic.claudefordesktop.ShipIt", L("ai.claude.update"), .safe, L("ai.claude.update.detail")),
            ("\(home)/Library/Application Support/Cursor", L("ai.cursor"), .caution, L("ai.cursor.detail")),
        ]

        for (path, name, safety, detail) in otherTargets {
            if let size = shell.directorySize(path), size > 50_000_000 {
                items.append(StorageItem(name: name, path: path, size: size, category: .aiTools, safety: safety, detail: detail))
            }
        }

        return items
    }
}
