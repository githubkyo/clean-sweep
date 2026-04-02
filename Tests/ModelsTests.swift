import Testing
@testable import CleanSweep

@Suite("Models Tests")
struct ModelsTests {

    // CE-001
    @Test("StorageCategoryは9カテゴリ")
    func storageCategoryCount() {
        #expect(StorageCategory.allCases.count == 9)
    }

    // CE-002
    @Test("SafetyLevelは3レベル")
    func safetyLevelCases() {
        #expect(SafetyLevel.safe.rawValue == "安全")
        #expect(SafetyLevel.caution.rawValue == "注意")
        #expect(SafetyLevel.dangerous.rawValue == "危険")
    }

    // CE-003
    @Test("StorageItem.formattedSizeが正しく変換される")
    func formattedSize() {
        let item = StorageItem(name: "test", path: "/test", size: 1_000_000_000, category: .docker, safety: .safe, detail: "")
        #expect(item.formattedSize.contains("GB") || item.formattedSize.contains("MB"))
    }

    @Test("StorageItem.formattedSize 0バイト")
    func formattedSizeZero() {
        let item = StorageItem(name: "test", path: "/test", size: 0, category: .docker, safety: .safe, detail: "")
        #expect(item.formattedSize == "Zero KB" || item.formattedSize.contains("0"))
    }

    // CE-004
    @Test("ScanResult.byCategoryがサイズ降順")
    func byCategorySortedDescending() {
        let result = ScanResult(items: [
            StorageItem(name: "small", path: "/s", size: 100, category: .flutter, safety: .safe, detail: ""),
            StorageItem(name: "large", path: "/l", size: 10000, category: .docker, safety: .safe, detail: ""),
            StorageItem(name: "medium", path: "/m", size: 5000, category: .xcode, safety: .safe, detail: ""),
        ])
        let categories = result.byCategory
        #expect(categories.count == 3)
        #expect(categories[0].category == .docker)
        #expect(categories[1].category == .xcode)
        #expect(categories[2].category == .flutter)
    }

    @Test("ScanResult.byCategoryは空カテゴリを除外")
    func byCategoryExcludesEmpty() {
        let result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: ""),
        ])
        #expect(result.byCategory.count == 1)
        #expect(result.byCategory[0].category == .docker)
    }

    @Test("ScanResult.byCategory同一カテゴリの合算")
    func byCategoryAggregates() {
        let result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: ""),
            StorageItem(name: "b", path: "/b", size: 200, category: .docker, safety: .caution, detail: ""),
        ])
        #expect(result.byCategory.count == 1)
        #expect(result.byCategory[0].totalSize == 300)
        #expect(result.byCategory[0].items.count == 2)
    }

    // CE-005
    @Test("totalReclaimableが全項目合計")
    func totalReclaimable() {
        let result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: ""),
            StorageItem(name: "b", path: "/b", size: 200, category: .xcode, safety: .safe, detail: ""),
        ])
        #expect(result.totalReclaimable == 300)
    }

    @Test("空のScanResult")
    func emptyResult() {
        let result = ScanResult()
        #expect(result.totalReclaimable == 0)
        #expect(result.selectedSize == 0)
        #expect(result.byCategory.isEmpty)
    }

    // CE-006
    @Test("selectedSizeが選択項目のみ合計")
    func selectedSize() {
        let result = ScanResult(items: [
            StorageItem(name: "a", path: "/a", size: 100, category: .docker, safety: .safe, detail: "", isSelected: true),
            StorageItem(name: "b", path: "/b", size: 200, category: .xcode, safety: .safe, detail: "", isSelected: false),
            StorageItem(name: "c", path: "/c", size: 300, category: .flutter, safety: .safe, detail: "", isSelected: true),
        ])
        #expect(result.selectedSize == 400)
    }

    @Test("全カテゴリにアイコンがある")
    func allCategoriesHaveIcons() {
        for cat in StorageCategory.allCases {
            #expect(!cat.icon.isEmpty)
        }
    }

    @Test("全安全度レベルに説明がある")
    func allSafetyLevelsHaveDescriptions() {
        for level in [SafetyLevel.safe, .caution, .dangerous] {
            #expect(!level.description.isEmpty)
        }
    }

    @Test("DeletionMethodのデフォルトはfileRemoval")
    func defaultDeletionMethod() {
        let item = StorageItem(name: "t", path: "/t", size: 0, category: .docker, safety: .safe, detail: "")
        if case .fileRemoval = item.deletionMethod {
            // OK
        } else {
            #expect(Bool(false), "Expected .fileRemoval")
        }
    }

    @Test("DeletionMethod dockerPrune")
    func dockerPruneDeletionMethod() {
        let item = StorageItem(name: "t", path: "/t", size: 0, category: .docker, safety: .safe, detail: "", deletionMethod: .dockerPrune)
        if case .dockerPrune = item.deletionMethod {
            // OK
        } else {
            #expect(Bool(false), "Expected .dockerPrune")
        }
    }

    @Test("DeletionMethod sudoCommand stores command")
    func sudoCommandDeletionMethod() {
        let cmd = "sudo tmutil deletelocalsnapshots test"
        let item = StorageItem(name: "t", path: "/t", size: 0, category: .apfsSnapshots, safety: .caution, detail: "", deletionMethod: .sudoCommand(cmd))
        if case .sudoCommand(let stored) = item.deletionMethod {
            #expect(stored == cmd)
        } else {
            #expect(Bool(false), "Expected .sudoCommand")
        }
    }
}
