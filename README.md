# MyレコーダーChromeアシスタント（Google Chat対応版）

> [shoito/kot-chrome-assistant](https://github.com/shoito/kot-chrome-assistant) のフォークです。Google Chat通知機能を追加しています。

勤怠管理システム「[Myレコーダー | KING OF TIME](https://kingoftime.jp/record/myrecorder/)」を快適に使えるようにするためのChrome拡張です。

## 機能一覧

- ブラウザの専用ボタンからMyレコーダーをポップアップ表示
- 出勤/退勤ボタンの表示アシスト（誤操作防止）
- **Google Chat通知（Incoming Webhook）** — ボット名義で投稿
- **Google Chatユーザー認証投稿（OAuth2）** — 自分のアイコン・名前で投稿
- Slackメッセージ通知
- Slackステータス変更

## インストール

1. このリポジトリをクローンまたはzipでダウンロード
2. Chromeで `chrome://extensions` を開く
3. 右上の「デベロッパーモード」をONにする
4. 「パッケージ化されていない拡張機能を読み込む」をクリック
5. クローンしたディレクトリを選択

## Google Chat通知の設定

### 方法1: Incoming Webhook（ボット名義）

手軽に使えますが、投稿者はWebhookのボット名義になります。

1. Google Chatスペースを開く
2. スペース名をクリック → 「アプリと統合」→「Webhookを追加」
3. 名前を入力して「保存」→ Webhook URLをコピー
4. 拡張のオプション画面 →「Google Chatメッセージ通知」→ 有効化
5. Webhook URLを貼り付け、各イベントのメッセージを入力 →「適用」

### 方法2: OAuth2ユーザー認証（自分の名前で投稿）

自分のGoogleアカウント（アイコン・名前）で投稿できます。Google Workspaceアカウントが必要です。

#### GCPプロジェクトの準備（管理者が1回だけ実施）

1. [Google Cloud Console](https://console.cloud.google.com/) でプロジェクトを作成
2. **Google Chat APIの有効化**
   - 「APIとサービス」→「ライブラリ」→ 「Google Chat API」を検索して有効化
3. **Chat appの構成**
   - 「APIとサービス」→「Google Chat API」→「構成」タブ
   - アプリ名: 任意（例: KoT勤怠チャット通知）
   - アバターURL: 任意のアイコン画像URL（必須）
   - 説明: 任意
   - インタラクティブ機能: すべてOFF
   - 公開設定: 組織内の対象ユーザーに公開
   - 「保存」をクリック
4. **Google Auth Platformの設定**
   - 「Google Auth Platform」→「対象」→ User Type を **内部** に設定
   - 「Google Auth Platform」→「データアクセス」→ スコープを追加: `https://www.googleapis.com/auth/chat.messages.create`
   - ※ 旧UIでは「OAuth同意画面」として表示される場合があります
5. **OAuthクライアントIDの作成**
   - 「Google Auth Platform」→「クライアント」→「クライアントの作成」
   - アプリケーションの種類: **ウェブ アプリケーション**
   - 承認済みのリダイレクトURI: `https://<拡張のID>.chromiumapp.org/`
   - 拡張のIDは `chrome://extensions` で確認できます
   - ※ 旧UIでは「認証情報」→「認証情報を作成」→「OAuth 2.0 クライアントID」

#### 各ユーザーの設定

1. 拡張のオプション画面 →「Google Chatユーザー認証投稿」→ 有効化
2. 管理者から共有された **OAuth Client ID** を入力
3. **投稿先スペースID** を入力
   - Google Chatでスペースを開き、URLの末尾部分（例: `https://chat.google.com/room/AAAAxxxxBBBB` の `AAAAxxxxBBBB`）
   - `spaces/AAAAxxxxBBBB` 形式やURL全体でもOK
   - 複数スペースは半角スペース区切り
4. 各イベントのメッセージを入力 →「適用」
5. 「Googleに接続」→ Googleの認証画面で許可
6. 「テスト送信」で動作確認

## Slack通知の設定

### メッセージ通知

オプション画面 →「Slackメッセージ通知」で設定。「ユーザーとして通知する」（Token方式）と「Incoming WebHooks」の2方式に対応。

### ステータス変更

オプション画面 →「Slackステータス更新」で設定。出勤/退勤/休憩中のステータス絵文字・テキストをカスタマイズ可能。

## KING OF TIMEドメイン設定

オプション画面でs2/s3/s4サブドメインの切り替え、ユーザー認証/SAML認証の切り替えが可能。

## ライセンス

MIT

## 元リポジトリ

[shoito/kot-chrome-assistant](https://github.com/shoito/kot-chrome-assistant)
