# KOT Assistant (macOS)

KING OF TIME「Myレコーダー」用のメニューバー常駐アプリ。XcodeGen + ローカル SwiftPM パッケージ構成。

## ビルド・テスト

```bash
# 初回および project.yml 変更時（xcodegen がなければ brew install xcodegen）
xcodegen generate

# アプリのビルド（エラーはこの出力を直接読むこと。ユーザーにコピペさせない）
xcodebuild -project KOTAssistant.xcodeproj -scheme KOTAssistant \
  -destination 'platform=macOS' build 2>&1 | xcbeautify
# xcbeautify がなければパイプなしで実行

# コアロジックのテスト（高速。ロジック変更時はまずこれ）
swift test --package-path Packages/KOTCore
```

## 構成と方針

- `Packages/KOTCore/` — 純 Swift パッケージ（Linux でもテスト可能）
  - `KOTCore`: 打刻状態エンジン・設定モデル・SetupConfig・PKCE
  - `KOTNotifications`: Slack/Google Chat クライアント・OAuth トークン管理・通知ディスパッチャ
- `KOTAssistant/` — アプリ本体（SwiftUI / WKWebView / App Intents）。ロジックは極力 KOTCore 側へ置く
- `*.xcodeproj`、`KOTAssistant/Info.plist`、`*.entitlements` は **XcodeGen の生成物**。直接編集せず `project.yml` を変更して `xcodegen generate`
- トークン・シークレットは Keychain（`SecretStore`）。UserDefaults に置かない
- 通知は fire-and-forget（失敗はログのみ）。打刻検知の通知経路は `kot_bridge.js` の kotPunch 一本
- UserDefaults のキー名は旧 Chrome 拡張のキーを踏襲（対応表は README）

## 検証

- ロジック変更 → `swift test --package-path Packages/KOTCore` が通ること
- アプリ変更 → xcodebuild が通ること。動作確認は README 末尾のスモークテスト表
