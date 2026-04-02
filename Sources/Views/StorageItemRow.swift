import SwiftUI

struct StorageItemRow: View {
    let item: StorageItem
    @Environment(StorageScanner.self) private var scanner

    var body: some View {
        HStack(spacing: 8) {
            Button {
                scanner.toggleItem(item.id)
            } label: {
                Image(systemName: item.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(item.isSelected ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.name)
                        .font(.body)
                    if case .sudoCommand = item.deletionMethod {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("sudo権限が必要 — 削除時にコマンドをクリップボードにコピー")
                    } else if case .dockerPrune = item.deletionMethod {
                        Image(systemName: "terminal")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .help("docker system prune を実行")
                    }
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.safety.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(item.safety.color.opacity(0.2), in: Capsule())
                .foregroundStyle(item.safety.color)

            if item.size > 0 {
                Text(item.formattedSize)
                    .font(.body.monospacedDigit())
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("不明")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .padding(.leading, 28)
    }
}
