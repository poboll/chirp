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

    /// 前台应用图标 → 64px PNG base64（主题端有图标才会渲染"正在使用"）。
    var frontmostIconBase64: String? {
        guard let app = NSWorkspace.shared.frontmostApplication,
            let icon = app.icon
        else { return nil }
        let side: CGFloat = 64
        let size = NSSize(width: side, height: side)
        let img = NSImage(size: size)
        img.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: size),
                  from: .zero, operation: .copy, fraction: 1)
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        // The theme drops this string straight into <img src>, so it must
        // be a data URI — raw base64 renders as a broken image.
        return "data:image/png;base64," + png.base64EncodedString()
    }
}
