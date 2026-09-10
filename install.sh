#!/usr/bin/env bash
# ZCode RTL Fix — نصب پچ نمایش راست‌به‌چپ متن‌های فارسی در ZCode Desktop
# کارکرد: از app.asar نسخه پشتیبان می‌گیرد، index.html رندرر را با یک <style> RTL مجهز می‌کند،
# سپس asar را دوباره بسته‌بندی می‌کند. اسکریپت idempotent است (اجرای دوباره، بلوک قبلی را جایگزین می‌کند).
# بعد از هر آپدیت ZCode هم می‌توان همین اسکریپت را دوباره اجرا کرد؛ بکاپ به‌صورت خودکار از
# نسخه تمیزِ جدید بازسازی می‌شود (تا uninstall هرگز باعث دانگرید نشود).
set -euo pipefail

# در محیط LaunchAgent مسیر npx نیست؛ مسیرهای رایج Node را اضافه کن
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"

APP="/Applications/ZCode.app"
RES="$APP/Contents/Resources"
ASAR="$RES/app.asar"
BACKUP_DIR="$HOME/.zcode/rtl-patch"
BACKUP="$BACKUP_DIR/app.asar.backup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_FILE="$SCRIPT_DIR/rtl-fix.css"
PAGE_JS="$SCRIPT_DIR/rtl-fix-page.js"
PRELOAD_JS="$SCRIPT_DIR/rtl-fix-preload.js"

[ -f "$CSS_FILE" ]    || { echo "ERROR: rtl-fix.css next to install.sh not found"; exit 1; }
[ -f "$PAGE_JS" ]     || { echo "ERROR: rtl-fix-page.js next to install.sh not found"; exit 1; }
[ -f "$PRELOAD_JS" ]  || { echo "ERROR: rtl-fix-preload.js next to install.sh not found"; exit 1; }
[ -f "$ASAR" ]     || { echo "ERROR: $ASAR not found — ZCode installed elsewhere?"; exit 1; }
command -v npx >/dev/null 2>&1 || { echo "ERROR: npx (Node.js) is required"; exit 1; }

ASAR_BIN=(npx --yes @electron/asar)
WORK="$(mktemp -d /tmp/zcode-rtl.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

asar_is_patched() {
  local d; d="$(mktemp -d)"
  if (cd "$d" && "${ASAR_BIN[@]}" extract-file "$ASAR" out/renderer/index.html >/dev/null 2>&1 \
       && grep -q "ZCODE-RTL-START" index.html 2>/dev/null); then
    rm -rf "$d"; return 0
  fi
  rm -rf "$d"; return 1
}

# حالت --if-needed برای واچر خودکار: اگر از قبل پچ است، هیچ کاری نکن (جلوگیری از حلقه)
if [ "${1:-}" = "--if-needed" ]; then
  if asar_is_patched; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') already patched — nothing to do"
    exit 0
  fi
  echo "$(date '+%Y-%m-%d %H:%M:%S') patch missing (ZCode updated?) — reinstalling"
fi

echo "==> [1/8] Preparing backup"
mkdir -p "$BACKUP_DIR"
if asar_is_patched; then
  if [ -f "$BACKUP" ]; then
    echo "    current app.asar already patched — keeping existing (pre-patch) backup"
  else
    echo "    WARNING: app is patched but backup is missing; uninstalling later will"
    echo "    require reinstalling ZCode. Continuing anyway."
  fi
else
  # asar تمیز است — یا نصب اولیه است یا ZCode تازه آپدیت شده و پچ پاک شده؛
  # بکاپ از همین نسخه تمیز ساخته/به‌روز می‌شود تا هرگز نسخه قدیمی را برنگردانیم
  echo "    current app.asar is pristine — saving/refreshing backup from it"
  cp "$ASAR" "$BACKUP"
fi

echo "==> [2/8] Extracting app.asar"
"${ASAR_BIN[@]}" extract "$ASAR" "$WORK/app"

HTML="$WORK/app/out/renderer/index.html"
[ -f "$HTML" ] || { echo "ERROR: out/renderer/index.html not found — app layout changed"; exit 1; }

# استخراجِ asar بیت اجرایی فایل‌های باینری را حفظ نمی‌کند؛ از نسخه اصلی برمی‌داریم
echo "    restoring native binary permissions"
while IFS= read -r -d '' f; do
  rel="${f#"$RES/app.asar.unpacked/"}"
  if [ -e "$WORK/app/$rel" ]; then
    chmod "$(stat -f '%Lp' "$f")" "$WORK/app/$rel"
  fi
done < <(find "$RES/app.asar.unpacked" -type f -print0)

echo "==> [3/8] Injecting RTL <style> into index.html"
python3 - "$HTML" "$CSS_FILE" <<'PYEOF'
import re, sys
html_path, css_path = sys.argv[1], sys.argv[2]
css = open(css_path, encoding='utf-8').read()
html = open(html_path, encoding='utf-8').read()
block = ('<!--ZCODE-RTL-START-->\n<style id="zcode-rtl-fix">\n'
         + css + '\n</style>\n<!--ZCODE-RTL-END-->')
