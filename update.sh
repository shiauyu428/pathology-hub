#!/bin/bash
# 一鍵更新：從 病理報告系統 子資料夾同步到 pathology-hub，偵測變更後推送
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/../病理報告系統"
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

# 來源資料夾 → hub 資料夾 對應表（格式：source_subfolder|hub_folder|html_filename）
declare -a MAPPINGS=(
  "Appendix|appendix|appendix_path_report_v1.html"
  "Benign|gallbladder|gallbladder_path_report.html"
  "Benign|uterus-benign|uterus_benign_report_1.html"
  "Breast - Biopsy|breast-bx|breast_bx_report_1.html"
  "Breast - DCIS|breast-dcis|breast-dcis-report_1.html"
  "Breast - Invasive cancer|breast|breast_path_report_v6_9.html"
  "Colon|colorectal|colorectal_path_report_2_1.html"
  "HCC|liver-hcc|liver_hcc_path_report_v6_1.html"
  "Intrahepatic Bile Duct|cholangiocarcinoma|bile_duct_ih_report_2.html"
  "Lung|lung|lung_path_report_1.html"
  "Oral|oral|oral_path_report_5.html"
  "Ovary|ovary|ovary_path_report.html"
  "Prostate - Biopsy|prostate|prostate_biopsy_report_3.html"
  "Skin - SCC|skin-scc|scc_skin_report_1.html"
  "Stomach|stomach|stomach_report_generator_1.html"
  "Thyroid|thyroid|thyroid_report_generator_5.html"
)

echo ""
echo "📂 同步來源 → pathology-hub..."
UPDATED=0

for mapping in "${MAPPINGS[@]}"; do
  IFS='|' read -r src_folder hub_folder filename <<< "$mapping"
  src="$SOURCE_DIR/$src_folder/$filename"
  dst="$SCRIPT_DIR/$hub_folder/index.html"

  if [ ! -f "$src" ]; then
    echo "  ⚠️  找不到來源：$src_folder/$filename"
    continue
  fi

  if cmp -s "$src" "$dst"; then
    echo "  ✓  無變更：$hub_folder"
  else
    cp "$src" "$dst"
    echo "  🆕 已更新：$hub_folder  ←  $src_folder/$filename"
    UPDATED=$((UPDATED + 1))
  fi
done

echo ""
if [ "$UPDATED" -eq 0 ]; then
  # 也檢查 git 有沒有其他手動改動
  CHANGED=$(git -C "$SCRIPT_DIR" status --short)
  if [ -z "$CHANGED" ]; then
    echo "✅ 沒有任何變更，無需推送"
    exit 0
  fi
fi

echo "📦 重新打包 all-in-one.html..."
python3 << PYEOF
import os, base64
HUB = os.path.dirname(os.path.abspath("$SCRIPT_DIR/update.sh"))
APPS = [
    ("breast","Breast — Invasive"),("breast-dcis","Breast — DCIS"),("breast-bx","Breast Biopsy"),
    ("lung","Lung"),("stomach","Stomach"),("colorectal","Colorectal"),("liver-hcc","Liver HCC"),
    ("cholangiocarcinoma","Cholangiocarcinoma"),("appendix","Appendix"),("thyroid","Thyroid"),
    ("prostate","Prostate Biopsy"),("ovary","Ovary"),("oral","Oral / H&N"),("skin-scc","Skin SCC"),
    ("uterus-benign","Uterus Benign"),("gallbladder","Gallbladder"),
]
encoded = []
for folder, label in APPS:
    p = os.path.join("$SCRIPT_DIR", folder, "index.html")
    if os.path.exists(p):
        with open(p, "rb") as f: data = base64.b64encode(f.read()).decode()
        encoded.append((folder, label, data))
card_parts = []
for fld,lbl,_ in encoded:
    card_parts.append(f'<div class="card" onclick="open_app(\'{fld}\')">{lbl}</div>\n')
