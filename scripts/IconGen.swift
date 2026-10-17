import AppKit
import Foundation

// 生成 chirp. 应用图标：鼠尾草绿圆角矩形 + 白色小鸟剪影。
// 遵循 macOS 标准图标网格（Big Sur 起的圆角矩形）：
//   - 1024 画布，内容体占据 824×824（约 80.5%，四周留白 ~9.8%）
//   - 圆角采用连续曲率（squircle，Apple 图标的标准形状），近似圆角半径 ≈ 内容体的 22.5%
//   - 透明留白，Finder / Dock / 应用程序文件夹里就是标准大小，不再是铺满画布的方块
// 输出 iconset 目录（含全部标准尺寸），供 iconutil 转 icns。

/// Apple 图标的标准“squircle”轮廓（超椭圆，指数 n≈5）。
/// 沿 0..2π 采样一圈，数学上保证形状正确。
func squirclePath(in rect: NSRect, samples: Int = 128) -> NSBezierPath {
    let a = rect.width / 2
    let b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let n: Double = 5.0
    let m = 2.0 / n
    let path = NSBezierPath()
    for i in 0...samples {
        let t = Double(i) / Double(samples) * (.pi * 2) // 完整一圈
        let cosT = cos(t), sinT = sin(t)
        let px = a * pow(abs(cosT), m) * (cosT >= 0 ? 1 : -1)
        let py = b * pow(abs(sinT), m) * (sinT >= 0 ? 1 : -1)
        let pt = NSPoint(x: cx + px, y: cy + py)
        if i == 0 { path.move(to: pt) } else { path.line(to: pt) }
    }
    path.close()
    return path
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

/// 把白色模板符号（如 bird.fill）染成指定颜色。
func tint(_ image: NSImage, color: NSColor) -> NSImage {
    let size = image.size
    let out = NSImage(size: size)
    out.lockFocus()
    color.setFill()
    NSRect(origin: .zero, size: size).fill()
    image.draw(in: NSRect(origin: .zero, size: size),
               from: .zero, operation: .destinationIn, fraction: 1)
    out.unlockFocus()
    return out
}

func drawIcon(px: Int) -> NSImage {
    let size = NSSize(width: px, height: px)
    let image = NSImage(size: size)
    image.lockFocus()

    let full = NSRect(origin: .zero, size: size)

    // 内容体：占据画布的 80.5%，四周留白 ~9.77%
    let content = px == 16 ? 13 : (px == 32 ? 26 : (px == 128 ? 103 : Int(Double(px) * 824.0 / 1024.0)))
    let inset = (px - content) / 2
    let bodyRect = NSRect(x: inset, y: inset, width: content, height: content)
    let body = squirclePath(in: bodyRect)

    // 裁切到圆角形状
    body.addClip()

    // 背景渐变：鼠尾草绿（呼应博客的花园气质），顶部偏亮、底部偏深
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.58, green: 0.69, blue: 0.55, alpha: 1),
            NSColor(calibratedRed: 0.40, green: 0.53, blue: 0.39, alpha: 1),
        ]
    )!
    gradient.draw(in: full, angle: -90)

    // 顶部柔光（macOS 图标的轻量高光）
    let glow = NSGradient(
        colors: [
            NSColor(white: 1, alpha: 0.28),
            NSColor(white: 1, alpha: 0.0),
        ]
    )!
    let glowRect = NSRect(x: bodyRect.origin.x, y: bodyRect.origin.y + bodyRect.height * 0.45,
                          width: bodyRect.width, height: bodyRect.height * 0.55)
    glow.draw(in: glowRect, angle: -90)

    // 白色小鸟剪影（模板符号），尺寸约内容体的 56%
    let symSize = CGFloat(content) * 0.56
    let config = NSImage.SymbolConfiguration(pointSize: symSize, weight: .bold)
    if let bird = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let birdTinted = tint(bird, color: .white)
        let b = birdTinted.size
        let birdRect = NSRect(x: bodyRect.midX - b.width / 2,
                              y: bodyRect.midY - b.height / 2,
                              width: b.width, height: b.height)
        birdTinted.draw(in: birdRect)
    }

    // 内容体描边：细且淡，增加图标的“边缘感”
    body.lineWidth = max(1, CGFloat(px) / 512)
    NSColor(white: 1, alpha: 0.10).setStroke()
    body.stroke()

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
