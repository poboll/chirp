<div align="center">

<img src="assets/icon.png" width="108" alt="chirp. icon">

# chirp.

**报信小鸟** —— 把「正在使用的软件」实时汇报给你的博客。

[![Release](https://img.shields.io/github/v/release/poboll/chirp?style=flat-square&label=Release)](https://github.com/poboll/chirp/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9%20·%20AppKit-orange?style=flat-square)](Package.swift)
[![macOS](https://img.shields.io/badge/macOS-13%2B-silver?style=flat-square)](https://poboll.github.io/chirp/)

[官网](https://poboll.github.io/chirp/) · [下载 Release](https://github.com/poboll/chirp/releases/latest)

</div>

---

`chirp.` 是一个 macOS 菜单栏应用：看着你正在用什么软件，叽叽喳喳地告诉博客。访客打开你的页面，导航栏上就会显示「正在使用 Xcode」这样的实时状态。

灵感来自 Innei 的 [ProcessReporter](https://github.com/Innei/ProcessReporter)（及其前身 mx-space/ProcessReporterMac），但只想留下一件事：**报信**。没有 Slack、没有 Discord、没有 S3，一只小鸟就够。

## 特性

- **轻**：纯 AppKit + Swift Package，零第三方依赖，release 二进制约 200KB
- **省**：只在应用切换时上报（3 秒防抖），每 4 分钟心跳续期一次（服务端缓存 5 分钟）
- **稳**：睡眠唤醒自动补报、失败菜单栏图标变红、`KeepAlive` 常驻
- **静**：`LSUIElement` 无 Dock 图标，只住菜单栏
- **有图标**：上报带应用图标，三层自动回落（见下），新装软件零操作

## 工作方式

```text
切换应用 ──防抖 3s──▶ POST /api/v3/fn/ps/update
                        {key, timestamp, process: {name, iconUrl?}}
                              │
                              ▼
              mx-space snippet 缓存 5 分钟 + WebSocket 广播
                              │
                              ▼
              博客导航栏「正在使用 XX」（Shiro / Yohaku 主题）
```

## 使用

### 方式一：一键安装（推荐）

需要 macOS 13+（Apple Silicon）。先准备好 mx-space 的 `ps/update` fn snippet（Shiro 官方生态自带，主题配置 `module.activity.endpoint`）：

```bash
# 交互式：装好后点菜单栏小鸟 → 打开配置文件（⌘,）填 endpoint 和 key
curl -fsSL https://raw.githubusercontent.com/poboll/chirp/main/scripts/install.sh | bash

# 无人值守：配置以参数注入（密钥只落本机 ~/.config/chirp/config.json，权限 600）
bash install.sh --endpoint https://your-blog.example.com/api/v3/fn/ps/update --key YOUR_KEY
```

安装脚本会：下载最新 Release → 装 `/Applications` → 写配置（若给了参数）→ 配置开机自启并立即启动。

### 方式二：源码构建

1. 配置 `~/.config/chirp/config.json`（权限 600）：

```json
{
  "endpoint": "https://your-blog.example.com/api/v3/fn/ps/update",
  "key": "与 snippet 一致的密钥",
  "debounceSeconds": 3,
  "heartbeatSeconds": 240
}
```

2. 构建安装：

```bash
sh scripts/build-app.sh            # 构建 + 组装 + 安装到 /Applications
sh scripts/install-launch-agent.sh # 开机自启动 + 立即运行
```

菜单栏的小鸟：单击看「当前应用 / 博客显示 / 上次上报结果」，`⌘P` 暂停，`⌘R` 立即刷新，`⌘,` 打开配置，`⌘H` 使用说明（[官网](https://poboll.github.io/chirp/)）。

## 图标从哪来

前端「正在使用」的应用图标按三层回落，绝大多数应用不需要任何手动配置：

1. **主题内置映射**：Shiro/Yohaku 自带的 [Innei/reporter-assets](https://github.com/Innei/reporter-assets) 名称映射（Xcode、VS Code 等常见开发软件）；
2. **app-icons CDN**：chirp 按 [poboll/app-icons](https://github.com/poboll/app-icons) 的 `manifest.json` 把应用名映射成 jsdelivr CDN 图标 URL 上报（约 240 个常见 macOS 应用，manifest 每日自动刷新缓存）；
3. **data URI 兜底**：两者都未命中时，直接抓本机应用图标内嵌上报——新装任何软件立即可用，等它进了 app-icons 仓库后自动切成 CDN 轻量模式。

想扩充 CDN 图标库：`swift scripts/ExportIcons.swift` 导出本机图标与 manifest，往 app-icons 仓库提 PR 即可。

## 开发

```bash
swift build            # 构建
swift run              # 本地跑
swift scripts/IconGen.swift build/AppIcon.iconset  # 重新生成图标
```

## 致谢

- [Innei/ProcessReporter](https://github.com/Innei/ProcessReporter) 与 [mx-space](https://github.com/mx-space) 生态——原始创意与 serverless snippet 契约

## License

MIT
