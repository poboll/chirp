import Foundation

/// 图标来源决策：优先 CDN（poboll/app-icons via jsdelivr），未命中的应用回落内嵌 data URI。
/// manifest 每天刷新一次，失败静默降级（下一次上报仍可用旧缓存或 data URI）。
final class IconProvider {
    private let config: Config
    private let session: URLSession
    private(set) var knownSlugs: Set<String> = []
    private var lastFetchAt: Date?

    init(config: Config) {
        self.config = config
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 8
        self.session = URLSession(configuration: cfg)
    }

    func refreshManifestIfNeeded() {
        if let last = lastFetchAt, Date().timeIntervalSince(last) < 86_400 { return }
        guard let url = URL(string: config.iconManifestUrl) else { return }
        let task = session.dataTask(with: url) { [weak self] data, response, _ in
            guard let data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let apps = obj["apps"] as? [String: String]
            else { return }
            self?.knownSlugs = Set(apps.values)
            self?.lastFetchAt = Date()
        }
        task.resume()
    }

    /// 命中 CDN 时返回 (url, nil)；否则 (nil, dataURI)。
    func icon(forApp name: String, localFallback: String?) -> (url: String?, base64: String?) {
        refreshManifestIfNeeded()
        let slug = iconSlug(name)
        if !slug.isEmpty && knownSlugs.contains(slug) {
            return ("\(config.iconBase)/\(slug).png", nil)
        }
        return (nil, localFallback)
    }
}
