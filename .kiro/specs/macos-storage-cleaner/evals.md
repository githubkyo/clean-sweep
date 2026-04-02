# EVAL DEFINITION: macos-storage-cleaner

## Capability Evals

| ID | Description | Grader | Priority |
|----|-------------|--------|----------|
| CE-001 | StorageCategory.allCases.countが9であること | code | P0 |
| CE-002 | SafetyLevelの3レベル(safe/caution/dangerous)が定義されていること | code | P0 |
| CE-003 | StorageItem.formattedSizeが正しい単位変換を行うこと（1GB=1,000,000,000B） | code | P0 |
| CE-004 | ScanResult.byCategoryがサイズ降順でソートされること | code | P0 |
| CE-005 | ScanResult.totalReclaimableが全項目のサイズ合計を返すこと | code | P0 |
| CE-006 | ScanResult.selectedSizeがisSelected=trueの項目のみ合計すること | code | P0 |
| CE-007 | DockerScanner: "42.97GB (62%)"を正しくバイト数にパースすること | code | P0 |
| CE-008 | DockerScanner: "21.13GB"(括弧なし)を正しくパースすること | code | P1 |
| CE-009 | APFSSnapshotScanner: diskutil出力からスナップショット名を抽出すること | code | P1 |
| CE-010 | ShellExecutor: 存在するディレクトリのサイズを正の値で返すこと | code | P0 |
| CE-011 | ShellExecutor: 存在しないパスに対してnilを返すこと | code | P0 |
| CE-012 | StorageScanner: scan後にSafe項目のみisSelected=trueであること | code | P0 |
| CE-013 | StorageScanner: toggleItemで選択状態が反転すること | code | P0 |
| CE-014 | StorageScanner: selectAll(in:)で指定カテゴリの全項目が選択されること | code | P0 |
| CE-015 | swift buildがエラーなしで成功すること | build | P0 |
| CE-016 | swift testが全テストパスすること | test | P0 |

## Regression Evals

| ID | Description | Baseline |
|----|-------------|----------|
| RE-001 | Package.swiftが有効でmacOS 14+ターゲットであること | current |
| RE-002 | CleanSweepApp.swiftが@mainエントリポイントを持つこと | current |

## Success Metrics
- pass@3 (Capability): >= 90%
- pass^3 (Regression): 100%
