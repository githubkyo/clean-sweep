import Foundation

struct XcodeScanner: CategoryScanner {
    let category = StorageCategory.xcode
    let shell: ShellExecuting
    let home: String

    init(shell: ShellExecuting = ShellExecutor.shared, home: String = SystemInfo.shared.home) {
        self.shell = shell
        self.home = home
    }

    func scan() async -> [StorageItem] {
        let xcodeBase = "\(home)/Library/Developer/Xcode"

        let targets: [(String, String, SafetyLevel, String)] = [
            ("\(xcodeBase)/DerivedData", "Xcode DerivedData", .safe, "ビルドキャッシュ（ビルド時に再生成）"),
            ("\(xcodeBase)/Archives", "Xcode Archives", .caution, "過去のアーカイブ（App Store提出済みなら不要）"),
            ("\(xcodeBase)/iOS DeviceSupport", "iOS DeviceSupport", .caution, "デバイスシンボル（接続時に再DL）"),
            ("\(home)/Library/Developer/CoreSimulator", "iOS Simulator", .caution, "シミュレータデータ"),
        ]

        return targets.compactMap { path, name, safety, detail in
            guard let size = shell.directorySize(path), size > 50_000_000 else { return nil }
            return StorageItem(name: name, path: path, size: size, category: .xcode, safety: safety, detail: detail)
        }
    }
}
