import Testing
@testable import CleanSweep

@Suite("StorageScanner Tests")
struct StorageScannerTests {

    // CE-012
    @Test("Safe項目の自動選択")
    func autoSelectSafeItems() {
        var result = ScanResult(items: [
            StorageItem(name: "safe1", path: "/s1", size: 100, category: .docker, safety: .safe, detail: ""),
            StorageItem(name: "caution1", path: "/c1", size: 200, category: .xcode, safety: .caution, detail: ""),
            StorageItem(name: "dangerous1", path: "/d1", size: 300, category: .aiTools, safety: .dangerous, detail: ""),
            StorageItem(name: "safe2", path: "/s2", size: 400, category: .gradle, safety: .safe, detail: ""),
        ])

        for i in result.items.indices where result.items[i].safety == .safe {
            result.items[i].isSelected = true
        }

        #expect(result.items[0].isSelected == true)
        #expect(result.items[1].isSelected == false)
        #expect(result.items[2].isSelected == false)
        #expect(result.items[3].isSelected == true)
        #expect(result.selectedSize == 500)  // 100 + 400
    }

    // CE-013
    @Test("toggleItemで選択反転")
    func toggleItem() {
        var result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: "", isSelected: false),
        ])
        let id = result.items[0].id

        if let idx = result.items.firstIndex(where: { $0.id == id }) {
            result.items[idx].isSelected.toggle()
        }
        #expect(result.items[0].isSelected == true)

        if let idx = result.items.firstIndex(where: { $0.id == id }) {
            result.items[idx].isSelected.toggle()
        }
        #expect(result.items[0].isSelected == false)
    }

    // CE-014
    @Test("selectAllでカテゴリ全選択")
    func selectAllInCategory() {
        var result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: "", isSelected: false),
            StorageItem(name: "b", path: "/b", size: 200, category: .docker, safety: .caution, detail: "", isSelected: false),
            StorageItem(name: "c", path: "/c", size: 300, category: .xcode, safety: .safe, detail: "", isSelected: false),
        ])

        for i in result.items.indices where result.items[i].category == .docker {
            result.items[i].isSelected = true
        }

        #expect(result.items[0].isSelected == true)
        #expect(result.items[1].isSelected == true)
        #expect(result.items[2].isSelected == false)
    }

    @Test("deselectAllでカテゴリ全解除")
    func deselectAllInCategory() {
        var result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: "", isSelected: true),
            StorageItem(name: "b", path: "/b", size: 200, category: .docker, safety: .caution, detail: "", isSelected: true),
            StorageItem(name: "c", path: "/c", size: 300, category: .xcode, safety: .safe, detail: "", isSelected: true),
        ])

        for i in result.items.indices where result.items[i].category == .docker {
            result.items[i].isSelected = false
        }

        #expect(result.items[0].isSelected == false)
        #expect(result.items[1].isSelected == false)
        #expect(result.items[2].isSelected == true)
    }

    @Test("安全度に応じた選択状態のビジネスロジック")
    func safetyBasedSelection() {
        var result = ScanResult(items: [
            StorageItem(name: "npm cache", path: "/a", size: 1_000_000_000, category: .nodePackages, safety: .safe, detail: ""),
            StorageItem(name: "Xcode Archives", path: "/b", size: 5_000_000_000, category: .xcode, safety: .caution, detail: ""),
            StorageItem(name: "Docker image", path: "/c", size: 20_000_000_000, category: .docker, safety: .dangerous, detail: ""),
        ])

        // Simulate scan() auto-select behavior
        for i in result.items.indices where result.items[i].safety == .safe {
            result.items[i].isSelected = true
        }

        // Only safe items auto-selected, totaling 1GB
        #expect(result.selectedSize == 1_000_000_000)
        // Total reclaimable is 26GB
        #expect(result.totalReclaimable == 26_000_000_000)
    }
}
