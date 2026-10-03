#!/bin/bash
# 打包 chirp.app：构建 → 组装 bundle → ad-hoc 签名
# 默认安装到 /Applications；--dist 只产出 zip（CI / 发布用）
# 版本可用 CHIRP_VERSION 环境变量覆盖（默认取 git tag，无 tag 则 1.0.0）
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="chirp.app"
BUNDLE_ID="com.caiths.chirp"
DIST_ONLY=0
[ "${1:-}" = "--dist" ] && DIST_ONLY=1

if [ -n "${CHIRP_VERSION:-}" ]; then
  VERSION="${CHIRP_VERSION}"
elif command -v git >/dev/null && git describe --tags >/dev/null 2>&1; then
  VERSION="$(git describe --tags --abbrev=0 | sed 's/^v//')"
else
  VERSION="1.0.0"
fi
STAGING="build/${APP_NAME}"

echo "==> 构建 release 二进制（v${VERSION}）"
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

if [ "$DIST_ONLY" = "1" ]; then
  # 固定产物名：releases/latest/download/ 需要稳定 URL
  ARTIFACT="dist/chirp-macos-arm64.zip"
  mkdir -p dist
  rm -f "${ARTIFACT}" "${ARTIFACT}.sha256"
  (cd build && zip -qry "../${ARTIFACT}" "${APP_NAME}")
  shasum -a 256 "${ARTIFACT}" | tee "${ARTIFACT}.sha256"
  echo "==> 产物：${ARTIFACT}（v${VERSION}）"
  exit 0
fi

echo "==> 安装到 /Applications"
rm -rf "/Applications/${APP_NAME}"
cp -R "${STAGING}" "/Applications/${APP_NAME}"

echo "==> 完成：/Applications/${APP_NAME}"
echo "    配置文件：~/.config/chirp/config.json"
echo "    自启动：sh scripts/install-launch-agent.sh"
