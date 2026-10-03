import Foundation

/// 向 mx-space 的 ps/update fn snippet 上报当前前台应用。
/// 契约（与服务器 snippet v3 对齐）：
///   POST {key, timestamp, process: {name, description?}}
///   空 body 的 POST 等价于读取当前状态。
final class Reporter {
    private let config: Config
    private let session: URLSession
    private(set) var lastReportedName: String?
    private(set) var lastSuccessAt: Date?
    private(set) var lastError: String?

    init(config: Config) {
        self.config = config
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.httpAdditionalHeaders = ["User-Agent": "chirp/1.0"]
        self.session = URLSession(configuration: cfg)
    }

    struct Payload: Codable {
        struct Process: Codable {
            var name: String
            var description: String?
            var iconBase64: String?
        }
        var process: Process
        var key: String
        var timestamp: UInt
    }

    /// 上报；同名应用静默跳过（force 用于心跳续期）。
    func report(appName: String, iconBase64: String? = nil, force: Bool = false, completion: ((Bool) -> Void)? = nil) {
        if !force && appName == lastReportedName {
            completion?(true)
            return
        }
        guard let url = URL(string: config.endpoint) else {
            lastError = "端点无效"
            completion?(false)
            return
        }

        let payload = Payload(
            process: .init(name: appName, description: nil, iconBase64: iconBase64),
            key: config.key,
            timestamp: UInt(max(0, Date().timeIntervalSince1970))
        )
        let body = (try? JSONEncoder().encode(payload)) ?? Data()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let task = session.dataTask(with: request) { [weak self] _, response, error in
            let ok: Bool
            if let error {
                ok = false
                self?.lastError = error.localizedDescription
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                ok = (200..<300).contains(code)
                self?.lastError = ok ? nil : "HTTP \(code)"
            }
            if ok {
                self?.lastReportedName = appName
                self?.lastSuccessAt = Date()
            }
            DispatchQueue.main.async { completion?(ok) }
        }
        task.resume()
    }

    /// 读取服务器当前缓存的状态（用于菜单显示远端视角）。
    func fetchRemoteState(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: config.endpoint) else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let task = session.dataTask(with: request) { data, response, _ in
            guard let data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let processName = obj["processName"] as? String
            else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(processName) }
        }
        task.resume()
    }
}
