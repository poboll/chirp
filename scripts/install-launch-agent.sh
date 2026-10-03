#!/bin/bash
# 配置开机自启动（LaunchAgent）并立即拉起 chirp.
set -euo pipefail

LABEL="com.caiths.chirp"
APP="/Applications/chirp.app"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ ! -d "$APP" ]; then
  echo "先运行 scripts/build-app.sh 安装应用" >&2
  exit 1
fi

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${APP}/Contents/MacOS/chirp</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
PLIST

# 移除旧的再加载
launchctl unload "$PLIST" 2>/dev/null || true
pkill -x chirp 2>/dev/null || true
launchctl load "$PLIST"

sleep 1
if pgrep -x chirp >/dev/null; then
  echo "chirp. 已在运行，并已配置开机自启动"
else
  echo "启动失败，请手动检查：open ${APP}" >&2
  exit 1
fi
