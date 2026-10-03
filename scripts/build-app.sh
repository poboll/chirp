#!/bin/bash
# 打包 chirp.app 并安装：构建 → 组装 bundle → ad-hoc 签名 → /Applications
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="chirp.app"
BUNDLE_ID="com.caiths.chirp"
VERSION="1.0.0"
STAGING="build/${APP_NAME}"

echo "==> 构建 release 二进制"
swift build -c release

echo "==> 生成图标"
if [ ! -f build/AppIcon.icns ]; then
  swift scripts/IconGen.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

echo "==> 组装 ${STAGING}"
rm -rf "${STAGING}"
mkdir -p "${STAGING}/Contents/MacOS" "${STAGING}/Contents/Resources"
cp .build/release/chirp "${STAGING}/Contents/MacOS/chirp"
cp build/AppIcon.icns "${STAGING}/Contents/Resources/AppIcon.icns"

cat > "${STAGING}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>chirp</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleName</key><string>chirp.</string>
  <key>CFBundleDisplayName</key><string>chirp.</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>caiths</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc 签名"
codesign --force --sign - --timestamp=none "${STAGING}"

echo "==> 安装到 /Applications"
rm -rf "/Applications/${APP_NAME}"
cp -R "${STAGING}" "/Applications/${APP_NAME}"

echo "==> 完成：/Applications/${APP_NAME}"
echo "    配置文件：~/.config/chirp/config.json"
echo "    自启动：sh scripts/install-launch-agent.sh"
