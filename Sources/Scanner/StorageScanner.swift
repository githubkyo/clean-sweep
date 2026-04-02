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
        deleteLog = []
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

    func deleteSelected() async {
        isDeleting = true
        deleteLog = []
        let selected = result.items.filter(\.isSelected)
        var successCount = 0
        var failCount = 0

        for item in selected {
            // Check for cancellation
            if Task.isCancelled {
                deleteLog.append("中断: 残り\(selected.count - successCount - failCount)件をスキップ")
                break
            }

            switch item.deletionMethod {
            case .fileRemoval:
                let (success, message) = await deleteFile(item)
                deleteLog.append(message)
                if success { successCount += 1 } else { failCount += 1 }

            case .dockerPrune:
                let pruneResult = await Task.detached { [shell = self.shell] in
                    shell.run(["docker", "system", "prune", "-a", "--volumes", "-f"])
                }.value
                if pruneResult != nil {
                    deleteLog.append("削除完了: \(item.name) (docker system prune 実行)")
                    successCount += 1
                } else {
                    deleteLog.append("削除失敗: \(item.name) - Docker pruneに失敗")
                    failCount += 1
                }

            case .sudoCommand(let command):
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                deleteLog.append("クリップボードにコピー: \(item.name) → ターミナルで貼り付けて実行してください")
                successCount += 1
            }
        }

        deleteLog.append("--- 完了: \(successCount)件成功, \(failCount)件失敗 ---")

        await scan()
        isDeleting = false
    }

    func cancelDeletion() {
        deletionTask?.cancel()
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

    private func deleteFile(_ item: StorageItem) async -> (Bool, String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: item.path) else {
            return (false, "スキップ: \(item.name)（パスが存在しない）")
        }

        do {
            if useTrash {
                // Move to Trash — user can recover from Finder
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
}
