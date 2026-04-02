import Foundation

struct GradleScanner: CategoryScanner {
    let category = StorageCategory.gradle
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        let gradlePath = "\(home)/.gradle"
        guard let size = shell.directorySize(gradlePath), size > 100_000_000 else { return [] }
        return [StorageItem(
            name: "Gradle キャッシュ",
            path: gradlePath,
            size: size,
            category: .gradle,
            safety: .safe,
            detail: "ビルド依存関係キャッシュ（ビルド時に再DL）"
        )]
    }
}
