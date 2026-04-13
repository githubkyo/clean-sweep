import SwiftUI

struct CategorySectionView: View {
    let category: StorageCategory
    let items: [StorageItem]
    let totalSize: Int64
    @Environment(StorageScanner.self) private var scanner
    @State private var isExpanded = true

    private var allSelected: Bool {
        items.allSatisfy(\.isSelected)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(items) { item in
                StorageItemRow(item: item)
            }
        } label: {
            HStack(spacing: 8) {
                Button {
                    if allSelected {
                        scanner.deselectAll(in: category)
                    } else {
                        scanner.selectAll(in: category)
                    }
                } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square")
                        .foregroundStyle(allSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: category.icon)
                    .frame(width: 20)
                    .foregroundStyle(.blue)

                Text(category.localizedName)
                    .font(.headline)

                Text(L("category.items.count", items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}
