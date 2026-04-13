# CleanSweep

日本語 | [English](README.md)

macOS開発者向けストレージクリーナー。Docker/Xcode/npm/Gradle/AIツール等の隠れた巨大ファイルを検出し、安全に削除できるネイティブアプリ。

## 特徴

- **開発者ツール特化** — Docker、Xcode DerivedData、npm/yarn/pnpmキャッシュ、Gradle、Flutter、CocoaPods
- **AIツール対応** — Claude Code一時ファイル、Claude Desktop、Cursorデータ
- **システム深層スキャン** — APFSスナップショット、/private/tmp、システムキャッシュ
- **安全度スコア** — 安全/注意/危険の3段階で色分け表示
- **ゴミ箱移動** — デフォルトでゴミ箱に移動（Finderから復元可能）
- **sudo対応** — APFSスナップショット等はコマンドをクリップボードにコピー
- **多言語対応** — 日本語・英語

## 必要環境

- macOS 14 (Sonoma) 以上
- Swift 6.2+ / Xcode 16+
- フルディスクアクセス権限（推奨）

## インストール

### Homebrew（予定）
```bash
brew install --cask cleansweep
```

### DMGダウンロード
[Releases](../../releases) ページから最新の `.dmg` をダウンロード

### ソースからビルド
```bash
git clone https://github.com/your-username/clean-sweep.git
cd clean-sweep
make run
```

## 使い方

1. CleanSweepを起動
2. フルディスクアクセスを設定（初回のみ — アプリ内ガイドあり）
3. 「スキャン」ボタンを押す
4. 安全な項目は自動選択される
5. 確認して「ゴミ箱へ」を押す

## ビルド

```bash
make build    # リリースビルド
make test     # テスト実行
make app      # .appバンドル作成
make sign     # ad-hoc署名
make dmg      # DMG作成
make run      # ビルド＆起動
```

## スキャン対象

| カテゴリ | 対象 | デフォルト安全度 |
|---------|------|----------------|
| Docker | 未使用イメージ/ボリューム/ビルドキャッシュ | 安全 |
| Xcode | DerivedData, Archives, DeviceSupport, Simulator | 安全〜注意 |
| Node.js | npm/yarn/pnpmキャッシュ, node_modules | 安全 |
| Flutter | pub-cache, CocoaPods | 安全 |
| Gradle | .gradleキャッシュ | 安全 |
| AIツール | Claude Code一時ファイル, Claude Desktop | 安全〜注意 |
| システムキャッシュ | Chrome, Homebrew, VS Code, pip | 安全 |
| 一時ファイル | /private/tmp (100MB以上) | 注意 |
| APFSスナップショット | OS更新用スナップショット | 注意 |

## ライセンス

MIT License
