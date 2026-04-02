import Foundation

struct TmpFileScanner: CategoryScanner {
    let category = StorageCategory.tmpFiles
    let shell: ShellExecuting

    init(shell: ShellExecuting = ShellExecutor.shared) {
        self.shell = shell
    }

    func scan() async -> [StorageItem] {
        let fm = FileManager.default
        let tmpPath = "/private/tmp"
        guard let contents = try? fm.contentsOfDirectory(atPath: tmpPath) else { return [] }

        return contents.compactMap { entry in
            let fullPath = "\(tmpPath)/\(entry)"
            guard let size = shell.directorySize(fullPath), size > 100_000_000 else { return nil }
            return StorageItem(
                name: "tmp/\(entry)",
                path: fullPath,
                size: size,
                category: .tmpFiles,
                safety: .caution,
                detail: "一時ファイル"
            )
        }
    }
}
