import SwiftUI

enum SafetyLevel: String, Sendable {
    case safe
    case caution
    case dangerous

    var localizedName: String {
        L("safety.\(rawValue)")
    }

    var localizedDescription: String {
        L("safety.\(rawValue).description")
    }

    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .yellow
        case .dangerous: .red
        }
    }
}
