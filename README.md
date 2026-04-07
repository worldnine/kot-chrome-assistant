# MyレコーダーChromeアシスタント

Chromeウェブストア - MyレコーダーChromeアシスタント・ページ
https://chrome.google.com/webstore/detail/pifbdpooppfkllaiobkaoeocbfmpabaj/

勤怠管理システム「[Myレコーダー | KING OF TIME](https://kingoftime.jp/record/myrecorder/)」を快適に使えるようにするためのChrome拡張です。

## ブラウザの専用ボタンからポップアップ表示
ブックマークからMyレコーダーページを開くことすら面倒な人向けに、ポップアップ表示して、素早く出勤や退勤できるようにします。
![Browser Action](docs/images/browser-action.png)

## Myレコーダーページの出勤、退勤ボタンの表示アシスト
次のアクションを分かりやすくして、2重に出勤や退勤をしてしまう誤操作を予防します。
![Content Scripts](docs/images/content-scripts-clockout.png)

## 出勤、退勤時のGoogle Chatメッセージ通知
設定したGoogle ChatスペースのIncoming Webhookに対して、以下のようなメッセージが送られるようにできます。
メッセージやWebhook URLはカスタマイズ可能です。複数のWebhook URLを指定して同時に通知することもできます。

- 出勤ボタン押下時に「出社しました。」
- 退勤ボタン押下時に「退社します。」

※ Google Chatスペースで Incoming Webhook を発行して、オプション画面でWebhook URLを設定してください。

## 出勤、退勤時のGoogle Chatユーザー認証投稿
Google Chat APIのOAuth2ユーザー認証を使い、自分のGoogleアカウント（アイコン・名前）でメッセージを投稿できます。

- 出勤ボタン押下時に「出社しました。」
- 退勤ボタン押下時に「退社します。」

### セットアップ手順
1. Google Cloud Consoleでプロジェクトを作成（または既存プロジェクトを使用）
2. Google Chat API を有効化
3. OAuth 同意画面を設定（スコープ: `chat.messages.create`）
4. 認証情報 > OAuth 2.0 クライアントID を作成（アプリケーションの種類: **Chrome拡張機能**、拡張機能IDを指定）
5. 取得したクライアントIDをオプション画面の「OAuth Client ID」に入力
6. 「Googleに接続」ボタンで認証、投稿先スペースIDを設定

※ Google Workspaceアカウントが必要です。個人の@gmail.comアカウントではChat APIが利用できません。
※ ユーザー認証投稿ではChat appとの関連表示が残ります。

## 出勤、退勤時のSlackメッセージ通知
設定したSlackチャンネルに対して、以下のようなメッセージが送られるようにできます。  
メッセージやチャンネルはカスタマイズ可能です。

- 出勤ボタン押下時に「出社しました。」
- 退勤ボタン押下時に「退社します。」

## 出勤、退勤時のSlackステータス変更
設定したステータス絵文字やステータステキストで、以下のようなステータスに変更できます。  
ステータス絵文字やステータステキストはカスタマイズ可能です。

- 出勤ボタン押下時に「:office: 仕事中」
- 退勤ボタン押下時に「:house: プライベートタイム」

## Contributors ✨

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/shoito"><img src="https://avatars.githubusercontent.com/u/37051?v=4?s=100" width="100px;" alt="shoito"/><br /><sub><b>shoito</b></sub></a><br /><a href="https://github.com/shoito/kot-chrome-assistant/commits?author=shoito" title="Documentation">📖</a> <a href="#business-shoito" title="Business development">💼</a> <a href="https://github.com/shoito/kot-chrome-assistant/commits?author=shoito" title="Code">💻</a> <a href="#design-shoito" title="Design">🎨</a> <a href="#ideas-shoito" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://cti1650-portfolio-site.vercel.app/"><img src="https://avatars.githubusercontent.com/u/15701307?v=4?s=100" width="100px;" alt="cti1650"/><br /><sub><b>cti1650</b></sub></a><br /><a href="https://github.com/shoito/kot-chrome-assistant/commits?author=cti1650" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/hirobel"><img src="https://avatars.githubusercontent.com/u/350904?v=4?s=100" width="100px;" alt="Hiroaki Katoo"/><br /><sub><b>Hiroaki Katoo</b></sub></a><br /><a href="https://github.com/shoito/kot-chrome-assistant/commits?author=hirobel" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ueki-kazuki"><img src="https://avatars.githubusercontent.com/u/6090912?v=4?s=100" width="100px;" alt="Kazuki Ueki"/><br /><sub><b>Kazuki Ueki</b></sub></a><br /><a href="https://github.com/shoito/kot-chrome-assistant/commits?author=ueki-kazuki" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
