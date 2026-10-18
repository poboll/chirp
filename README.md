<div align="center">

<img src="assets/icon.png" width="108" alt="chirp. icon">

# chirp.

**报信小鸟** —— 把「正在使用的软件」实时汇报给你的博客。

[![Release](https://img.shields.io/github/v/release/poboll/chirp?style=flat-square&label=Release)](https://github.com/poboll/chirp/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-5.9%20·%20AppKit-orange?style=flat-square)](Package.swift)
[![macOS](https://img.shields.io/badge/macOS-13%2B%20·%20Apple%20Silicon-silver?style=flat-square)](https://poboll.github.io/chirp/)

[官网](https://poboll.github.io/chirp/) · [下载 Release](https://github.com/poboll/chirp/releases/latest)

</div>

<div align="center">

![菜单栏与下拉菜单](assets/menu-shot.png)

<sub>装上之后，菜单栏右侧就是这只小鸟 —— 点开即可看到「当前应用 / 博客显示 / 上报状态」。</sub>

</div>

---

`chirp.` 是一个 macOS 菜单栏应用：看着你正在用什么软件，叽叽喳喳地告诉博客。访客打开你的页面，导航栏上就会显示「正在使用 Xcode」这样的实时状态。

它脱胎于 [Innei](https://github.com/Innei) 的 [ProcessReporter](https://github.com/Innei/ProcessReporter) 与 [mx-space/ProcessReporterMac](https://github.com/mx-space/ProcessReporterMac)，但只保留一件事：**报信**。没有 Slack、没有 Discord、没有 S3，一只小鸟就够。

## 特性

- **轻**：纯 AppKit + Swift Package，零第三方依赖，release 二进制约 **250KB**
- **省**：只在应用切换时上报（3 秒防抖），每 4 分钟心跳续期一次（服务端缓存 5 分钟）
- **稳**：睡眠唤醒自动补报、失败菜单栏图标变红、`KeepAlive` 常驻
- **静**：`LSUIElement` 无 Dock 图标，只住菜单栏
- **有图标**：上报带应用图标，三层自动回落（见下），新装软件零操作

## 工作方式

```text
切换应用 ──防抖 3s──▶ POST /api/v3/fn/ps/update
                        {key, timestamp, process: {name, iconUrl?, iconBase64?}}
                              │
                              ▼
           mx-space 函数（fn snippet）写入缓存 + WebSocket 广播
                              │
                              ▼
               博客导航栏「正在使用 XX」
```

上报内容只有三样：**应用名、图标、时间戳**。没有窗口标题、没有输入内容、没有截屏。

---

## 生态与兼容性

chirp 是 [Innei](https://github.com/Innei)（[innei.in](https://innei.in)）那套 **mx-space 写作生态**里的一块拼图。下面这些项目的状态与职责都按仓库实际情况标注，方便你判断自己该用哪一套。

### 后端

| 项目 | 是什么 | 状态 |
|---|---|---|
| [mx-space/core](https://github.com/mx-space/core) | 生态的心脏：NestJS + Fastify + PostgreSQL + Redis 的无头 CMS，v12 起用 PostgreSQL | 活跃 · 双许可 AGPLv3 + MIT |
| [mx-space/api-client](https://github.com/mx-space/api-client) | mx-space RESTful API 的 TypeScript 客户端（Yohaku 的 Companion 调用即出自它） | **已归档** · ★5 |

> Yohaku 用的是它发布的 `@mx-space/api-client` npm 包 —— 仓库已归档，但包仍在被消费。

### 前端 / 主题

| 项目 | 是什么 | 状态 |
|---|---|---|
| [Innei/Yohaku](https://github.com/Innei/Yohaku) | 余白 —— 排版设计系统 + iOS 客户端，官方**推荐**的现代前端体验（线上实例 [innei.in](https://innei.in)） | 活跃 · 设计系统 MIT |
| [Innei/Shiro](https://github.com/Innei/Shiro) | 极简个人站，纸雪质感的经典前端，★4k+ | 活跃 · AGPLv3 |
| **Shiroi**（`innei-dev/Shiroi`） | Yohaku 的**上一代**付费前端，与 Yohaku 已完全分离、赞助关系独立 | 赞助获取 · **仓库非公开，故不直链** |
| [mx-space/kami](https://github.com/mx-space/kami) | 动漫风经典前端 | 维护中（legacy） |
| [mx-space/mx-admin](https://github.com/mx-space/mx-admin) | 上一代 Vue 3 管理后台 | **已归档**（已并入 core 自带 admin） |

> **Yohaku 的构成**（据其官方 README）：[Innei/Yohaku](https://github.com/Innei/Yohaku) 公开 **iOS 客户端（MIT）+ 设计系统（MIT）+ 跨端渲染包**；**完整 Web 实现**在赞助后可访问的仓库中持续维护，要求 **mx-core v12+**。获取方式是通过 [GitHub Sponsors](https://github.com/sponsors/Innei) 赞助后在 [Innei/Yohaku Issues](https://github.com/Innei/Yohaku/issues) 提交用户名开通。
>
> 注意别把三者搞混：**Shiro**（本文表格里的开源极简前端）、**Shiroi**（上一代付费前端）、**Yohaku**（新一代）。Shiroi 与 Yohaku 的访问权限与赞助关系相互独立，赞助其中一个不等于获得另一个。

### 上报端（chirp 的前辈）

| 项目 | 是什么 | 状态 |
|---|---|---|
| [Innei/ProcessReporter](https://github.com/Innei/ProcessReporter) | 最初的 macOS 上报器（Swift/AppKit） | **已归档** |
| [mx-space/ProcessReporterMac](https://github.com/mx-space/ProcessReporterMac) | 为 Shiro 而生的上报器，经服务端 WebSocket 实时推给访客，MIT | 活跃 |
| [Innei/reporter-assets](https://github.com/Innei/reporter-assets) | 应用名 → 图标/描述的资源库（约 80 个常用应用，含中文名映射） | 活跃 · 未声明 License（二次分发前请先确认） |
| [poboll/app-icons](https://github.com/poboll/app-icons) | chirp 自用的图标库（**实测 239 个应用**，jsdelivr CDN，每日刷新） | 活跃 · chirp 维护 |

### ⚠️ 两套「正在使用」机制，别混淆

这是最容易踩坑的地方 —— 生态里同时存在**两代**方案，接口完全不同：

1. **函数订阅式（chirp 采用）**：客户端 POST 到 mx-space 的 **serverless 函数** `/api/v3/fn/ps/update`，函数把状态写进缓存并经 WebSocket 广播。只需在 mx-space 后台建一个 fn snippet、前端主题读它即可。**chirp 走的就是这条**，适用于自建、Shiro 时代、以及任何你自己写的读接口。
2. **mx-core Companion（新一代）**：mx-core 内置 `companion` 模块，路由为 `PUT /companion/presence`、`POST /companion/presence/clear`、`GET /companion/presence/public`（schema `yohaku.companion.presence` v2，建议 30 秒心跳、租约 30–120 秒）。Yohaku 的「Live Desk」正是消费这条。

**结论**：chirp 目前对接的是**方案 1**。如果你用的是 Yohaku 的 Live Desk（方案 2），chirp 不能直接顶替 —— 需要等 chirp 适配 Companion 协议，或另配一个中转函数。Shiro 时代与自建博客用方案 1 即可，这也是 chirp 的默认路径。

---

## 使用

### 方式一：一键安装（推荐）

> 仅支持 **Apple Silicon**（arm64）。macOS 13+。Release 里没有 Intel 构建 —— 需要 Intel 版请按方式二自行编译。

先在 mx-space 后台准备好 `ps/update` 函数（见下文「接入」或[官网](https://poboll.github.io/chirp/#integration)），然后：

```bash
# 交互式：装好后点菜单栏小鸟 → 打开配置文件（⌘,）填 endpoint 和 key
curl -fsSL https://raw.githubusercontent.com/poboll/chirp/main/scripts/install.sh | bash

# 无人值守：配置以参数注入（密钥只落本机 ~/.config/chirp/config.json，权限 600）
bash install.sh --endpoint https://your-blog.example.com/api/v3/fn/ps/update --key YOUR_KEY
```

安装脚本会：下载最新 Release → 装 `/Applications` → 写配置（若给了参数）→ 配置开机自启并立即启动。

### 方式二：源码构建

1. 配置 `~/.config/chirp/config.json`（权限 600）。**最小可用只有两行** —— 其余字段都有内置默认值：

```json
{
  "endpoint": "https://your-blog.example.com/api/v3/fn/ps/update",
  "key": "与 snippet 一致的密钥"
}
```

想显式写全（也是官网「配置」节的推荐模板）：

```json
{
  "endpoint": "https://your-blog.example.com/api/v3/fn/ps/update",
  "key": "与 snippet 一致的密钥",
  "debounceSeconds": 3,
  "heartbeatSeconds": 240,
  "iconManifestUrl": "https://fastly.jsdelivr.net/gh/poboll/app-icons@main/manifest.json",
  "iconBase": "https://fastly.jsdelivr.net/gh/poboll/app-icons@main/icons"
}
```

一行命令写入（自动 600 权限）：

```bash
mkdir -p ~/.config/chirp && cat > ~/.config/chirp/config.json <<'EOF'
{ "endpoint": "https://your-blog.example.com/api/v3/fn/ps/update", "key": "YOUR_KEY" }
EOF
chmod 600 ~/.config/chirp/config.json
```

| 字段 | 默认 | 说明 |
|---|---|---|
| `endpoint` | 必填 | `ps/update` 函数完整地址，含 `/api/v3/fn/` 前缀 |
| `key` | 必填 | 与 snippet 内 `AUTH_KEY` 一致；不一致一律 401 |
| `debounceSeconds` | `3` | 切换应用后延迟上报，避免快速切换刷屏 |
| `heartbeatSeconds` | `240` | 心跳续期；服务端缓存 300 秒，须小于它 |
| `iconManifestUrl` | app-icons CDN | 应用名 → 图标清单，默认指向 [poboll/app-icons](https://github.com/poboll/app-icons) |
| `iconBase` | app-icons CDN | 图标 URL 前缀；未命中回落内嵌 data URI |

> 配置损坏时 chirp **不会覆盖**你的文件，只在菜单里提示；`iconManifestUrl` / `iconBase` 可以换成你自己的图标库，格式见 app-icons 的 `manifest.json`。

2. 构建安装：

```bash
sh scripts/build-app.sh            # 构建 + 组装 + 安装到 /Applications
sh scripts/install-launch-agent.sh # 开机自启动 + 立即运行
```

菜单栏的小鸟：单击看「当前应用 / 博客显示 / 上次上报结果」，`⌘P` 暂停，`⌘R` 立即刷新，`⌘,` 打开配置，`⌘H` 使用说明（[官网](https://poboll.github.io/chirp/)）。

### 服务端：一个 `ps/update` 函数

在 mx-space 后台 → Serverless 函数 → 新建，路径 `ps/update`、Method **POST**，逻辑就是「校验 key → 写缓存 → 应用名变化时广播」。完整 snippet（含读分支、缓存 TTL、WebSocket 广播）见[官网接入文档](https://poboll.github.io/chirp/#integration)，字段为 `{key, process:{name, iconUrl?, iconBase64?}}`。

## 图标从哪来

前端「正在使用」的应用图标按三层回落，绝大多数应用不需要任何手动配置：

1. **主题内置映射**：生态通用的 [Innei/reporter-assets](https://github.com/Innei/reporter-assets) 名称映射（Xcode、VS Code 等常见开发软件，含中文应用名）；
2. **app-icons CDN**：chirp 按 [poboll/app-icons](https://github.com/poboll/app-icons) 的 `manifest.json` 把应用名映射成 jsdelivr CDN 图标 URL 上报（约 240 个常见 macOS 应用，manifest 每日自动刷新）；
3. **data URI 兜底**：两者都未命中时，直接抓本机应用图标内嵌上报 —— 新装任何软件立即可用，等它进了 app-icons 仓库后自动切成 CDN 轻量模式。

想扩充 CDN 图标库：`swift scripts/ExportIcons.swift` 导出本机图标与 manifest，往 app-icons 仓库提 PR 即可。

## 开发

```bash
swift build            # 构建
swift run              # 本地跑
swift scripts/IconGen.swift build/AppIcon.iconset  # 重新生成圆角图标
```

图标遵循新版 macOS 标准：超椭圆（squircle）圆角矩形、约 10% 内边距、鼠尾草绿渐变 + 白色 `bird.fill` 剪影，与系统原生图标同一套观感。

## 致谢

- [Innei](https://github.com/Innei) —— [mx-space](https://github.com/mx-space) 生态、[Shiro](https://github.com/Innei/Shiro) 与 [Yohaku](https://github.com/Innei/Yohaku)、以及 [ProcessReporter](https://github.com/Innei/ProcessReporter)：原始创意、`ps/update` 契约与图标资源
- [mx-space/ProcessReporterMac](https://github.com/mx-space/ProcessReporterMac)（MIT）—— 上报器的直系祖先，chirp 的极简版蓝本
- [Innei/reporter-assets](https://github.com/Innei/reporter-assets) —— 应用图标与中文名映射

## License

MIT
