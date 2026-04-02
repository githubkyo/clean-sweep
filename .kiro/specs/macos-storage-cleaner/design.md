# 技術設計書

## アーキテクチャ概要

SwiftUI + Observation フレームワークによるmacOSネイティブアプリ。MVVM風のレイヤー構成で、Scanner層がファイルシステム操作を担当し、View層がUI表示を担当する。

```
┌─────────────────────────────────────┐
│            Views (SwiftUI)          │
│  ContentView / CategorySection /    │
│  ScanButton / DeleteConfirmDialog   │
├─────────────────────────────────────┤
│         StorageScanner (@Observable)│
│  scan() / deleteSelected() /        │
│  toggleItem() / selectAll()         │
├─────────────────────────────────────┤
│        CategoryScanner (Protocol)   │
│  DockerScanner / XcodeScanner /     │
│  NodeScanner / ... (9 scanners)     │
├─────────────────────────────────────┤
│        Utilities                    │
│  ShellExecutor / SizeFormatter      │
└─────────────────────────────────────┘
```

## コンポーネント設計

### 1. Models

#### StorageCategory (enum)
- 9つのケース: docker, xcode, nodePackages, flutter, gradle, aiTools, systemCaches, apfsSnapshots, tmpFiles
- プロパティ: `icon: String`, `displayName: String`
- REQ-3 対応

#### SafetyLevel (enum)
- 3つのケース: safe, caution, dangerous
- プロパティ: `displayName: String`, `color: Color`, `description: String`
- REQ-2 対応

#### StorageItem (struct, Identifiable)
- プロパティ: `id: UUID`, `name: String`, `path: String`, `size: Int64`, `category: StorageCategory`, `safety: SafetyLevel`, `detail: String`, `isSelected: Bool`
- 計算プロパティ: `formattedSize: String` (REQ-7)

#### ScanResult (struct)
- プロパティ: `items: [StorageItem]`
- 計算プロパティ: `totalReclaimable: Int64`, `selectedSize: Int64`, `byCategory: [(category, items, totalSize)]` (REQ-10)
- `byCategory`はサイズ降順ソート (REQ-3)

### 2. Scanner層

#### CategoryScannerProtocol (protocol)
```swift
protocol CategoryScanner: Sendable {
    var category: StorageCategory { get }
    func scan() async -> [StorageItem]
}
```

各カテゴリに対応する9つのScanner実装:
- `DockerScanner`: `docker system df`コマンドで回収可能サイズを取得 (REQ-1)
- `XcodeScanner`: DerivedData/Archives/DeviceSupport/CoreSimulatorの各ディレクトリサイズ
- `NodeScanner`: npm/yarn/pnpmキャッシュ + workspace配下のnode_modules検出
- `FlutterScanner`: pub-cache/CocoaPodsキャッシュ
- `GradleScanner`: .gradleディレクトリ
- `AIToolsScanner`: /private/tmp/claude-*, Claude Desktop, Cursorデータ
- `SystemCacheScanner`: Chrome/Homebrew/VS Code/pipキャッシュ
- `TmpFileScanner`: /private/tmp配下の100MB以上エントリ
- `APFSSnapshotScanner`: `diskutil apfs listSnapshots`で列挙（サイズは取得不可、0として記録）

#### ShellExecutor (struct)
```swift
struct ShellExecutor: Sendable {
    static func run(_ args: String...) -> String?
    static func directorySize(_ path: String) -> Int64?
}
```
- `Process`を使用してシェルコマンド実行
- `du -sk`でディレクトリサイズ取得 (NFR-4)
- エラー時はnilを返却 (NFR-5)

#### StorageScanner (@Observable, @MainActor)
- プロパティ: `result: ScanResult`, `isScanning: Bool`, `scanProgress: String`, `isDeleting: Bool`, `deleteLog: [String]`
- `scan()`: 9つのCategoryScannerを順次実行、完了後にSafe項目を自動選択 (REQ-1, REQ-5, REQ-8)
- `deleteSelected()`: 選択項目を`FileManager.removeItem`で削除、ログ記録後に再スキャン (REQ-4)
- `toggleItem(_:)`, `selectAll(in:)`, `deselectAll(in:)` (REQ-6)

