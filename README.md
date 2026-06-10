# KOT Assistant for macOS

KING OF TIME「[Myレコーダー](https://kingoftime.jp/record/myrecorder/)」用のメニューバー常駐アプリです。
Chrome 拡張 [kot-chrome-assistant](https://github.com/worldnine/kot-chrome-assistant)（原作: [shoito/kot-chrome-assistant](https://github.com/shoito/kot-chrome-assistant)）を Swift でフルリメイクしたものです。

- メニューバーから 1 クリックで Myレコーダーを開いて打刻
- 打刻（出勤 / 退勤 / 休始 / 休終）を検知して以下へ自動通知
  - **Slack メッセージ**（ユーザートークン or Incoming Webhooks、複数ワークスペース/チャンネル対応）
  - **Slack ステータス**（絵文字＋テキスト。休憩終了時は出勤時ステータスへ復帰）
  - **Google Chat**（Incoming Webhook）
  - **Google Chat ユーザー認証**（OAuth2 PKCE。自分のアイコン・名前で投稿）
- **App Intents** 対応 — Shortcuts / Spotlight / ターミナル（`shortcuts run`）から打刻可能
- セットアップ URL（`kotassistant://setup?d=BASE64` / 旧拡張形式）による設定配布

## 必要環境

- macOS 14 (Sonoma) 以降
- ビルドには Xcode 16 以降と [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## ビルド方法

```bash
./scripts/bootstrap.sh        # xcodegen をインストールして KOTAssistant.xcodeproj を生成
open KOTAssistant.xcodeproj   # Signing & Capabilities で Team を設定して Run
```

`*.xcodeproj` は XcodeGen の生成物なのでコミットされていません。`project.yml` を変更したら再度 `xcodegen generate` を実行してください。

コアロジックは純 Swift パッケージなので、Mac がなくてもテストできます:

```bash
swift test --package-path Packages/KOTCore
```

## 使い方

1. アプリを起動するとメニューバーに時計アイコンが常駐します
2. アイコンをクリックして Myレコーダーにログイン（ログイン状態は永続します）
3. 「設定…」から通知連携を設定
4. Myレコーダーの打刻ボタンを押すと、有効化した連携へ自動通知されます

アイコンは状態で変わります: 未出勤 `deskclock` / 勤務中 `deskclock.fill` / 休憩中 `cup.and.saucer.fill` / 退勤済み `moon.zzz.fill`

### ターミナルから打刻する

App Intents が Shortcuts に自動登録されるため、追加実装なしで CLI 相当が使えます:

```bash
shortcuts run "出勤"
shortcuts run "退勤"
shortcuts run "休憩開始"
shortcuts run "休憩終了"
shortcuts run "打刻状況"   # 例: 勤務中（出勤 09:00 → 休始 12:00 → 休終 13:00）
```

お好みで alias を:

```bash
alias dako='shortcuts run'
```

アプリが起動していなくても `shortcuts run` がバックグラウンドで起動します（Myレコーダーのログインセッションが有効な間）。

### Google Chat ユーザー認証のセットアップ

1. Google Cloud Console で OAuth クライアントを作成（**デスクトップアプリ**タイプ推奨。ループバックリダイレクト `http://127.0.0.1` を使用します）
2. Google Chat API を有効化（スコープ `chat.messages.create`）
3. 設定画面に Client ID / Client Secret / スペース ID を入力して「Google に接続」

スペース ID は 3 形式に対応: `spaces/AAAA` / `AAAA` / `https://chat.google.com/room/AAAA`

管理者から設定を配布する場合はセットアップ URL が使えます:

```
kotassistant://setup?d=<BASE64(JSON)>
```

JSON 形式（旧拡張と同じ）: `{"clientId", "clientSecret", "space", "clockIn", "clockOut", "breakStart", "breakEnd"}`。
旧拡張の `...#setup=BASE64` 形式の URL や素の base64 を設定画面に貼り付けても取り込めます。

## アーキテクチャ

```
KOTAssistant/                    アプリ本体（SwiftUI / macOS のみ）
├── KOTAssistantApp.swift        MenuBarExtra + Settings + 依存コンテナ
├── Recorder/                    常駐 WKWebView と JS ブリッジ
│   ├── RecorderWebController    keeper ウィンドウ方式で常時 JS 実行可能
│   └── Resources/kot_bridge.js  localStorage 読取・打刻検知・プログラム打刻
├── Intents/                     App Intents（出勤/退勤/休憩/状況）
├── UI/                          ポップオーバーと設定タブ
└── Support/                     Keychain・OAuth ループバックサーバ

Packages/KOTCore/                純 Swift パッケージ（Linux でもテスト可能）
├── KOTCore                      状態エンジン・設定モデル・SetupConfig・PKCE
└── KOTNotifications             Slack/Google Chat クライアント・OAuth トークン管理・通知ディスパッチャ
```

設計のポイント:

- **状態導出は Swift 側**: WebView は localStorage（`PARSONAL_BROWSER_RECORDER@SETTING` / `@RECORD_HISTORY_*`）の生 JSON を渡すだけ。打刻状態の判定・ボタン可用性は `RecorderStateEngine` が行い、Linux 上の `swift test` で検証できます
- **通知経路は一本**: ユーザーのクリックも App Intents のプログラム打刻も同じ実ボタンの click を踏むため、通知の二重送信が起きません
- **トークンは Keychain**: Slack トークン・OAuth クライアントシークレット・アクセストークン類は UserDefaults に置きません
- **OAuth はループバック方式**: Google クライアントはカスタム URL スキームを受け付けないため、`127.0.0.1` のワンショットサーバでリダイレクトを受けます。リフレッシュは single-flight・期限 5 分バッファ・401 時 1 回再送（旧拡張と同じ挙動）

### 旧拡張からの設定キー対応

UserDefaults のキー名は chrome.storage.sync のキーを踏襲しています（`slackEnabled` 等）。変更点:

| 旧拡張 | 本アプリ |
|---|---|
| `s2Selected` / `s3Selected` / `s4Selected` | `kotDomain` (s2/s3/s4) |
| `samlSelected` | `kotAuthMode` (account/saml) |
| `openInNewTab` | 廃止（「ブラウザで開く」ボタンに置換） |
| `slackToken` ほかトークン類 | Keychain（サービス名 `jp.co.infosign.KOTAssistant`） |
| `slackWebHooksUrl`（保存）/ `slackWebhooksUrl`（読取）の不一致バグ | `slackWebHooksUrl` に統一して修正 |

## 開発

- CI 定義は `scripts/github-actions-ci.yml`（Linux で `swift test`、macOS で `xcodegen generate` + `xcodebuild`）。
  リポジトリ移行後に `.github/workflows/ci.yml` へ移動してください
- コアのテストは `Packages/KOTCore/Tests/` に 57 件（状態エンジン・トークンローテーション・OAuth single-flight・401 リトライ・セットアップ URL マージ等）

### 新リポジトリへの移行

このブランチはルートが Swift プロジェクトの独立構成なので、そのまま新リポジトリの main にできます:

```bash
git clone https://github.com/worldnine/kot-chrome-assistant.git kot-macos-assistant
cd kot-macos-assistant
git checkout claude/swift-macos-remake-q9kcoj
git remote set-url origin <新リポジトリのURL>
git push -u origin claude/swift-macos-remake-q9kcoj:main
git mv scripts/github-actions-ci.yml .github/workflows/ci.yml  # CI を有効化
git commit -m "CIワークフローを有効化" && git push
```

履歴をまっさらにしたい場合は `git checkout --orphan main` で squash してから push してください。

### 初回ビルド後のスモークテスト

- [ ] メニューバーのポップオーバーに Myレコーダーが表示され、ログインが永続する
- [ ] 出勤 → 休始 → 休終 → 退勤 の各打刻でボタンが減光し、アイコンが変化する
- [ ] 各連携のテスト送信ボタンが成功する
- [ ] Google「接続」でブラウザ認可 → 接続済みになる
- [ ] `shortcuts run "打刻状況"` が状態を返す
- [ ] `shortcuts run "出勤"` で打刻と通知が行われる

## ライセンス

[MIT](LICENSE)
