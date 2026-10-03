import Foundation

/// ~/.config/chirp/config.json
struct Config: Codable {
    /// 上报端点，指向 mx-space 的 fn snippet
    var endpoint: String
    /// 上报密钥（与 snippet 内嵌密钥一致）
    var key: String
    /// 切换应用后延迟上报的秒数（防抖）
    var debounceSeconds: Double = 3
    /// 心跳间隔秒数（snippet 缓存 300 秒，保持略短于它）
    var heartbeatSeconds: Double = 240
    /// 应用图标 CDN（poboll/app-icons + jsdelivr）；命中的应用发轻量 URL，未命中回落内嵌图标
    var iconManifestUrl: String = "https://fastly.jsdelivr.net/gh/poboll/app-icons@main/manifest.json"
    var iconBase: String = "https://fastly.jsdelivr.net/gh/poboll/app-icons@main/icons"

    static let configURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/chirp/config.json")

    /// 读取结果：正常 / 文件不存在 / 文件损坏（损坏时绝不覆盖原文件）
    enum LoadResult {
        case ok(Config)
        case missing
        case corrupted(String)
    }

    static func loadResult() -> LoadResult {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return .missing }
        guard let data = try? Data(contentsOf: configURL) else {
            return .corrupted("无法读取文件")
        }
        do {
            return .ok(try JSONDecoder().decode(Config.self, from: data))
        } catch {
            return .corrupted(String(describing: error))
        }
    }

    static func load() -> Config? {
        if case .ok(let c) = loadResult() { return c }
        return nil
    }

    /// 仅在文件不存在时写入模板；已存在（哪怕损坏）一律不动，返回路径供提示。
    @discardableResult
    static func writeTemplate() -> String {
        if FileManager.default.fileExists(atPath: configURL.path) { return configURL.path }
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let template = Config(endpoint: "https://example.com/api/v3/fn/ps/update", key: "your-key-here")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(template)) ?? Data()
        try? data.write(to: configURL, options: [.atomic as Data.WritingOptions])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
        return configURL.path
    }
}
