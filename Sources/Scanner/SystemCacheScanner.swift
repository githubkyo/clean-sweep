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
            ("\(home)/Library/Caches/Google", L("cache.chrome"), .safe, L("cache.chrome.detail")),
            ("\(home)/Library/Caches/Homebrew", L("cache.homebrew"), .safe, L("cache.homebrew.detail")),
            ("\(home)/Library/Caches/com.microsoft.VSCode.ShipIt", L("cache.vscode"), .safe, L("cache.vscode.detail")),
            ("\(home)/Library/Caches/ms-playwright", L("cache.playwright"), .safe, L("cache.playwright.detail")),
            ("\(home)/Library/Caches/pip", L("cache.pip"), .safe, L("cache.pip.detail")),
        ]

        return targets.compactMap { path, name, safety, detail in
            guard let size = shell.directorySize(path), size > 30_000_000 else { return nil }
            return StorageItem(name: name, path: path, size: size, category: .systemCaches, safety: safety, detail: detail)
        }
    }
}
