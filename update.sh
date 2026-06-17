#!/bin/bash
# 一鍵更新：從 Path-Report.enex 提取所有 APP 並推送到 GitHub

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENEX="$SCRIPT_DIR/../病理報告系統/Path-Report.enex"
TOKEN_FILE="$SCRIPT_DIR/.github_token"

echo "🔄 病理工具一鍵更新"
echo "================================"

# 確認 enex 存在
if [ ! -f "$ENEX" ]; then
  echo "❌ 找不到 Path-Report.enex：$ENEX"
  exit 1
fi

# 讀取 GitHub token
if [ ! -f "$TOKEN_FILE" ]; then
  echo "首次設定：請輸入 GitHub Personal Access Token"
  read -s -p "Token: " TOKEN
  echo ""
  echo "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "✅ Token 已儲存"
fi
TOKEN=$(cat "$TOKEN_FILE")

# 提取所有 HTML
echo ""
echo "📦 從 Path-Report.enex 提取 APP..."
python3 << PYEOF
import xml.etree.ElementTree as ET
import base64, re, os

enex_path = """$ENEX"""
hub_path = """$SCRIPT_DIR"""

folder_map = {
    'Ovary': 'ovary',
    'Cholangiocarcinoma': 'cholangiocarcinoma',
    'Uterus Benign': 'uterus-benign',
    'Appendix': 'appendix',
    'Breast Bx': 'breast-bx',
    'Stomach': 'stomach',
    'Colorectal': 'colorectal',
    'Liver HCC': 'liver-hcc',
    'Thyroid': 'thyroid',
    'Prostate': 'prostate',
    'Gallbladder': 'gallbladder',
    'Lung': 'lung',
    '口腔': 'oral',
    'Breast DCIS': 'breast-dcis',
    'Skin SCC': 'skin-scc',
    '乳癌': 'breast',
    'Pathology Form Database': 'evernote-forms',
}

tree = ET.parse(enex_path)
root = tree.getroot()
resources = root.findall('.//resource')

count = 0
for i, res in enumerate(resources):
    data_el = res.find('data')
    mime_el = res.find('mime')
    if data_el is None or mime_el is None or mime_el.text != 'text/html':
        continue
    raw = data_el.text.replace('\n','').replace(' ','')
    html = base64.b64decode(raw).decode('utf-8', errors='replace')
    title_match = re.search(r'<title>(.*?)</title>', html, re.IGNORECASE)
    title = title_match.group(1) if title_match else f'resource_{i}'
    folder = next((v for k, v in folder_map.items() if k in title), f'app-{i}')
    out_dir = os.path.join(hub_path, folder)
    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, 'index.html'), 'w', encoding='utf-8') as f:
        f.write(html)
    print(f"  ✓ {folder}  —  {title}")
    count += 1

print(f"\n共更新 {count} 個 APP")
PYEOF

# Git commit & push
echo ""
echo "🚀 推送到 GitHub..."
cd "$SCRIPT_DIR"
git remote set-url origin "https://shiauyu428:${TOKEN}@github.com/shiauyu428/pathology-hub.git"

git add -A
if git diff --cached --quiet; then
  echo "✅ 沒有變更，無需推送"
else
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
  git commit -m "更新 APP — $TIMESTAMP"
  git push
  echo "✅ 推送完成！"
fi

git remote set-url origin "https://github.com/shiauyu428/pathology-hub.git"
echo ""
echo "🌐 網站：https://shiauyu428.github.io/pathology-hub/"
echo "（GitHub Pages 約 1-2 分鐘後生效）"
