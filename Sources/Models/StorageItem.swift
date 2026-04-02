import Foundation

enum StorageCategory: String, CaseIterable, Identifiable {
    case docker = "Docker"
    case xcode = "Xcode"
    case nodePackages = "Node.js"
    case flutter = "Flutter"
    case gradle = "Gradle"
    case aiTools = "AIツール"
    case systemCaches = "システムキャッシュ"
    case apfsSnapshots = "APFSスナップショット"
    case tmpFiles = "一時ファイル"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .docker: "shippingbox"
        case .xcode: "hammer"
        case .nodePackages: "cube"
        case .flutter: "bird"
        case .gradle: "gearshape.2"
        case .aiTools: "brain"
        case .systemCaches: "archivebox"
        case .apfsSnapshots: "camera.on.rectangle"
        case .tmpFiles: "trash"
        }
    }

    var color: String {
        switch self {
        case .docker: "blue"
        case .xcode: "cyan"
        case .nodePackages: "green"
        case .flutter: "indigo"
        case .gradle: "orange"
        case .aiTools: "purple"
        case .systemCaches: "yellow"
        case .apfsSnapshots: "red"
        case .tmpFiles: "gray"
        }
    }
}

enum SafetyLevel: String {
    case safe = "安全"
    case caution = "注意"
    case dangerous = "危険"

    var description: String {
        switch self {
        case .safe: "削除しても再生成される"
        case .caution: "削除前に確認推奨"
        case .dangerous: "削除するとデータ損失の可能性"
        }
    }
}

struct StorageItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: StorageCategory
    let safety: SafetyLevel
    let detail: String
    var isSelected: Bool = false

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
