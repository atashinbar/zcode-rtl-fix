#!/usr/bin/env bash
# ZCode RTL Fix — غیرفعال‌سازی اجرای خودکار پچ بعد از آپدیت
set -euo pipefail

LABEL="com.zcode.rtl-fix"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
echo "OK — auto-reapply disabled."
