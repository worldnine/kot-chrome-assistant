# 社内版リポジトリのセットアップ手順

OSS版のリリース時に自動で社内版zipを生成するプライベートリポジトリの構成手順です。

## リポジトリ構成

```
your-org/kot-chrome-assistant-internal/
├── .github/
│   └── workflows/
│       └── build-internal.yml   # 下記のworkflowをコピー
└── setup.json                   # 社内向け初期設定
```

## 1. setup.json の作成

```json
{
  "clientId": "YOUR_OAUTH_CLIENT_ID.apps.googleusercontent.com",
  "clientSecret": "YOUR_OAUTH_CLIENT_SECRET",
  "space": "SPACE_ID_1 SPACE_ID_2",
  "clockIn": "出社しました。",
  "clockOut": "退社します。",
  "breakStart": "休憩入ります。",
  "breakEnd": "再開します。"
}
```

- `space`: 半角スペース区切りで複数指定可。省略するとユーザーが手動で設定。
- `clockIn` 等のメッセージ: 省略するとデフォルト値が使われます。

## 2. GitHub Actions workflow

`.github/workflows/build-internal.yml` を作成:

```yaml
name: 社内版zip作成

on:
  # OSS版リリース時に自動トリガー
  repository_dispatch:
    types: [oss-release]
  # 手動実行も可能
  workflow_dispatch:
    inputs:
      version:
        description: 'バージョン（例: v0.14.0）。空欄でOSS最新版を使用'
        required: false

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: バージョン決定
        id: version
        run: |
          if [ -n "${{ github.event.client_payload.version }}" ]; then
            echo "version=${{ github.event.client_payload.version }}" >> "$GITHUB_OUTPUT"
          elif [ -n "${{ inputs.version }}" ]; then
            echo "version=${{ inputs.version }}" >> "$GITHUB_OUTPUT"
          else
            VERSION=$(gh release view --repo worldnine/kot-chrome-assistant --json tagName -q .tagName)
            echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          fi
        env:
          GH_TOKEN: ${{ github.token }}

      - name: OSS版zipをダウンロード
        run: |
          gh release download ${{ steps.version.outputs.version }} \
            --repo worldnine/kot-chrome-assistant \
            --pattern 'kot-chrome-assistant.zip' \
            --dir /tmp
        env:
          GH_TOKEN: ${{ github.token }}

      - name: setup.json を同梱して社内版zipを作成
        run: |
          mkdir -p /tmp/internal
          unzip /tmp/kot-chrome-assistant.zip -d /tmp/internal
          cp setup.json /tmp/internal/
          cd /tmp/internal && zip -r /tmp/kot-chrome-assistant-internal.zip .

      - name: 社内版リリース作成
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.version.outputs.version }}
          name: ${{ steps.version.outputs.version }}（社内版）
          files: /tmp/kot-chrome-assistant-internal.zip
          body: |
            OSS版 ${{ steps.version.outputs.version }} ベースの社内版です。
            `setup.json` による初期設定が同梱されています。
```

## 3. OSS側リポジトリの設定

OSS版リポジトリ（worldnine/kot-chrome-assistant）で以下を設定:

1. **Repository variable** `INTERNAL_REPO` に社内リポジトリのフルネームを設定
   - 例: `your-org/kot-chrome-assistant-internal`
2. **Repository secret** `INTERNAL_REPO_TOKEN` に社内リポジトリへの `repository_dispatch` 権限を持つPATを設定
   - PAT作成時のスコープ: `repo`（プライベートリポジトリの場合）

## 動作フロー

1. OSS版でタグをpush → OSS版リリース作成
2. OSS版workflowが `repository_dispatch` で社内リポジトリに通知
3. 社内リポジトリのworkflowが自動起動
4. OSS版zipをダウンロード → `setup.json` を追加 → 社内版リリース作成

社内ユーザーは社内リポジトリのリリースページから社内版zipをダウンロードするだけで、
インストール後に自動で初期設定が適用されます。
