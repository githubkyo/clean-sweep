import SwiftUI

struct DeleteLogView: View {
    @Environment(StorageScanner.self) private var scanner

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(scanner.deleteLog.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 4) {
                        Image(systemName: iconName(for: entry.kind))
                            .foregroundStyle(iconColor(for: entry.kind))
                            .font(.caption)
                        Text(entry.message)
                            .font(.caption.monospaced())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 120)
    }

    private func iconName(for kind: DeleteLogEntry.Kind) -> String {
        switch kind {
        case .success, .trash: "checkmark.circle.fill"
        case .clipboard: "doc.on.clipboard.fill"
        case .skipped: "arrow.right.circle.fill"
        case .error, .summary: "exclamationmark.triangle.fill"
        }
    }

    private func iconColor(for kind: DeleteLogEntry.Kind) -> Color {
        switch kind {
        case .success, .trash: .green
        case .clipboard: .orange
        case .skipped: .secondary
        case .error, .summary: .red
        }
    }
}
