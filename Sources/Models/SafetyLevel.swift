import SwiftUI

enum SafetyLevel: String, Sendable {
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

    var color: Color {
        switch self {
        case .safe: .green
        case .caution: .yellow
        case .dangerous: .red
        }
    }
}
