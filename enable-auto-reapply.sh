#!/usr/bin/env bash
# ZCode RTL Fix — فعال‌سازی اجرای خودکار پچ بعد از هر آپدیت ZCode
# یک LaunchAgent می‌سازد که app.asar را زیر نظر دارد و اگر ZCode آپدیت شد و پچ پاک شد،
# install.sh --if-needed را دوباره اجرا می‌کند (اگر پچ موجود باشد، کاری نمی‌کند).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH="$SCRIPT_DIR/install.sh"
[ -f "$INSTALL_SH" ] || { echo "ERROR: install.sh not found next to this script"; exit 1; }

LABEL="com.zcode.rtl-fix"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/.zcode/rtl-patch"
mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${INSTALL_SH}</string>
        <string>--if-needed</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WatchPaths</key>
    <array>
        <string>/Applications/ZCode.app/Contents/Resources/app.asar</string>
    </array>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/auto-reapply.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/auto-reapply.log</string>
</dict>
</plist>
EOF

# اگر نمونه قبلی هست، خاموشش کن
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo "OK — auto-reapply enabled."
echo "  Watcher: $PLIST"
echo "  Log:     $LOG_DIR/auto-reapply.log"
echo "  بعد از آپدیت ZCode، پچ ظرف حداکثر ~۱۰ دقیقه (یا بلافاصله با تغییر app.asar) دوباره نصب می‌شود؛"
echo "  سپس یک ری‌استارت ZCode برای اثر کردن پچ لازم است."
