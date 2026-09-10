#!/usr/bin/env bash
# ZCode RTL Fix — ساخت پکیج توزیع‌پذیر (تک‌فایلی + زیپ) در dist/
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$SRC_DIR/dist"
STAGE="$DIST/ZCode-RTL-Fix"
rm -rf "$STAGE"
mkdir -p "$STAGE"

cp "$SRC_DIR/install.sh" "$SRC_DIR/uninstall.sh" "$STAGE/"
cp "$SRC_DIR/rtl-fix.css" "$SRC_DIR/rtl-fix-page.js" "$SRC_DIR/rtl-fix-preload.js" "$STAGE/"
cp "$SRC_DIR/enable-auto-reapply.sh" "$SRC_DIR/disable-auto-reapply.sh" "$STAGE/"
cp "$SRC_DIR/README.fa.md" "$STAGE/"
chmod +x "$STAGE"/*.sh

# --- README انگلیسی کوتاه ---
cat > "$STAGE/README.en.md" <<'ENEOF'
# ZCode RTL Fix

Makes Persian/Arabic text render right-to-left correctly in the ZCode Desktop chat
(messages, lists, headings, and the typing box), while English and code stay LTR.

Requirements: macOS, ZCode Desktop installed at /Applications/ZCode.app, Node.js
(for `npx @electron/asar`).

## Install

Double-click `ZCode-RTL-Fix-Installer.command` (if macOS blocks it: right-click → Open),
or from a terminal:

    ./install.sh

Then fully restart ZCode (Cmd+Q → reopen).

## Uninstall

    ./uninstall.sh

## Auto re-apply after ZCode updates (optional)

    ./enable-auto-reapply.sh     # on
    ./disable-auto-reapply.sh    # off

## Notes

- Every ZCode app update wipes the patch; re-run install.sh (or enable the watcher).
- The app's code signature becomes invalid after patching; this does not break the
  app or future updates on the same machine.
- See README.fa.md for full details (Persian).
ENEOF

# --- نصاب تک‌فایلی ---
OUT="$DIST/ZCode-RTL-Fix-Installer.command"
{
  echo '#!/usr/bin/env bash'
  echo '# ZCode RTL Fix — single-file installer (Farsi/Persian RTL display fix for ZCode Desktop)'
  echo '# این فایل همه چیز را داخلش دارد؛ فقط اجرایش کنید.'
  echo 'set -euo pipefail'
  echo 'DEST="$HOME/zcode-rtl-patch"'
  echo 'mkdir -p "$DEST"'
  for f in install.sh uninstall.sh rtl-fix.css rtl-fix-page.js rtl-fix-preload.js enable-auto-reapply.sh disable-auto-reapply.sh; do
    echo "cat > \"\$DEST/$f\" <<'ZCODE_RTL_FILE_EOF'"
    cat "$SRC_DIR/$f"
    echo "ZCODE_RTL_FILE_EOF"
    echo "chmod +x \"\$DEST/$f\""
  done
  cat <<'TAIL'
echo "Files extracted to: $DEST"
echo "Running installer..."
bash "$DEST/install.sh"
echo ""
echo "برای فعال‌سازی نصب خودکار بعد از آپدیت‌های ZCode این را اجرا کنید:"
echo "  bash ~/zcode-rtl-patch/enable-auto-reapply.sh"
TAIL
} > "$OUT"
chmod +x "$OUT"

# --- زیپ ---
cd "$DIST" && rm -f ZCode-RTL-Fix.zip && zip -qr ZCode-RTL-Fix.zip ZCode-RTL-Fix

echo "OK — dist built:"
ls -lh "$DIST" | awk '{print $9, $5}'
