import SwiftUI

enum StorageCategory: String, CaseIterable, Identifiable, Sendable {
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
}
