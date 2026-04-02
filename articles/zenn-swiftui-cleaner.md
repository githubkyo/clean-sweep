---
title: "SwiftUIでmacOSストレージクリーナーアプリを作った話"
emoji: "🧹"
type: "tech"
topics: ["swift", "swiftui", "macos", "xcode"]
published: true
---

## きっかけ：Mac Miniのシステムデータが274GB

ある日、Mac Miniのストレージを確認したら「システムデータ」が274GBになっていた。調べてみると、Claude Codeの一時ファイルが84GB、Dockerが104GBを占めていた。

手動で掃除した後、「毎回これやるのは面倒だな、アプリにしよう」と思い立ち、**CleanSweep**というmacOS向けストレージクリーナーアプリをSwiftUIで開発した。

https://github.com/githubkyo/clean-sweep

この記事では、開発中に得た技術的な知見を共有する。

## アーキテクチャ概要

Swift Package Managerのexecutable targetとして構成し、SwiftUIでUIを構築している。

```
Package.swift          # swift-tools-version: 6.2, macOS 14+
Sources/
  Scanner/
    CategoryScanner.swift   # プロトコル定義 + ShellExecuting DI
    StorageScanner.swift    # @Observable メインスキャナー
    DockerScanner.swift     # 9つのスキャナー実装の1つ
    ...
  Models/
    StorageItem.swift       # 検出項目モデル
    StorageCategory.swift   # 9カテゴリ定義
  Views/
    ContentView.swift
Tests/
  MockShellExecutor.swift   # テスト用モック
  ScannerTests.swift        # 42テスト (Swift Testing)
```

核となる設計は2つ：`CategoryScanner`プロトコルによるスキャナーの抽象化と、`ShellExecuting`プロトコルによるDI。

```swift
protocol CategoryScanner: Sendable {
    var category: StorageCategory { get }
    func scan() async -> [StorageItem]
}

protocol ShellExecuting: Sendable {
    func run(_ args: [String]) -> String?
    func directorySize(_ path: String) -> Int64?
}
```

テストでは`MockShellExecutor`を注入し、実際のコマンド実行なしに全ロジックを検証できる。

## ポイント1：`du -sk`でディレクトリサイズ取得

最初は`FileManager.enumerator`で全ファイルを走査してサイズを合算していたが、巨大ディレクトリ（Docker 100GB超など）で数十秒かかり、メモリ使用量も跳ね上がった。

結局、`Process`経由で`du -sk`を呼ぶのが最適解だった。

```swift
func directorySize(_ path: String) -> Int64? {
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    guard let output = run(["du", "-sk", path]) else { return nil }
    let parts = output.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: "\t")
    guard let kb = Int64(parts.first ?? "") else { return nil }
    return kb * 1024
}
```

`-s`でサマリーのみ、`-k`でKB単位。出力は`12345\t/path/to/dir`の形式なのでタブで分割して先頭をパースするだけ。FileManagerのAPIだけでmacOS開発を完結させたい気持ちはあるが、パフォーマンスの差が圧倒的なので割り切った。

## ポイント2：Docker回収可能サイズのパース

`docker system df --format`の出力から回収可能サイズを取得する。問題は出力形式が`42.97GB (62%)`のように括弧付きパーセンテージが含まれること。

```swift
static func parseDockerSize(_ str: String) -> Int64 {
    // "(62%)" のような括弧部分を正規表現で除去
    let cleaned = str.replacingOccurrences(
        of: #"\s*\(.*\)"#, with: "", options: .regularExpression
    ).trimmingCharacters(in: .whitespaces)

    let multipliers: [(String, Double)] = [
        ("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("kB", 1e3), ("B", 1),
    ]
    for (suffix, mult) in multipliers {
        if cleaned.hasSuffix(suffix),
           let val = Double(cleaned.dropLast(suffix.count)) {
            return Int64(val * mult)
        }
    }
    return 0
}
```

これはテストしやすい純粋関数なので、Swift Testingで各単位・エッジケースを網羅的にテストしている。

## ポイント3：DeletionMethod enumで削除方法を型安全に分岐

クリーナーアプリ特有の課題として、項目ごとに削除方法が異なる。ファイル削除、Docker prune、sudo必要なコマンドの3パターンをenumで型安全に表現した。

