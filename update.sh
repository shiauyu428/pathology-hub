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
nav = "".join(f'<button{"  class=\"active\"" if i==0 else ""} onclick="show(\'{fld}\')" id="btn-{fld}">{lbl}</button>\n' for i,(fld,lbl,_) in enumerate(encoded))
frames = "".join(f'<iframe id="fr-{fld}" src="data:text/html;base64,{d}" style="display:{"block" if i==0 else "none"}"></iframe>\n' for i,(fld,_,d) in enumerate(encoded))
html = f"""<!DOCTYPE html><html lang="zh-TW"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>病理報告生成系統</title><style>*{{box-sizing:border-box;margin:0;padding:0}}body{{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;display:flex;flex-direction:column;height:100vh;background:#1c2b3a}}#topbar{{background:#1c2b3a;padding:10px 16px;display:flex;align-items:center}}#topbar h1{{color:#fff;font-size:14px;font-weight:600}}#nav{{background:#243447;padding:6px 12px;display:flex;gap:6px;flex-wrap:wrap;border-bottom:1px solid #1a2535}}button{{background:transparent;border:1px solid #3d5269;color:#8da0b3;border-radius:6px;padding:5px 11px;font-size:12px;cursor:pointer;white-space:nowrap;transition:all .15s}}button:hover{{background:#2d4256;color:#c5d5e5}}button.active{{background:#2563eb;border-color:#2563eb;color:#fff;font-weight:500}}#content{{flex:1;overflow:hidden;background:#fff}}iframe{{width:100%;height:100%;border:none}}</style></head><body><div id="topbar"><h1>病理報告生成系統</h1></div><div id="nav">{nav}</div><div id="content">{frames}</div><script>function show(id){{document.querySelectorAll('iframe').forEach(f=>f.style.display='none');document.querySelectorAll('button').forEach(b=>b.classList.remove('active'));document.getElementById('fr-'+id).style.display='block';document.getElementById('btn-'+id).classList.add('active');}}</script></body></html>"""
out = os.path.join("$SCRIPT_DIR", "pathology-all-in-one.html")
with open(out, "w", encoding="utf-8") as f: f.write(html)
print(f"  ✅ pathology-all-in-one.html ({os.path.getsize(out)//1024} KB)")
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
