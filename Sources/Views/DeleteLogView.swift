import SwiftUI

struct DeleteLogView: View {
    @Environment(StorageScanner.self) private var scanner

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(scanner.deleteLog.enumerated()), id: \.offset) { _, log in
                    HStack(spacing: 4) {
                        Image(systemName: iconName(for: log))
                            .foregroundStyle(iconColor(for: log))
                            .font(.caption)
                        Text(log)
                            .font(.caption.monospaced())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 120)
    }

    private func iconName(for log: String) -> String {
        if log.hasPrefix("削除完了") { return "checkmark.circle.fill" }
        if log.hasPrefix("クリップボード") { return "doc.on.clipboard.fill" }
        if log.hasPrefix("スキップ") { return "arrow.right.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    private func iconColor(for log: String) -> Color {
        if log.hasPrefix("削除完了") { return .green }
        if log.hasPrefix("クリップボード") { return .orange }
        if log.hasPrefix("スキップ") { return .secondary }
        return .red
    }
}
