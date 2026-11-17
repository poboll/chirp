import Foundation

/// Never forward credentials through redirects, including HTTP downgrades.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Legacy fn and mx-core Companion presence v2. Mutable state stays on the main queue.
final class Reporter {
    private let config: Config
    private let session: URLSession
    private var sequence = UInt64(Date().timeIntervalSince1970 * 1000)
    private var generation = 0
    private var task: URLSessionDataTask?
    private(set) var lastReportedName: String?
    private(set) var lastSuccessAt: Date?
    private(set) var lastError: String?

    init(config: Config, session: URLSession? = nil) {
        self.config = config
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.httpAdditionalHeaders = ["User-Agent": "chirp/1.2.0"]
        self.session = session ?? URLSession(configuration: cfg, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }

    func invalidate() {
        generation += 1
        task?.cancel()
        session.invalidateAndCancel()
    }

    private func nextMeta() -> [String: Any] {
        sequence = max(sequence + 1, UInt64(Date().timeIntervalSince1970 * 1000))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ["schema": "yohaku.companion.presence", "schemaVersion": 2,
                "requestId": UUID().uuidString.lowercased(), "deviceId": config.deviceId,
                "sequence": sequence, "observedAt": formatter.string(from: Date())]
    }

    func makeReportRequest(appName: String, iconUrl: String?, iconBase64: String?) throws -> URLRequest {
        try config.validate()
        var request = URLRequest(url: URL(string: config.endpoint)!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any]
        if config.usesCompanion {
            request.httpMethod = "PUT"
            request.setValue("Bearer " + config.deviceToken, forHTTPHeaderField: "Authorization")
            // Companion wire compatibility level, independent of chirp's app version.
            request.setValue("1.7.3", forHTTPHeaderField: "x-yohaku-companion-version")
            var icon: Any = NSNull()
            if let value = iconUrl, let url = URL(string: value), url.scheme == "https", url.host != nil,
               url.user == nil, url.password == nil, value.utf8.count <= 2048 {
                icon = ["url": value]
            }
            let normalized = appName.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
            let name = String(String.UnicodeScalarView(normalized.unicodeScalars.prefix(120)))
            body = ["meta": nextMeta(), "data": ["availability": "active", "lease": ["ttlSeconds": 90],
                "application": ["displayName": name, "activity": NSNull(), "window": NSNull(), "icon": icon],
                "media": NSNull()]]
        } else {
            request.httpMethod = "POST"
            var process: [String: Any] = ["name": appName]
            process["iconUrl"] = iconUrl
            process["iconBase64"] = iconBase64
            body = ["process": process, "key": config.key, "timestamp": UInt64(Date().timeIntervalSince1970 * 1000)]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func report(appName: String, iconUrl: String? = nil, iconBase64: String? = nil, force: Bool = false,
                completion: ((Bool) -> Void)? = nil) {
        if !force && appName == lastReportedName && lastError == nil { return }
        do {
            let request = try makeReportRequest(appName: appName, iconUrl: iconUrl, iconBase64: iconBase64)
            send(request) { [weak self] ok in
                if ok { self?.lastReportedName = appName; self?.lastSuccessAt = Date() }
                completion?(ok)
            }
        } catch {
            lastError = error.localizedDescription
            completion?(false)
        }
    }

    /// Higher sequence fences older in-flight updates when pausing or sleeping.
    func clear(completion: @escaping (Bool) -> Void) {
        guard config.usesCompanion else { completion(true); return }
        var request = URLRequest(url: URL(string: config.endpoint + "/clear")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + config.deviceToken, forHTTPHeaderField: "Authorization")
        request.setValue("1.7.3", forHTTPHeaderField: "x-yohaku-companion-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["meta": nextMeta(), "data": ["reason": "paused"]])
        lastReportedName = nil
        send(request, completion: completion)
    }

    private func send(_ request: URLRequest, completion: @escaping (Bool) -> Void) {
        generation += 1
        let ticket = generation
        task?.cancel()
        task = session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self, self.generation == ticket else { return }
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                let failure = object?["error"] as? [String: Any]
                let value = Self.unwrap(object ?? [:])
                let accepted = self.config.usesCompanion ? value["acceptedSequence"] != nil : value["ok"] as? Int == 1
                let ok = error == nil && (200..<300).contains(code) && failure == nil && accepted
                // Stable error codes only; upstream messages could echo secrets.
                self.lastError = ok ? nil : (error != nil ? "网络连接失败" : "HTTP \(code) · \(failure?["code"] as? String ?? "响应格式不匹配")")
                if let acceptedSequence = failure?["acceptedSequence"] as? UInt64 {
                    self.sequence = max(self.sequence, acceptedSequence)
                }
                completion(ok)
            }
        }
        task?.resume()
    }

    /// Functions can be raw, enveloped, or wrapped twice after a core upgrade.
    static func unwrap(_ object: [String: Any]) -> [String: Any] {
        var value = object
        for _ in 0..<3 {
            if let data = value["data"] as? [String: Any] { value = data } else { break }
        }
        return value
    }

    static func remoteName(from object: [String: Any], companion: Bool) -> String? {
        let value = unwrap(object)
        if companion {
            guard let state = value["state"] as? [String: Any], let projection = state["projection"] as? [String: Any],
                  let expiry = projection["expiresAt"] as? String else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: expiry), date > Date() else { return nil }
            return (projection["application"] as? [String: Any])?["displayName"] as? String
        }
        return value["processName"] as? String ?? value["process_name"] as? String
            ?? (value["processInfo"] as? [String: Any])?["name"] as? String
            ?? (value["process_info"] as? [String: Any])?["name"] as? String
    }

    func fetchRemoteState(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: config.endpoint + (config.usesCompanion ? "/public" : "")) else { completion(nil); return }
        var request = URLRequest(url: url)
        request.httpMethod = config.usesCompanion ? "GET" : "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if !config.usesCompanion {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)
        }
        session.dataTask(with: request) { [weak self] data, response, _ in
            let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let name = (response as? HTTPURLResponse)?.statusCode == 200
                ? object.flatMap { Self.remoteName(from: $0, companion: self?.config.usesCompanion == true) } : nil
            DispatchQueue.main.async { completion(name) }
        }.resume()
    }
}
