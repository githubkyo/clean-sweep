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
    var deleteLog: [DeleteLogEntry] = []
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
            scanProgress = L("scanner.scanning", scanner.category.localizedName)
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
                    deleteLog.append(DeleteLogEntry(
                        kind: .skipped,
                        message: L("scanner.cancelled", selected.count - successCount - failCount)
                    ))
                    break
                }

                switch item.deletionMethod {
                case .fileRemoval:
                    let trash = useTrash
                    let (success, entry) = await Task.detached {
                        Self.performFileDeletion(item, useTrash: trash)
                    }.value
                    deleteLog.append(entry)
                    if success { successCount += 1 } else { failCount += 1 }

                case .dockerPrune:
                    if dockerPruneExecuted {
                        // prune is global — only run once per deletion batch
                        deleteLog.append(DeleteLogEntry(
                            kind: .skipped,
                            message: L("scanner.skipped.pruned", item.name)
                        ))
                        successCount += 1
                        continue
                    }
                    dockerPruneExecuted = true
                    let dockerItems = selected.filter { $0.deletionMethod == .dockerPrune }
                    let names = dockerItems.map(\.name).joined(separator: ", ")
                    let (pruneSuccess, pruneEntry) = await Task.detached { [shell = self.shell] in
                        Self.performDockerPrune(shell: shell, itemName: names)
                    }.value
                    deleteLog.append(pruneEntry)
                    if pruneSuccess { successCount += 1 } else { failCount += 1 }

                case .sudoCommand(let command):
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    deleteLog.append(DeleteLogEntry(
                        kind: .clipboard,
                        message: L("scanner.clipboard", item.name)
                    ))
                    successCount += 1
                }
            }

            deleteLog.append(DeleteLogEntry(
                kind: .summary,
                message: L("scanner.summary", successCount, failCount)
            ))

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
    private nonisolated static func performFileDeletion(_ item: StorageItem, useTrash: Bool) -> (Bool, DeleteLogEntry) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: item.path) else {
            return (false, DeleteLogEntry(kind: .skipped, message: L("scanner.path.missing", item.name)))
        }

        do {
            if useTrash {
                try fm.trashItem(at: URL(filePath: item.path), resultingItemURL: nil)
                return (true, DeleteLogEntry(kind: .trash, message: L("scanner.trash.success", item.name, item.formattedSize)))
            } else {
                try fm.removeItem(atPath: item.path)
                return (true, DeleteLogEntry(kind: .success, message: L("scanner.delete.success", item.name, item.formattedSize)))
            }
        } catch {
            return (false, DeleteLogEntry(kind: .error, message: L("scanner.delete.failure", item.name, error.localizedDescription)))
        }
    }

    /// Parse docker prune output to verify actual reclamation.
    private nonisolated static func performDockerPrune(shell: ShellExecuting, itemName: String) -> (Bool, DeleteLogEntry) {
        guard let output = shell.run(["docker", "system", "prune", "-a", "--volumes", "-f"]) else {
            return (false, DeleteLogEntry(kind: .error, message: L("scanner.docker.failure", itemName)))
        }

        // docker system prune output ends with "Total reclaimed space: X.XXGB"
        let lines = output.split(separator: "\n")
        if let reclaimedLine = lines.last(where: { $0.contains("reclaimed space") }) {
            let reclaimed = reclaimedLine.trimmingCharacters(in: .whitespaces)
            if reclaimed.hasSuffix("0B") {
                return (false, DeleteLogEntry(kind: .skipped, message: L("scanner.docker.nospace", itemName)))
            }
            return (true, DeleteLogEntry(kind: .success, message: L("scanner.docker.success.detail", itemName, reclaimed)))
        }

        return (true, DeleteLogEntry(kind: .success, message: L("scanner.docker.success", itemName)))
    }
}
