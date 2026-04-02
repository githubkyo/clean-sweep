import Foundation

enum DeletionMethod: Sendable {
    case fileRemoval          // FileManager.removeItem
    case dockerPrune          // docker system prune -f
    case sudoCommand(String)  // Copy command to clipboard
}

struct StorageItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: StorageCategory
    let safety: SafetyLevel
    let detail: String
    var isSelected: Bool = false
    let deletionMethod: DeletionMethod

    init(
        name: String, path: String, size: Int64,
        category: StorageCategory, safety: SafetyLevel, detail: String,
        isSelected: Bool = false,
        deletionMethod: DeletionMethod = .fileRemoval
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.safety = safety
        self.detail = detail
        self.isSelected = isSelected
        self.deletionMethod = deletionMethod
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