### 3. View層

#### ContentView
- メインレイアウト: ヘッダー + スクロール可能なカテゴリリスト
- ヘッダー: 合計回収可能サイズ、選択中サイズ、スキャン/削除ボタン (REQ-10)
- スキャン中: プログレステキスト + ProgressView (REQ-8)
- `@Environment(StorageScanner.self)` でスキャナーを取得

#### HeaderView
- 合計サイズ表示 (REQ-10)
- 選択サイズ表示（リアルタイム更新）
- スキャンボタン（スキャン中はdisabled）
- 削除ボタン（選択なし時はdisabled、押下で確認ダイアログ表示）(REQ-9)

#### CategorySectionView
- カテゴリアイコン + 名前 + 合計サイズ + アイテム数 (REQ-3)
- カテゴリ一括選択チェックボックス (REQ-6)
- DisclosureGroupで展開/折りたたみ

#### StorageItemRow
- 項目名 + サイズ + 安全度バッジ + チェックボックス (REQ-2, REQ-7)
- 安全度に応じた色分け: Safe=green, Caution=yellow, Dangerous=red (NFR-3)
- 詳細説明をサブテキストで表示

#### DeleteConfirmDialog
- 選択項目数と合計サイズを表示 (REQ-9)
- 「危険」レベルの項目がある場合は警告メッセージを追加表示 (NFR-3)
- 「削除」「キャンセル」ボタン

#### DeleteLogView
- 削除結果のログ一覧表示（成功=緑、失敗=赤）(REQ-4)

### 4. App構成

#### CleanSweepApp (@main)
- `WindowGroup` + `windowStyle(.titleBar)`
- `defaultSize(width: 900, height: 640)`
- `StorageScanner`を`@State`で保持し`.environment()`で配布

## データフロー

```
ユーザー操作 → StorageScanner (状態更新) → SwiftUI自動再描画
                    ↓
            CategoryScanner.scan()
                    ↓
            ShellExecutor.run() / FileManager
                    ↓
            [StorageItem] → ScanResult
```

## エラーハンドリング

- **スキャンエラー**: ShellExecutor.run()がnilを返した場合、そのカテゴリをスキップして続行 (NFR-5)
- **削除エラー**: FileManager.removeItemのcatchでエラーメッセージをdeleteLogに記録 (REQ-4)
- **権限エラー**: APFSスナップショット削除はsudo必要のため、コマンド文字列をクリップボードにコピーする機能で対応 (NFR-3)
- **Docker未起動**: `docker system df`失敗時はDockerカテゴリを空で返却

## ファイル構成

```
Sources/
├── CleanSweepApp.swift          # @main App
├── Models/
│   ├── StorageCategory.swift    # カテゴリenum
│   ├── SafetyLevel.swift        # 安全度enum
│   ├── StorageItem.swift        # アイテムstruct
│   └── ScanResult.swift         # スキャン結果struct
├── Scanner/
│   ├── CategoryScanner.swift    # Protocol + ShellExecutor
│   ├── StorageScanner.swift     # メインスキャナー (@Observable)
│   ├── DockerScanner.swift
│   ├── XcodeScanner.swift
│   ├── NodeScanner.swift
│   ├── FlutterScanner.swift
│   ├── GradleScanner.swift
│   ├── AIToolsScanner.swift
│   ├── SystemCacheScanner.swift
│   ├── TmpFileScanner.swift
│   └── APFSSnapshotScanner.swift
└── Views/
    ├── ContentView.swift
    ├── HeaderView.swift
    ├── CategorySectionView.swift
    ├── StorageItemRow.swift
    ├── DeleteConfirmDialog.swift
    └── DeleteLogView.swift
```
