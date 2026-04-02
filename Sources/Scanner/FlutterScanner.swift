import Foundation

struct FlutterScanner: CategoryScanner {
    let category = StorageCategory.flutter
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(home)/.pub-cache", "Flutter pub キャッシュ", .safe, "dart pub cache repair で再生成"),
            ("\(home)/Library/Caches/CocoaPods", "CocoaPods キャッシュ", .safe, "pod cache clean --all で再生成"),
        ]

        return targets.compactMap { path, name, safety, detail in
            guard let size = shell.directorySize(path), size > 50_000_000 else { return nil }
            return StorageItem(name: name, path: path, size: size, category: .flutter, safety: safety, detail: detail)
        }
    }
}
