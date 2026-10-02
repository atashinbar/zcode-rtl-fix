#!/usr/bin/env bash
# ZCode RTL Fix — واچر سازگار با محافظت App Management مک
# نسخه‌های جدید macOS اجازه نمی‌دهند پروسه‌ی پس‌زمینه (launchd) داخل باندل اپ بنویسد؛
# بنابراین: اول نصب بی‌صدای معمولی را امتحان می‌کنیم؛ اگر TCC جلوگیری کرد،
# حداکثر یک بار در روز یک دیالوگ نشان می‌دهیم و با تایید کاربر، با دسترسی ادمین نصب می‌کنیم.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/.zcode/rtl-patch"
STAMP="$LOG_DIR/.last-prompt"
mkdir -p "$LOG_DIR"
LOG="$LOG_DIR/auto-reapply.log"
ts() { date '+%Y-%m-%d %H:%M:%S'; }

if OUT=$(bash "$SCRIPT_DIR/install.sh" --if-needed 2>&1); then
  echo "$OUT" | tail -1 >> "$LOG"
  exit 0
fi

echo "$(ts) silent install failed (likely App Management/TCC): $(echo "$OUT" | tail -1)" >> "$LOG"

# حداکثر یک بار در ۲۴ ساعت دیالوگ نشان بده
NOW=$(date +%s)
if [ -f "$STAMP" ]; then
  LAST=$(stat -f %m "$STAMP" 2>/dev/null || echo 0)
  [ $(( NOW - LAST )) -lt 86400 ] && exit 0
fi
touch "$STAMP"

BTN=$(/usr/bin/osascript -e 'display dialog "آپدیت ZCode پچ فارسی (RTL) را پاک کرده است. الان دوباره نصب شود؟" with title "ZCode RTL Fix" buttons {"بعداً", "الان نصب کن"} default button "الان نصب کن" cancel button "بعداً"' -e 'button returned of result' 2>/dev/null)
if [ "${BTN:-}" != "الان نصب کن" ]; then
  echo "$(ts) user postponed" >> "$LOG"
  exit 0
fi

CMD="HOME='$HOME' ZCODE_RTL_OWNER='$(id -un)' /bin/bash '$SCRIPT_DIR/install.sh' >>'$LOG' 2>&1"
if /usr/bin/osascript -e "do shell script \"$CMD\" with administrator privileges with prompt \"ZCode RTL Fix\"" 2>>"$LOG"; then
  echo "$(ts) admin install OK" >> "$LOG"
  /usr/bin/osascript -e 'display notification "پچ RTL دوباره نصب شد — ZCode را یک بار ری‌استارت کنید" with title "ZCode RTL Fix"' 2>/dev/null
else
  echo "$(ts) admin install failed" >> "$LOG"
fi
