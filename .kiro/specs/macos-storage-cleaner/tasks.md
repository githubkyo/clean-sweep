# 実装タスク

## Task 1: Models層の実装 (P) ✅
_Requirements: REQ-2, REQ-3, REQ-7_

- [x] 1.1: `StorageCategory` enumを実装（9カテゴリ、icon/displayNameプロパティ）
- [x] 1.2: `SafetyLevel` enumを実装（3レベル、color/descriptionプロパティ）
- [x] 1.3: `StorageItem` structを実装（Identifiable、formattedSize計算プロパティ）
- [x] 1.4: `ScanResult` structを実装（totalReclaimable/selectedSize/byCategory計算プロパティ）
- [x] 1.5: Modelsのユニットテストを作成

---

## Task 2: ShellExecutor と CategoryScanner Protocol (P) ✅
_Requirements: REQ-1, NFR-4, NFR-5_

- [x] 2.1: `ShellExecutor` structを実装（run/directorySize）
- [x] 2.2: `CategoryScanner` protocolを定義
- [x] 2.3: ShellExecutorのテスト（コマンド実行、エラーハンドリング）

---

## Task 3: Docker/Xcode Scanner実装 ✅
_Requirements: REQ-1_

- [x] 3.1: `DockerScanner`を実装（docker system df解析、サイズパース）
- [x] 3.2: `XcodeScanner`を実装（4ディレクトリのサイズ取得）
- [x] 3.3: Dockerサイズパース関数のテスト
- [x] 3.4: スキャン結果の安全度レベル割り当てテスト

---

## Task 4: Node/Flutter/Gradle Scanner実装 (P) ✅
_Requirements: REQ-1_

- [x] 4.1: `NodeScanner`を実装（npm/yarn/pnpmキャッシュ + node_modules検出）
- [x] 4.2: `FlutterScanner`を実装（pub-cache/CocoaPods）
- [x] 4.3: `GradleScanner`を実装（.gradle）
- [x] 4.4: node_modules検出ロジックのテスト

---

## Task 5: AITools/SystemCache/Tmp/APFS Scanner実装 (P) ✅
_Requirements: REQ-1_

- [x] 5.1: `AIToolsScanner`を実装（Claude Code一時ファイル、Claude Desktop）
- [x] 5.2: `SystemCacheScanner`を実装（Chrome/Homebrew/VS Code/pip）
- [x] 5.3: `TmpFileScanner`を実装（/private/tmp配下100MB以上）
- [x] 5.4: `APFSSnapshotScanner`を実装（diskutil出力解析）
- [x] 5.5: APFS snapshot解析のテスト

---

## Task 6: StorageScanner統合 ✅
_Requirements: REQ-1, REQ-4, REQ-5, REQ-6, REQ-8_

- [x] 6.1: `StorageScanner`を実装（@Observable、全スキャナー統合）
- [x] 6.2: scan()メソッド実装（順次実行、プログレス更新、自動選択）
- [x] 6.3: deleteSelected()メソッド実装（FileManager削除、ログ記録）
- [x] 6.4: toggleItem/selectAll/deselectAllメソッド実装
- [x] 6.5: 統合テスト（スキャン→選択→削除フロー）

---

## Task 7: View層 - HeaderとContentView ✅
_Requirements: REQ-8, REQ-10_

- [x] 7.1: `HeaderView`を実装（合計サイズ、選択サイズ、スキャン/削除ボタン）
- [x] 7.2: `ContentView`を実装（ヘッダー + カテゴリリスト + 進捗表示）
- [x] 7.3: `CleanSweepApp`を更新（Environment設定）

---

## Task 8: View層 - カテゴリとアイテム表示 ✅
_Requirements: REQ-2, REQ-3, REQ-6, REQ-7_

- [x] 8.1: `StorageItemRow`を実装（名前、サイズ、安全度バッジ、チェックボックス）
- [x] 8.2: `CategorySectionView`を実装（DisclosureGroup、一括選択、合計サイズ）

---

## Task 9: View層 - 削除確認とログ ✅
_Requirements: REQ-4, REQ-9, NFR-3_

- [x] 9.1: `DeleteConfirmDialog`をHeaderViewに統合（confirmationDialog）
- [x] 9.2: `DeleteLogView`を実装（成功/失敗の色分けログ）
- [x] 9.3: HeaderViewに確認ダイアログ連携を追加

---

## Task 10: 統合テストとビルド確認 ✅

- [x] 10.1: `swift build`でビルド成功を確認
- [x] 10.2: `swift test`で全テスト通過を確認（23/23）
- [x] 10.3: セキュリティレビュー完了
