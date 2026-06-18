#!/bin/bash
# 一鍵更新：從 Path-Report.enex 提取所有報告生成 APP 並推送到 GitHub
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENEX="$SCRIPT_DIR/../病理報告系統/Path-Report.enex"
TOKEN_FILE="$SCRIPT_DIR/.github_token"

echo "🔄 病理報告生成系統 — 一鍵更新"
echo "================================"

if [ ! -f "$ENEX" ]; then
  echo "❌ 找不到 Path-Report.enex"
  exit 1
fi

if [ ! -f "$TOKEN_FILE" ]; then
  echo "首次設定：請輸入 GitHub Personal Access Token"
  read -s -p "Token: " TOKEN
  echo ""
  echo "$TOKEN" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  echo "✅ Token 已儲存"
fi
TOKEN=$(cat "$TOKEN_FILE")

echo ""
echo "📦 從 Path-Report.enex 偵測並提取 APP..."
python3 << PYEOF
import xml.etree.ElementTree as ET
import base64, re, os, hashlib

enex_path = """$ENEX"""
hub_path = """$SCRIPT_DIR"""

# Pathology Form Database 不包含
SKIP_TITLES = {'Pathology Form Database'}

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
}

tree = ET.parse(enex_path)
root = tree.getroot()
resources = root.findall('.//resource')

updated = 0
skipped = 0

for i, res in enumerate(resources):
    data_el = res.find('data')
    mime_el = res.find('mime')
    if data_el is None or mime_el is None or mime_el.text != 'text/html':
        continue

    raw = data_el.text.replace('\n','').replace(' ','')
    html = base64.b64decode(raw).decode('utf-8', errors='replace')
    title_match = re.search(r'<title>(.*?)</title>', html, re.IGNORECASE)
    title = title_match.group(1) if title_match else f'resource_{i}'

    if title in SKIP_TITLES:
        print(f"  ⏭  略過：{title}")
        continue

    folder = next((v for k, v in folder_map.items() if k in title), f'app-{i}')
    out_dir = os.path.join(hub_path, folder)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, 'index.html')

    new_hash = hashlib.md5(html.encode()).hexdigest()
    old_hash = ''
    if os.path.exists(out_path):
        with open(out_path, 'rb') as f:
            old_hash = hashlib.md5(f.read()).hexdigest()

    if new_hash == old_hash:
        print(f"  ✓ 無變更：{folder}")
        skipped += 1
    else:
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(html)
        print(f"  🆕 已更新：{folder}  —  {title}")
        updated += 1

print(f"\n共更新 {updated} 個 APP，{skipped} 個無變更")
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
echo "🌐 https://shiauyu428.github.io/pathology-hub/"
