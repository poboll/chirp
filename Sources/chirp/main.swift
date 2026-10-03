import AppKit
import Foundation

// chirp. — 报信小鸟：把「正在使用的软件」汇报给博客的菜单栏应用。
// 零依赖、纯 AppKit。对上游 ProcessReporter 的轻量化重写。

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var observer = Observer()
    private var reporter: Reporter!
    private var config: Config!

    private var debounceTimer: Timer?
    private var heartbeatTimer: Timer?
    private var paused = false
    private(set) var currentApp: String?
    private(set) var remoteApp: String?
    private(set) var lastResult: String = "未上报"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let config = Config.load() else {
            let path = Config.writeTemplate()
            showAlert(
                "chirp. 需要配置",
                "已生成配置模板：\(path)\n请填入 endpoint 与 key 后重新打开 chirp.。"
            )
            NSApp.terminate(nil)
            return
        }
        self.config = config
        reporter = Reporter(config: config)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "chirp")
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
        let icon = observer.frontmostIconBase64
        reporter.report(appName: appName, iconBase64: icon, force: force) { [weak self] ok in
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

        let title = NSMenuItem(
            title: "chirp. 报信小鸟",
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

        let refreshItem = NSMenuItem(
            title: "立即刷新",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        )
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(.separator())

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