cards = "".join(card_parts)
frame_parts = []
for fld,_,d in encoded:
    frame_parts.append(f'<iframe id="fr-{fld}" src="data:text/html;base64,{d}" style="display:none"></iframe>\n')
frames = "".join(frame_parts)
html = f"""<!DOCTYPE html><html lang="zh-TW"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>病理報告生成系統</title><style>*{{box-sizing:border-box;margin:0;padding:0}}body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;height:100vh;background:#f0f2f5;display:flex;flex-direction:column}}#home{{flex:1;overflow-y:auto;padding:32px 24px}}#home h1{{font-size:20px;font-weight:700;color:#111827;margin-bottom:6px}}#home p{{color:#6b7280;font-size:13px;margin-bottom:28px}}#grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:14px}}.card{{background:#fff;border:1px solid #e2e5ec;border-radius:12px;padding:20px 16px;cursor:pointer;transition:all .15s;font-size:14px;font-weight:500;color:#1e293b;line-height:1.4;box-shadow:0 1px 3px rgba(0,0,0,.06)}}.card:hover{{border-color:#2563eb;box-shadow:0 4px 12px rgba(37,99,235,.15);transform:translateY(-2px);color:#2563eb}}#viewer{{display:none;flex-direction:column;height:100vh}}#viewer-bar{{background:#fff;border-bottom:1px solid #e2e5ec;padding:8px 16px;display:flex;align-items:center;gap:12px;flex-shrink:0}}#back-btn{{background:#f0f2f5;border:1px solid #d1d5db;color:#374151;border-radius:8px;padding:6px 14px;font-size:13px;cursor:pointer;transition:all .15s}}#back-btn:hover{{background:#e5e7eb}}#viewer-title{{font-size:14px;font-weight:600;color:#111827}}iframe{{flex:1;border:none;width:100%;height:100%}}</style></head><body><div id="home"><h1>病理報告生成系統</h1><p>選擇報告類型開始填寫</p><div id="grid">{cards}</div></div><div id="viewer"><div id="viewer-bar"><button id="back-btn" onclick="go_home()">← 返回</button><span id="viewer-title"></span></div>{frames}</div><script>const LABELS={{{','.join(f"'{fld}':'{lbl}'" for fld,lbl,_ in encoded)}}};function open_app(id){{document.getElementById('home').style.display='none';const v=document.getElementById('viewer');v.style.display='flex';document.querySelectorAll('iframe').forEach(f=>f.style.display='none');document.getElementById('fr-'+id).style.display='block';document.getElementById('viewer-title').textContent=LABELS[id]||id;}}function go_home(){{document.getElementById('viewer').style.display='none';document.getElementById('home').style.display='block';document.querySelectorAll('iframe').forEach(f=>f.style.display='none');}}</script></body></html>"""
out = os.path.join("$SCRIPT_DIR", "pathology-all-in-one.html")
with open(out, "w", encoding="utf-8") as f: f.write(html)
import shutil
dest = os.path.join(os.path.dirname("$SCRIPT_DIR"), "病理報告系統", "pathology-all-in-one.html")
shutil.copy(out, dest)
print(f"  ✅ pathology-all-in-one.html ({os.path.getsize(out)//1024} KB)  →  也已存到病理報告系統/")
PYEOF

echo "🚀 推送到 GitHub..."
git -C "$SCRIPT_DIR" remote set-url origin "https://shiauyu428:${TOKEN}@github.com/shiauyu428/pathology-hub.git"
git -C "$SCRIPT_DIR" add -A
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
git -C "$SCRIPT_DIR" commit -m "更新 APP — $TIMESTAMP"
git -C "$SCRIPT_DIR" push
git -C "$SCRIPT_DIR" remote set-url origin "https://github.com/shiauyu428/pathology-hub.git"

echo ""
echo "✅ 推送完成！"
echo "🌐 https://shiauyu428.github.io/pathology-hub/"
echo "（GitHub Pages 約 1-2 分鐘後生效）"
