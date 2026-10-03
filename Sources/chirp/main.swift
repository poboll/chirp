import AppKit
import Foundation

// chirp. — 报信小鸟：把「正在使用的软件」汇报给博客的菜单栏应用。
// 零依赖、纯 AppKit。对上游 ProcessReporter 的轻量化重写。

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var observer = Observer()
    private var reporter: Reporter!
    private var iconProvider: IconProvider!
    private var config: Config!

    private var debounceTimer: Timer?
    private var heartbeatTimer: Timer?
    private var paused = false
    private(set) var currentApp: String?
    private(set) var remoteApp: String?
    private(set) var lastResult: String = "未上报"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config: Config
        switch Config.loadResult() {
        case .ok(let c):
            config = c
        case .missing:
            let path = Config.writeTemplate()
            showAlert(
                "chirp. 需要配置",
                "已生成配置模板：\(path)\n请填入 endpoint 与 key 后重新打开 chirp.。"
            )
            NSApp.terminate(nil)
            return
        case .corrupted(let reason):
            showAlert(
                "chirp. 配置文件损坏",
                "\(Config.configURL.path)\n\(reason)\n\n为避免覆盖，chirp 没有修改这个文件；请修复后重开。"
            )
            NSApp.terminate(nil)
            return
        }
        self.config = config
        reporter = Reporter(config: config)
        iconProvider = IconProvider(config: config)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let cfg = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            let icon = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "chirp")?
                .withSymbolConfiguration(cfg)
            icon?.isTemplate = true
            button.image = icon
            button.imageScaling = .scaleProportionallyUpOrDown
        }
        rebuildMenu()

        observer.onAppChange = { [weak self] name in
            self?.scheduleReport(appName: name)
        }
        observer.onWake = { [weak self] in
            guard let self, let name = self.observer.frontmostName else { return }
            self.reportNow(appName: name, force: true)
        }
        observer.start()

        heartbeatTimer = Timer.scheduledTimer(
            withTimeInterval: config.heartbeatSeconds,
            repeats: true
        ) { [weak self] _ in
            guard let self, !self.paused, let name = self.observer.frontmostName else { return }
            self.reportNow(appName: name, force: true)
        }

        // 启动即上报当前应用
        log("launched, frontmost=\(observer.frontmostName ?? "nil") paused=\(paused)")
        if let name = observer.frontmostName {
            reportNow(appName: name, force: true)
        } else {
            log("frontmost 为空，未上报")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        observer.stop()
    }

    // MARK: - 上报

    private func scheduleReport(appName: String) {
        currentApp = appName
        debounceTimer?.invalidate()
        guard !paused else { return }
        debounceTimer = Timer.scheduledTimer(
            withTimeInterval: config.debounceSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.reportNow(appName: appName)
        }
    }

    private func reportNow(appName: String, force: Bool = false) {
        guard !paused else { return }
        currentApp = appName
        let local = observer.frontmostIconBase64
        let (url, base64) = iconProvider.icon(forApp: appName, bundleName: observer.frontmostBundleName, localFallback: local)
        reporter.report(appName: appName, iconUrl: url, iconBase64: base64, force: force) { [weak self] ok in
            guard let self else { return }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            self.lastResult = ok
                ? "已上报 \(formatter.string(from: Date()))"
                : "失败：\(self.reporter.lastError ?? "未知错误")"
            log("report \(appName) ok=\(ok) err=\(self.reporter.lastError ?? "-")")
            self.statusItem.button?.contentTintColor = ok ? nil : .systemRed
            self.rebuildMenu()
            if ok {
                self.refreshRemoteState()
            }
        }
    }

    private func refreshRemoteState() {
        reporter.fetchRemoteState { [weak self] name in
            guard let self else { return }
            self.remoteApp = name
            self.rebuildMenu()
        }
    }

    // MARK: - 菜单

    private func rebuildMenu() {
        let menu = NSMenu()

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let title = NSMenuItem(
            title: "chirp. 报信小鸟 v\(version)",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(title)
        menu.addItem(.separator())

        let appItem = NSMenuItem(
            title: "当前应用：\(currentApp ?? "—")",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(appItem)
        let remoteItem = NSMenuItem(
            title: "博客显示：\(remoteApp ?? "—")",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(remoteItem)
        let statusItem = NSMenuItem(
            title: "状态：\(lastResult)",
            action: nil,
            keyEquivalent: ""
        )
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let pauseItem = NSMenuItem(
            title: paused ? "继续上报" : "暂停上报",
            action: #selector(togglePause),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let configItem = NSMenuItem(
            title: "打开配置文件",
            action: #selector(openConfig),
            keyEquivalent: ","
        )
        configItem.target = self
        menu.addItem(configItem)

        let refreshItem = NSMenuItem(
            title: "立即刷新",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

        menu.addItem(.separator())
        let helpItem = NSMenuItem(
            title: "使用说明",
            action: #selector(openHelp),
            keyEquivalent: "h"
        )
        helpItem.target = self
        menu.addItem(helpItem)
        let aboutItem = NSMenuItem(
            title: "关于 chirp.",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)
        let repoItem = NSMenuItem(
            title: "GitHub 仓库",
            action: #selector(openRepo),
            keyEquivalent: ""
        )
        repoItem.target = self
        menu.addItem(repoItem)

        let quitItem = NSMenuItem(
            title: "退出 chirp.",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func togglePause() {
        paused.toggle()
        if paused {
            debounceTimer?.invalidate()
        } else if let name = observer.frontmostName {
            reportNow(appName: name, force: true)
        }
        rebuildMenu()
    }

    @objc private func refreshNow() {
        if let name = observer.frontmostName, !paused {
            reportNow(appName: name, force: true)
        } else {
            refreshRemoteState()
        }
    }

    @objc private func openConfig() {
        let url = Config.configURL
        if !FileManager.default.fileExists(atPath: url.path) {
            _ = Config.writeTemplate()
        }
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }

    @objc private func openHelp() {
        NSWorkspace.shared.open(URL(string: "https://poboll.github.io/chirp/")!)
    }

    @objc private func openRepo() {
        NSWorkspace.shared.open(URL(string: "https://github.com/poboll/chirp")!)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "1.0",
                .version: "",
                .credits: "报信小鸟 —— 把「正在使用的软件」实时汇报给你的博客。\n零依赖 · 纯 AppKit · MIT",
            ]
        )
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()


/// 调试日志直写 stderr（无缓冲，LaunchAgent 下可用 log stream 观察）。
func log(_ message: String) {
    FileHandle.standardError.write(Data(("[chirp] " + message + "\n").utf8))
}
