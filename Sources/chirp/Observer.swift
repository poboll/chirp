import AppKit
import Foundation

/// 监听前台应用切换 + 睡眠/唤醒。
final class Observer {
    var onAppChange: ((String) -> Void)?
    var onWake: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let activate = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let name = app.localizedName
            else { return }
            self?.onAppChange?(name)
        }
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onWake?()
        }
        observers = [activate, wake]
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
    }

    var frontmostName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