if 'ZCODE-RTL-START' in html:
    html = re.sub(r'<!--ZCODE-RTL-START-->.*?<!--ZCODE-RTL-END-->',
                  lambda m: block, html, flags=re.S)
else:
    html = html.replace('</head>', block + '\n</head>', 1)
open(html_path, 'w', encoding='utf-8').write(html)
print('    patched')
PYEOF

echo "==> [4/8] Injecting RTL <script> (dir=auto applier) into index.html"
python3 - "$HTML" "$PAGE_JS" <<'PYEOF'
import re, sys
html_path, js_path = sys.argv[1], sys.argv[2]
js = open(js_path, encoding='utf-8').read()
html = open(html_path, encoding='utf-8').read()
block = ('<!--ZCODE-RTL-JS-START-->\n<script>\n' + js + '\n</script>\n<!--ZCODE-RTL-JS-END-->')
if 'ZCODE-RTL-JS-START' in html:
    html = re.sub(r'<!--ZCODE-RTL-JS-START-->.*?<!--ZCODE-RTL-JS-END-->',
                  lambda m: block, html, flags=re.S)
else:
    html = html.replace('</head>', block + '\n</head>', 1)
open(html_path, 'w', encoding='utf-8').write(html)
print('    patched')
PYEOF

echo "==> [5/8] Patching coding-plan webview preload (safety net for webview-based views)"
PRELOAD="$WORK/app/out/preload/codingPlanWebview.cjs"
[ -f "$PRELOAD" ] || { echo "ERROR: out/preload/codingPlanWebview.cjs not found — app layout changed"; exit 1; }
python3 - "$PRELOAD" "$PRELOAD_JS" <<'PYEOF'
import re, sys
preload_path, js_path = sys.argv[1], sys.argv[2]
js = open(js_path, encoding='utf-8').read()
src = open(preload_path, encoding='utf-8').read()
block = '/*ZCODE-RTL-PRELOAD-START*/' + js + '\n/*ZCODE-RTL-PRELOAD-END*/'
if 'ZCODE-RTL-PRELOAD-START' in src:
    src = re.sub(r'/\*ZCODE-RTL-PRELOAD-START\*/.*?/\*ZCODE-RTL-PRELOAD-END\*/',
                 lambda m: block, src, flags=re.S)
else:
    src = src + '\n' + block + '\n'
open(preload_path, 'w', encoding='utf-8').write(src)
print('    patched')
PYEOF
node --check "$PRELOAD" || { echo "ERROR: patched preload failed syntax check"; exit 1; }

echo "==> [6/8] Repacking app.asar (native modules stay unpacked)"
"${ASAR_BIN[@]}" pack "$WORK/app" "$WORK/app.asar.new" --unpack "{*.node,spawn-helper}"

echo "==> [7/8] Verifying new archive"
UNP="$WORK/app.asar.new.unpacked"
for f in \
  "node_modules/node-pty/prebuilds/darwin-arm64/pty.node" \
  "node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper" \
  "node_modules/ssh2/lib/protocol/crypto/build/Release/sshcrypto.node"; do
  [ -f "$UNP/$f" ] || { echo "ERROR: expected unpacked file missing: $f"; exit 1; }
done
[ -x "$UNP/node_modules/node-pty/prebuilds/darwin-arm64/spawn-helper" ] || {
  echo "ERROR: spawn-helper lost its executable bit"; exit 1; }
mkdir -p "$WORK/verify"
(cd "$WORK/verify" && "${ASAR_BIN[@]}" extract-file "$WORK/app.asar.new" out/renderer/index.html \
  && "${ASAR_BIN[@]}" extract-file "$WORK/app.asar.new" out/preload/codingPlanWebview.cjs)
grep -q "ZCODE-RTL-START" "$WORK/verify/index.html" || { echo "ERROR: html marker not in packed archive"; exit 1; }
grep -q "ZCODE-RTL-JS-START" "$WORK/verify/index.html" || { echo "ERROR: js marker not in packed archive"; exit 1; }
grep -q "ZCODE-RTL-PRELOAD-START" "$WORK/verify/codingPlanWebview.cjs" || { echo "ERROR: preload marker not in packed archive"; exit 1; }

echo "==> [8/8] Installing"
# فایل‌های unpacked قبلی سر جای خودشان می‌مانند (محتوایشان تغییری نکرده)
cp -R "$UNP/." "$RES/app.asar.unpacked/"
mv "$WORK/app.asar.new" "$ASAR"
echo "OK — patch installed."
echo ""
echo "حالا ZCode را کامل ببندید (Cmd+Q) و دوباره باز کنید تا اثر پچ را ببینید."
echo "برای حذف: $SCRIPT_DIR/uninstall.sh"
