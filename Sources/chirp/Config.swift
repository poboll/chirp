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

    static func load() -> Config? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: data)
    }

    static func writeTemplate() -> String {
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
