import Foundation

struct ScanResult: Sendable {
    var items: [StorageItem] = []

    var totalReclaimable: Int64 {
        items.reduce(0) { $0 + $1.size }
    }

    var selectedSize: Int64 {
        items.filter(\.isSelected).reduce(0) { $0 + $1.size }
    }

    var byCategory: [(category: StorageCategory, items: [StorageItem], totalSize: Int64)] {
        StorageCategory.allCases.compactMap { cat in
            let catItems = items.filter { $0.category == cat }
            guard !catItems.isEmpty else { return nil }
            let total = catItems.reduce(Int64(0)) { $0 + $1.size }
            return (cat, catItems, total)
        }
        .sorted { $0.totalSize > $1.totalSize }
    }

    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalReclaimable, countStyle: .file)
    }

    var formattedSelected: String {
        ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file)
    }
}
