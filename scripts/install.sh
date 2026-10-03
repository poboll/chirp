#!/bin/bash
# chirp. 一键安装：下载 Release → 装 /Applications → 注入配置 → 开机自启
#
# 用法：
#   curl -fsSL https://raw.githubusercontent.com/poboll/chirp/main/scripts/install.sh | bash
#   （再用菜单 ⌘, 打开配置文件填写 endpoint / key）
#
# 无人值守（配置以参数注入，密钥只落本机 ~/.config/chirp/config.json，不经过 GitHub）：
#   bash install.sh --endpoint https://your-blog/api/v3/fn/ps/update --key YOUR_KEY
#
# 可选参数：--version v1.1.0 指定版本；--debounce 3；--heartbeat 240
set -euo pipefail

REPO="poboll/chirp"
APP_NAME="chirp.app"
CONFIG_DIR="$HOME/.config/chirp"
CONFIG_FILE="${CONFIG_DIR}/config.json"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.caiths.chirp.plist"
ENDPOINT=""; KEY=""; DEBOUNCE="3"; HEARTBEAT="240"; VERSION="latest"

while [ $# -gt 0 ]; do
  case "$1" in
    --endpoint)  ENDPOINT="$2";  shift 2 ;;
    --key)       KEY="$2";       shift 2 ;;
    --debounce)  DEBOUNCE="$2";  shift 2 ;;
    --heartbeat) HEARTBEAT="$2"; shift 2 ;;
    --version)   VERSION="$2";   shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "未知参数：$1（--help 查看用法）" >&2; exit 1 ;;
  esac
done

echo "==> 1/4 下载 Release（${VERSION}）"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if [ "$VERSION" = "latest" ]; then
  ASSET_URL="https://github.com/${REPO}/releases/latest/download/chirp-macos-arm64.zip"
else
  ASSET_URL="https://github.com/${REPO}/releases/download/${VERSION}/chirp-macos-arm64.zip"
fi
curl -fSL --progress-bar -o "${TMP}/chirp.zip" "$ASSET_URL"
ditto -x -k --rsrc "${TMP}/chirp.zip" "${TMP}"

echo "==> 2/4 安装到 /Applications"
rm -rf "/Applications/${APP_NAME}"
cp -R "${TMP}/${APP_NAME}" "/Applications/${APP_NAME}"
xattr -dr com.apple.quarantine "/Applications/${APP_NAME}" 2>/dev/null || true

echo "==> 3/4 配置（${CONFIG_FILE}）"
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
if [ -n "$ENDPOINT" ] && [ -n "$KEY" ]; then
  umask 177
  cat > "$CONFIG_FILE" <<EOF
{
  "endpoint": "${ENDPOINT}",
  "key": "${KEY}",
  "debounceSeconds": ${DEBOUNCE},
  "heartbeatSeconds": ${HEARTBEAT}
}
EOF
  chmod 600 "$CONFIG_FILE"
  echo "    已写入 endpoint 与 key（权限 600）"
elif [ ! -f "$CONFIG_FILE" ]; then
  echo "    未提供 --endpoint/--key，且无既有配置。"
  echo "    请稍后点菜单栏小鸟 → 打开配置文件（⌘,）填写 endpoint 与 key。"
fi

echo "==> 4/4 开机自启（LaunchAgent）"
mkdir -p "$(dirname "$LAUNCH_AGENT")"
cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.caiths.chirp</string>
  <key>ProgramArguments</key>
  <array><string>/Applications/chirp.app/Contents/MacOS/chirp</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
</dict>
</plist>
PLIST
launchctl unload "$LAUNCH_AGENT" >/dev/null 2>&1 || true
launchctl load "$LAUNCH_AGENT"

echo "==> 完成。菜单栏出现小鸟即成功；⌘P 暂停，⌘R 刷新，⌘, 配置。"
