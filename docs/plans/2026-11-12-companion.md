# Companion 接入与运行状态修复计划

**Goal:** 恢复新版博客的前台应用上报，明确菜单栏状态，同步 README、截图与官网。

**Architecture:** 按 endpoint 路径选择旧 ps/update 或 Companion v2。两套凭据分开；不猜测接口、不在未知地址试发凭据。保留 AppKit 与零第三方依赖。

**Tech Stack:** Swift 5.9、AppKit、URLSession、XCTest、静态 HTML。

1. Config / Reporter：可选字段默认值、HTTPS 验证、v2 schema、独立设备令牌、30s 心跳与90s租约、递增序号、清除状态、读取新旧 envelope、拒绝重定向。
2. AppDelegate / Observer：绿色成功、橙色等待或暂停、红色失败；菜单区分服务端状态与网页渲染；刷新重读配置；睡眠清除；正常退出不被 LaunchAgent 拉起。
3. 验证：XCTest 覆盖最小配置、新旧请求、envelope、假200响应、序号、过期状态、清除与重定向；release 构建与签名检查。
4. 本机迁移：备份旧app与配置；仅授权 companion:presence:write；读回上报、应用切换、心跳、暂停与继续。
5. README / 官网：按协议提供配置和排错，实拍菜单截图，明确截图与状态示意；静态资源与移动布局检查；发布后读回。

不采集窗口标题、键盘内容、截图或媒体；Companion 不支持内嵌 data URI 图标，未命中 CDN 时只上报名称。旧函数500作为迁移前事实记录，不把未修改的函数声称已修好。
