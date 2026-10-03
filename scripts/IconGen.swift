import AppKit
import Foundation

// 生成 chirp. 应用图标：鼠尾草绿圆角矩形 + 白色小鸟剪影。
// 输出 iconset 目录（含全部标准尺寸），供 iconutil 转 icns。

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

func drawIcon(px: Int) -> NSImage {
    let size = NSSize(width: px, height: px)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)

    // 背景渐变：鼠尾草绿（呼应博客的花园气质）
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.55, green: 0.66, blue: 0.52, alpha: 1),
            NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.42, alpha: 1),
        ]
    )!
    gradient.draw(in: rect, angle: -90)

    // 小鸟剪影（模板符号直接上色，保持几何简洁）
    let config = NSImage.SymbolConfiguration(
        pointSize: CGFloat(px) * 0.58,
        weight: .bold
    )
    if let bird = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        // 手动上白：锁定焦点后先铺白色再叠模板图
        let birdSize = bird.size
        let tintImage = NSImage(size: birdSize)
        tintImage.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: birdSize).fill()
        bird.draw(
            in: NSRect(origin: .zero, size: birdSize),
            from: .zero,
            operation: .destinationIn,
            fraction: 1
        )
        tintImage.unlockFocus()

        let birdRect = NSRect(
            x: rect.midX - birdSize.width / 2,
            y: rect.midY - birdSize.height / 2,
            width: birdSize.width,
            height: birdSize.height
        )
        tintImage.draw(in: birdRect)
    }

    image.unlockFocus()
    return image
}

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for (px, name) in sizes {
    let image = drawIcon(px: px)
    let path = (outputDir as NSString).appendingPathComponent(name)
    guard let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else { continue }
    try? png.write(to: URL(fileURLWithPath: path))
}
print("icons written to \(outputDir)")
