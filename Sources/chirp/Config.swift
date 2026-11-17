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
    var deviceId: String = ""
    var deviceToken: String = ""

    var usesCompanion: Bool { URL(string: endpoint)?.path.hasSuffix("/companion/presence") == true }
    var effectiveHeartbeat: Double { usesCompanion ? min(heartbeatSeconds, 30) : heartbeatSeconds }
    var backendName: String { usesCompanion ? "Companion v2" : "云函数 ps/update" }

    enum CodingKeys: String, CodingKey {
        case endpoint, key, debounceSeconds, heartbeatSeconds, iconManifestUrl, iconBase, deviceId, deviceToken
    }

    init(endpoint: String, key: String = "", deviceId: String = "", deviceToken: String = "") {
        self.endpoint = endpoint
        self.key = key
        self.deviceId = deviceId
        self.deviceToken = deviceToken
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        endpoint = try c.decode(String.self, forKey: .endpoint)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
        deviceId = try c.decodeIfPresent(String.self, forKey: .deviceId) ?? ""
        deviceToken = try c.decodeIfPresent(String.self, forKey: .deviceToken) ?? ""
        debounceSeconds = try c.decodeIfPresent(Double.self, forKey: .debounceSeconds) ?? 3
        heartbeatSeconds = try c.decodeIfPresent(Double.self, forKey: .heartbeatSeconds) ?? (usesCompanion ? 30 : 240)
        iconManifestUrl = try c.decodeIfPresent(String.self, forKey: .iconManifestUrl) ?? iconManifestUrl
        iconBase = try c.decodeIfPresent(String.self, forKey: .iconBase) ?? iconBase
        try validate()
    }

    func validate() throws {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else {
            throw ValidationError.invalid("endpoint 必须是完整 HTTPS 地址，不能包含凭据或查询参数")
        }
        guard debounceSeconds.isFinite, debounceSeconds >= 0,
              heartbeatSeconds.isFinite, heartbeatSeconds > 0, heartbeatSeconds < 300 else {
            throw ValidationError.invalid("debounceSeconds 须 ≥ 0，heartbeatSeconds 须在 0 到 300 秒之间")
        }
        if usesCompanion {
            guard UUID(uuidString: deviceId) != nil, !deviceToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.invalid("Companion 需要配对所得的 deviceId 与 deviceToken，旧 key 不能通用")
            }
        } else if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.invalid("云函数模式需要 key")
        }
    }

    enum ValidationError: LocalizedError {
        case invalid(String)
        var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
    }

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
            return .corrupted(error.localizedDescription)
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
