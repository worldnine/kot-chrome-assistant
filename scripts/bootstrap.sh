#!/usr/bin/env bash
# Xcode プロジェクトの生成（初回および project.yml 変更時に実行）
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen が見つからないためインストールします..."
  brew install xcodegen
fi

xcodegen generate
echo
echo "生成完了: open KOTAssistant.xcodeproj"
echo "Xcode で Signing & Capabilities の Team を設定してから Run してください。"
