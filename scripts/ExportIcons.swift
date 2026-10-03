import AppKit
import Foundation

// 导出本机全部应用图标 → icons/*.png + manifest.json
// 用法: swift scripts/ExportIcons.swift <输出目录>
// 供应 poboll/app-icons 仓库，chirp 通过 jsdelivr 引用。

func slug(_ name: String) -> String {
    // 保留中英数字与 +.#，其余折叠为 _，避免 CDN/URL 特殊字符问题
    var out = ""
    var lastUnderscore = false
    for ch in name {
        if ch.isLetter || ch.isNumber || "+.#".contains(ch) {
            out.append(ch)
            lastUnderscore = false
        } else if !lastUnderscore {
            out.append("_")
            lastUnderscore = true
        }
    }
    var result = out
    while result.hasPrefix("_") { result.removeFirst() }
    while result.hasSuffix("_") { result.removeLast() }
    return result
}

func exportIcon(appURL: URL, name: String, size: CGFloat, to dir: URL) -> String? {
    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    let nsSize = NSSize(width: size, height: size)
    let img = NSImage(size: nsSize)
    img.lockFocus()
    icon.draw(in: NSRect(origin: .zero, size: nsSize), from: .zero, operation: .copy, fraction: 1)
    img.unlockFocus()
    guard let tiff = img.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [.compressionFactor: 0.9])
    else { return nil }
    let fileSlug = slug(name)
    guard !fileSlug.isEmpty else { return nil }
    let url = dir.appendingPathComponent(fileSlug + ".png")
    try? png.write(to: url)
    return fileSlug
}

let outputDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "app-icons-export")
let iconsDir = outputDir.appendingPathComponent("icons", isDirectory: true)
try? FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)

// 用户应用 + 系统应用 + 当前运行的应用（覆盖 CLI/菜单栏等无 .app 常驻路径的特殊情况）
var appURLs = [URL]()
let searchRoots = [
    "/Applications",
    "/System/Applications",
    "\(NSHomeDirectory())/Applications",
    "/Applications/Setapp",
]
for root in searchRoots {
    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(atPath: root) else { continue }
    for item in items where item.hasSuffix(".app") {
        appURLs.append(URL(fileURLWithPath: root).appendingPathComponent(item))
    }
}

var manifest: [String: String] = [:]  // appName -> slug
var seen = Set<URL>()
for appURL in appURLs {
    if !seen.insert(appURL).inserted { continue }
    let name = appURL.deletingPathExtension().lastPathComponent
    if let s = exportIcon(appURL: appURL, name: name, size: 128, to: iconsDir) {
        manifest[name] = s
    }
}
// 运行中的应用（含菜单栏工具）
for running in NSWorkspace.shared.runningApplications {
    guard let bundleURL = running.bundleURL, let name = running.localizedName else { continue }
    if seen.contains(bundleURL) { continue }
    if seen.insert(bundleURL).inserted,
        let s = exportIcon(appURL: bundleURL, name: name, size: 128, to: iconsDir)
    {
        manifest[name] = s
    }
}

let manifestData = try! JSONSerialization.data(
    withJSONObject: ["apps": manifest, "generatedAt": ISO8601DateFormatter().string(from: Date())],
    options: [.prettyPrinted, .sortedKeys]
)
try! manifestData.write(to: outputDir.appendingPathComponent("manifest.json"))
print("exported \(manifest.count) icons -> \(iconsDir.path)")
