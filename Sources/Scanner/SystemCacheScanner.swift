import Foundation

struct SystemCacheScanner: CategoryScanner {
    let category = StorageCategory.systemCaches
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/Library/Caches/Google", "Google Chrome キャッシュ", .safe, "ブラウザキャッシュ"),
            ("\(home)/Library/Caches/Homebrew", "Homebrew キャッシュ", .safe, "brew cleanup で削除可能"),
            ("\(home)/Library/Caches/com.microsoft.VSCode.ShipIt", "VS Code 更新キャッシュ", .safe, "アップデートキャッシュ"),
            ("\(home)/Library/Caches/ms-playwright", "Playwright ブラウザ", .safe, "テスト用ブラウザバイナリ"),
            ("\(home)/Library/Caches/pip", "pip キャッシュ", .safe, "Pythonパッケージキャッシュ"),
        ]

        return targets.compactMap { path, name, safety, detail in
            guard let size = shell.directorySize(path), size > 30_000_000 else { return nil }
            return StorageItem(name: name, path: path, size: size, category: .systemCaches, safety: safety, detail: detail)
        }
    }
}
