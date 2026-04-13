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
            ("\(xcodeBase)/DerivedData", L("xcode.derived"), .safe, L("xcode.derived.detail")),
            ("\(xcodeBase)/Archives", L("xcode.archives"), .caution, L("xcode.archives.detail")),
            ("\(xcodeBase)/iOS DeviceSupport", L("xcode.device"), .caution, L("xcode.device.detail")),
            ("\(home)/Library/Developer/CoreSimulator", L("xcode.simulator"), .caution, L("xcode.simulator.detail")),
        ]

        return targets.compactMap { path, name, safety, detail in
            guard let size = shell.directorySize(path), size > 50_000_000 else { return nil }
            return StorageItem(name: name, path: path, size: size, category: .xcode, safety: safety, detail: detail)
        }
    }
}
