#!/usr/bin/env bash
# ZCode RTL Fix — حذف پچ و بازگردانی app.asar اصلی
# محافظ آپدیت: اگر ZCode از وقتی پچ شده آپدیت شده باشد (asar فعلی پچ ندارد)،
# برگرداندن بکاپ قدیمی یعنی دانگرید اپ — این اسکریپت به‌صورت پیش‌فرض اجازه نمی‌دهد.
# برای دانگرید اصراری: uninstall.sh --force
set -euo pipefail

APP="/Applications/ZCode.app"
RES="$APP/Contents/Resources"
ASAR="$RES/app.asar"
BACKUP="$HOME/.zcode/rtl-patch/app.asar.backup"
ASAR_BIN=(npx --yes @electron/asar)

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

if [ ! -f "$BACKUP" ]; then
  echo "ERROR: backup not found at $BACKUP"
  echo "If ZCode was updated after patching, simply reinstall ZCode to get a clean app."
  exit 1
fi

PATCHED=0
d="$(mktemp -d)"
if (cd "$d" && "${ASAR_BIN[@]}" extract-file "$ASAR" out/renderer/index.html >/dev/null 2>&1 \
     && grep -q "ZCODE-RTL-START" index.html 2>/dev/null); then
  PATCHED=1
fi
rm -rf "$d"

if [ "$PATCHED" -ne 1 ] && [ "$FORCE" -ne 1 ]; then
  echo "NOTE: current app.asar is NOT patched — ZCode has probably updated since the patch"
  echo "      and the patch is already gone. Restoring the old backup would DOWNGRADE the app."
  echo "      Nothing to uninstall. To downgrade anyway, run: uninstall.sh --force"
  exit 0
fi

echo "==> Restoring original app.asar from backup"
cp "$BACKUP" "$ASAR"
echo "OK — original app.asar restored. Restart ZCode (Cmd+Q, then reopen)."
