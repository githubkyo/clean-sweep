import SwiftUI

enum StorageCategory: String, CaseIterable, Identifiable, Sendable {
    case docker
    case xcode
    case nodePackages = "node"
    case flutter
    case gradle
    case aiTools
    case systemCaches
    case apfsSnapshots
    case tmpFiles

    var id: String { rawValue }

    var localizedName: String {
        L("category.\(rawValue)")
    }

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
