import Foundation

struct APFSSnapshotScanner: CategoryScanner {
    let category = StorageCategory.apfsSnapshots
    let shell: ShellExecuting

    init(shell: ShellExecuting = ShellExecutor.shared) {
        self.shell = shell
    }

    func scan() async -> [StorageItem] {
        // Dynamically detect boot disk identifier
        let diskId = SystemInfo.shared.bootDiskIdentifier() ?? "disk3s1"
        guard let output = shell.run(["diskutil", "apfs", "listSnapshots", diskId]) else {
            return []
        }
        return Self.parseSnapshots(output)
    }

    static func parseSnapshots(_ output: String) -> [StorageItem] {
        var items: [StorageItem] = []
        var currentName: String?

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
                .drop(while: { $0 == "|" || $0 == " " })
                .trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Name:") {
                currentName = String(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.hasPrefix("Purgeable:"), let name = currentName {
                let displayName = name.count > 50 ? String(name.prefix(50)) + "..." : name
                let command = "sudo tmutil deletelocalsnapshots \(name)"
                items.append(StorageItem(
                    name: "スナップショット: \(displayName)",
                    path: name,
                    size: 0,
                    category: .apfsSnapshots,
                    safety: .caution,
                    detail: "sudo権限が必要（コマンドをクリップボードにコピー）",
                    deletionMethod: .sudoCommand(command)
                ))
                currentName = nil
            }
        }

        return items
    }
}
