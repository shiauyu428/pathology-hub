#!/bin/bash
# 一鍵更新：偵測 pathology-hub 資料夾內的變更並推送到 GitHub
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="$SCRIPT_DIR/.github_token"

echo "🔄 病理報告生成系統 — 一鍵更新"
echo "================================"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "首次設定：請輸入 GitHub Personal Access Token"
  read -s -p "Token: " TOKEN
  echo ""
  echo "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "✅ Token 已儲存"
fi
TOKEN=$(cat "$TOKEN_FILE")

cd "$SCRIPT_DIR"

# 顯示有哪些檔案變更
echo ""
CHANGED=$(git status --short)
if [ -z "$CHANGED" ]; then
  echo "✅ 沒有變更，無需推送"
  exit 0
fi

echo "📝 偵測到以下變更："
git status --short
echo ""

# Push
git remote set-url origin "https://shiauyu428:${TOKEN}@github.com/shiauyu428/pathology-hub.git"
git add -A
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
git commit -m "更新 APP — $TIMESTAMP"
git push
git remote set-url origin "https://github.com/shiauyu428/pathology-hub.git"

echo ""
echo "✅ 推送完成！"
echo "🌐 https://shiauyu428.github.io/pathology-hub/"
echo "（GitHub Pages 約 1-2 分鐘後生效）"
