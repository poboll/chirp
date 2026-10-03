# chirp.

> 报信小鸟 🐦 —— 把「正在使用的软件」实时汇报给你的博客。

![icon](assets/icon.png)

`chirp.` 是一个 macOS 菜单栏应用：看着你正在用什么软件，叽叽喳喳地告诉博客。访客打开你的页面，导航栏上就会显示「正在使用 Xcode」这样的实时状态。

灵感来自 Innei 的 [ProcessReporter](https://github.com/Innei/ProcessReporter)（及其前身 mx-space/ProcessReporterMac），但只想留下一件事：**报信**。没有 Slack、没有 Discord、没有 S3，一只小鸟就够。

## 特性

- **轻**：纯 AppKit + Swift Package，零第三方依赖，release 二进制约 200KB
- **省**：只在应用切换时上报（3 秒防抖），每 4 分钟心跳续期一次（服务端缓存 5 分钟）
- **稳**：睡眠唤醒自动补报、失败菜单栏图标变红、`KeepAlive` 常驻
- **静**：`LSUIElement` 无 Dock 图标，只住菜单栏

## 工作方式

```text
切换应用 ──防抖 3s──▶ POST /api/v3/fn/ps/update
                        {key, timestamp, process: {name}}
                              │
                              ▼
              mx-space snippet 缓存 5 分钟 + WebSocket 广播
                              │
                              ▼
              博客导航栏「正在使用 XX」（Shiro / Yohaku 主题）
```

## 使用

1. 准备 mx-space 的 `ps/update` fn snippet（Shiro 官方生态自带，主题配置 `module.activity.endpoint`）
2. 配置 `~/.config/chirp/config.json`（权限 600）：

```json
{
  "endpoint": "https://your-blog.example.com/api/v3/fn/ps/update",
  "key": "与 snippet 一致的密钥",
  "debounceSeconds": 3,
  "heartbeatSeconds": 240
}
```

3. 构建安装：

```bash
sh scripts/build-app.sh            # 构建 + 组装 + 安装到 /Applications
sh scripts/install-launch-agent.sh # 开机自启动 + 立即运行
```

菜单栏的小鸟：单击看「当前应用 / 博客显示 / 上次上报结果」，`⌘P` 暂停，`⌘R` 立即刷新。

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