```swift
enum DeletionMethod: Sendable {
    case fileRemoval          // FileManager.removeItem / trashItem
    case dockerPrune          // docker system prune -a --volumes -f
    case sudoCommand(String)  // クリップボードにコピー
}
```

削除実行時はswitch文で分岐する。`sudoCommand`の場合はユーザーに実行を委ねる設計にした。サンドボックス外のアプリでもsudo実行は避けたい。

```swift
case .sudoCommand(let command):
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(command, forType: .string)
    deleteLog.append("クリップボードにコピー → ターミナルで実行してください")
```

APFSスナップショットの削除が典型例で、`sudo tmutil deletelocalsnapshots <name>`をクリップボードにコピーする。

## ポイント4：Task.detachedでUIフリーズ防止

`StorageScanner`は`@MainActor`で宣言してUIバインディングを安全にしているが、各スキャナーの`scan()`はI/O待ちが発生する。`Task.detached`でメインスレッド外に逃がす。

```swift
@Observable
@MainActor
final class StorageScanner {
    func scan() async {
        for scanner in scanners {
            scanProgress = "\(scanner.category.rawValue) をスキャン中..."
            let items = await Task.detached { [scanner] in
                await scanner.scan()
            }.value
            result.items.append(contentsOf: items)
        }
    }
}
```

`[scanner]`でキャプチャリストに入れるのがポイント。Swift 6の厳格な並行性チェックでは、`Sendable`でないものをクロージャに暗黙キャプチャするとコンパイルエラーになる。`CategoryScanner`プロトコルに`Sendable`制約を付けているのでこれが成立する。

## ポイント5：Full Disk Access検出

macOSの一部ディレクトリはTCC（Transparency, Consent, and Control）で保護されている。Full Disk Accessがないとスキャンできないパスがある。

検出方法はシンプルで、TCC保護ディレクトリの可読性をチェックする。

```swift
struct PermissionChecker {
    static func hasFullDiskAccess() -> Bool {
        let testPaths = [
            "/Library/Application Support/com.apple.TCC",
            "\(FileManager.default.homeDirectoryForCurrentUser.path())/Library/Safari",
        ]
        return testPaths.contains { FileManager.default.isReadableFile(atPath: $0) }
    }
}
```

正式なAPIは存在しないため、これが事実上の標準的な検出方法になっている。

## ポイント6：ad-hoc署名 + DMG作成

Apple Developer Programに登録していなくても、ad-hoc署名でアプリを配布できる。Makefileに一連のビルドパイプラインをまとめた。

```makefile
sign: app
	codesign --force --deep --sign - \
		--entitlements CleanSweep.entitlements \
		"$(APP_BUNDLE)"

dmg: sign
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(APP_BUNDLE)" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(DMG_NAME)"
```

`make dmg`一発でビルド→.appバンドル作成→署名→DMG生成まで完了する。Gatekeeperの警告は出るが、個人利用・OSS配布なら十分実用的。

## ゴミ箱移動で安全に

デフォルトでは`FileManager.trashItem()`を使いFinderのゴミ箱に移動する。「消しすぎた」場合にゴミ箱から復元できるのは安心感がある。

```swift
try fm.trashItem(at: URL(filePath: item.path), resultingItemURL: nil)
```

永久削除オプションも用意しているが、デフォルトはゴミ箱移動。クリーナーアプリにとって「取り返しがつく」ことは重要な機能だと思う。

## まとめ

- macOSネイティブアプリはSwiftUI + SPMだけで十分作れる
- ディレクトリサイズ取得は`du -sk`をProcess経由で呼ぶのが速くてメモリにも優しい
- Protocol-based DIで外部コマンド依存をモック化し、42テストで品質を担保
- `DeletionMethod` enumで削除方法の違いを型で表現するとswitch漏れがなくなる
- ad-hoc署名なら開発者アカウント不要でDMG配布できる

開発者のMacはキャッシュや一時ファイルが知らないうちに膨らむ。自分の環境に合ったクリーナーを作ってみると、macOSのファイルシステムやセキュリティモデルへの理解が深まるのでおすすめ。
