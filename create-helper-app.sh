#!/usr/bin/env bash
# ZCode RTL Fix — ساخت اپ کمکی برای نصب بی‌صدای خودکار
# macOS به پروسه‌های پس‌زمینه اجازه‌ی نوشتن در باندل اپ‌ها را نمی‌دهد، مگر اینکه
# یک اپ «واقعی» مجوز App Management گرفته باشد. این اسکریپت یک اپ کوچک می‌سازد
# که فقط install.sh را اجرا می‌کند؛ یک بار به آن مجوز بدهید تا نصب خودکار
# بعد از آپدیت‌ها برای همیشه بی‌صدا شود.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/Applications"
APP="$APP_DIR/ZCode RTL Reapply.app"
BIN="$APP/Contents/MacOS/ZCode RTL Reapply"

mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ZCode RTL Reapply</string>
    <key>CFBundleDisplayName</key>
    <string>ZCode RTL Reapply</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.atashinbar.zcode-rtl-reapply</string>
    <key>CFBundleExecutable</key>
    <string>ZCode RTL Reapply</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
</dict>
</plist>
EOF

cat > "$BIN" <<EOF
#!/bin/bash
# اپ کمکی ZCode RTL Fix — فقط نصب پچ را انجام می‌دهد
LOG="\$HOME/.zcode/rtl-patch/auto-reapply.log"
mkdir -p "\$HOME/.zcode/rtl-patch"
export PATH="\$PATH:\$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"
bash "$SCRIPT_DIR/install.sh" --if-needed >> "\$LOG" 2>&1
exit \$?
EOF
chmod +x "$BIN"

echo "OK — helper app created:"
echo "  $APP"
echo ""
echo "یک بار برای همیشه این کار را بکنید (حدود ۳۰ ثانیه):"
echo "  System Settings → Privacy & Security → App Management"
echo "  → دکمه + → پوشه Applications (خانگی) → «ZCode RTL Reapply» → Open"
echo "از این به بعد نصب خودکار بعد از آپدیت ZCode بی‌صدا انجام می‌شود."
