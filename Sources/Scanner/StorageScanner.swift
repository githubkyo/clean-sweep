import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class StorageScanner {
    var result = ScanResult()
    var isScanning = false
    var scanProgress: String = ""
    var isDeleting = false
    var deleteLog: [String] = []
    var scanErrors: [String] = []
    var useTrash: Bool = true  // Safe default: move to Trash instead of permanent delete

    private let scanners: [any CategoryScanner]
    private let shell: ShellExecuting
    private var deletionTask: Task<Void, Never>?

    init(
        scanners: [any CategoryScanner]? = nil,
        shell: ShellExecuting = ShellExecutor.shared
    ) {
        self.shell = shell
        self.scanners = scanners ?? [
            DockerScanner(),
            XcodeScanner(),
            NodeScanner(),
            FlutterScanner(),
            GradleScanner(),
            AIToolsScanner(),
            SystemCacheScanner(),
            TmpFileScanner(),
            APFSSnapshotScanner(),
        ]
    }

    func scan() async {
        isScanning = true
        result = ScanResult()
        scanErrors = []

        for scanner in scanners {
            scanProgress = "\(scanner.category.rawValue) をスキャン中..."
            let items = await Task.detached { [scanner] in
                await scanner.scan()
            }.value
            result.items.append(contentsOf: items)
        }

        // Auto-select safe items (REQ-5)
        for i in result.items.indices where result.items[i].safety == .safe {
            result.items[i].isSelected = true
        }

        scanProgress = ""
        isScanning = false
    }

    func deleteSelected() {
        deleteLog = []
        isDeleting = true
        let selected = result.items.filter(\.isSelected)

        deletionTask = Task {
            var successCount = 0
            var failCount = 0
            var dockerPruneExecuted = false

            for item in selected {
                if Task.isCancelled {
                    deleteLog.append("中断: 残り\(selected.count - successCount - failCount)件をスキップ")
                    break
                }

                switch item.deletionMethod {
                case .fileRemoval:
                    let trash = useTrash
                    let (success, message) = await Task.detached {
                        Self.performFileDeletion(item, useTrash: trash)
                    }.value
                    deleteLog.append(message)
                    if success { successCount += 1 } else { failCount += 1 }

                case .dockerPrune:
                    if dockerPruneExecuted {
                        // prune is global — only run once per deletion batch
                        deleteLog.append("スキップ: \(item.name)（pruneは実行済み）")
                        successCount += 1
                        continue
                    }
                    dockerPruneExecuted = true
                    let dockerItems = selected.filter { $0.deletionMethod == .dockerPrune }
                    let names = dockerItems.map(\.name).joined(separator: ", ")
                    let (pruneSuccess, pruneMessage) = await Task.detached { [shell = self.shell] in
                        Self.performDockerPrune(shell: shell, itemName: names)
                    }.value
                    deleteLog.append(pruneMessage)
                    if pruneSuccess { successCount += 1 } else { failCount += 1 }

                case .sudoCommand(let command):
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    deleteLog.append("クリップボードにコピー: \(item.name) → ターミナルで貼り付けて実行してください")
                    successCount += 1
                }
            }

            deleteLog.append("--- 完了: \(successCount)件成功, \(failCount)件失敗 ---")

            // Re-scan without clearing deleteLog
            await scan()
            isDeleting = false
        }
    }

    func cancelDeletion() {
        deletionTask?.cancel()
        deletionTask = nil
    }

    func toggleItem(_ id: UUID) {
        guard let idx = result.items.firstIndex(where: { $0.id == id }) else { return }
        result.items[idx].isSelected.toggle()
    }

    func selectAll(in category: StorageCategory) {
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = true
        }
    }

    func deselectAll(in category: StorageCategory) {
        for i in result.items.indices where result.items[i].category == category {
            result.items[i].isSelected = false
        }
    }

    // MARK: - Private

    /// Perform file deletion off the main thread to avoid UI freezes on large directories.
    private nonisolated static func performFileDeletion(_ item: StorageItem, useTrash: Bool) -> (Bool, String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: item.path) else {
            return (false, "スキップ: \(item.name)（パスが存在しない）")
        }

        do {
            if useTrash {
                try fm.trashItem(at: URL(filePath: item.path), resultingItemURL: nil)
                return (true, "ゴミ箱に移動: \(item.name) (\(item.formattedSize))")
            } else {
                try fm.removeItem(atPath: item.path)
                return (true, "削除完了: \(item.name) (\(item.formattedSize))")
            }
        } catch {
            return (false, "削除失敗: \(item.name) - \(error.localizedDescription)")
        }
    }

    /// Parse docker prune output to verify actual reclamation.
    private nonisolated static func performDockerPrune(shell: ShellExecuting, itemName: String) -> (Bool, String) {
        guard let output = shell.run(["docker", "system", "prune", "-a", "--volumes", "-f"]) else {
            return (false, "削除失敗: \(itemName) - Docker pruneに失敗（Dockerが起動しているか確認してください）")
        }

        // docker system prune output ends with "Total reclaimed space: X.XXGB"
        let lines = output.split(separator: "\n")
        if let reclaimedLine = lines.last(where: { $0.contains("reclaimed space") }) {
            let reclaimed = reclaimedLine.trimmingCharacters(in: .whitespaces)
            if reclaimed.hasSuffix("0B") {
                return (false, "スキップ: \(itemName) - 回収可能な領域なし（使用中のリソースは削除できません）")
            }
            return (true, "削除完了: \(itemName) (\(reclaimed))")
        }

        return (true, "削除完了: \(itemName) (docker system prune 実行)")
    }
}
