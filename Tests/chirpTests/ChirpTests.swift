import XCTest
@testable import chirp

final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, body) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: code,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class ChirpTests: XCTestCase {
    let legacy = Config(endpoint: "https://example.com/api/v3/fn/ps/update", key: "test-only")
    var companion: Config { Config(endpoint: "https://example.com/api/v3/companion/presence",
        deviceId: "01a1cfb4-00a9-7bd3-94b2-384bbf85da80", deviceToken: "test-device-token") }
    func decode(_ json: String) throws -> Config { try JSONDecoder().decode(Config.self, from: Data(json.utf8)) }
    func object(_ request: URLRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    }
    func mockSession() -> URLSession {
        let c = URLSessionConfiguration.ephemeral
        c.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: c)
    }

    func testRetriesBackOffAndResetAfterRecovery() {
        var retry = RetryBackoff()
        XCTAssertEqual((0..<8).map { _ in retry.nextDelay() }, [5, 10, 20, 40, 60, 60, 60, 60])
        retry.reset()
        XCTAssertEqual(retry.nextDelay(), 5)
    }

    func testMinimalLegacyConfigUsesDocumentedDefaults() throws {
        let c = try decode(#"{"endpoint":"https://example.com/api/v3/fn/ps/update","key":"test"}"#)
        XCTAssertFalse(c.usesCompanion)
        XCTAssertEqual(c.heartbeatSeconds, 240)
        XCTAssertEqual(c.debounceSeconds, 3)
        XCTAssertTrue(c.iconBase.hasPrefix("https://"))
    }
    func testPartialConfigKeepsUnspecifiedDefaults() throws {
        let c = try decode(#"{"endpoint":"https://example.com/api/v3/fn/ps/update","key":"test","debounceSeconds":1}"#)
        XCTAssertEqual(c.debounceSeconds, 1)
        XCTAssertEqual(c.heartbeatSeconds, 240)
    }
    func testCompanionDefaultAndMigratedHeartbeat() throws {
        let data = try JSONEncoder().encode(companion)
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        obj.removeValue(forKey: "heartbeatSeconds")
        let c = try JSONDecoder().decode(Config.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertEqual(c.effectiveHeartbeat, 30)
        var migrated = companion
        migrated.heartbeatSeconds = 240
        XCTAssertEqual(migrated.effectiveHeartbeat, 30)
    }
    func testCompanionRejectsOldKeyWithoutDevicePairing() {
        XCTAssertThrowsError(try Config(endpoint: companion.endpoint, key: "old-key").validate())
    }
    func testInvalidEndpointsAndTimersAreRejected() {
        for endpoint in ["http://example.com/a", "https://user:pass@example.com/a", "https://example.com/a?token=secret", "invalid"] {
            XCTAssertThrowsError(try Config(endpoint: endpoint, key: "test").validate())
        }
        var c = legacy
        c.heartbeatSeconds = 300
        XCTAssertThrowsError(try c.validate())
        c.heartbeatSeconds = 240; c.debounceSeconds = -1
        XCTAssertThrowsError(try c.validate())
    }
    func testLegacyWireContractAndMilliseconds() throws {
        let r = try Reporter(config: legacy).makeReportRequest(appName: "Arc", iconUrl: nil, iconBase64: "data:image/png;base64,AA")
        let b = try object(r)
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertNil(r.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(b["key"] as? String, "test-only")
        XCTAssertGreaterThan(b["timestamp"] as! UInt64, 1_000_000_000_000)
        XCTAssertEqual((b["process"] as! [String: Any])["iconBase64"] as? String, "data:image/png;base64,AA")
    }
    func testCompanionWireContractDoesNotSendLegacyKeyOrBase64OrWindowTitle() throws {
        let reporter = Reporter(config: companion)
        let r = try reporter.makeReportRequest(appName: "  Cafe\u{301}  ", iconUrl: "https://cdn.example.com/a.png", iconBase64: "private-data")
        let b = try object(r), d = b["data"] as! [String: Any], a = d["application"] as! [String: Any]
        XCTAssertEqual(r.httpMethod, "PUT")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Authorization"), "Bearer test-device-token")
        XCTAssertEqual(r.value(forHTTPHeaderField: "x-yohaku-companion-version"), "1.7.3")
        XCTAssertEqual(a["displayName"] as? String, "Café")
        XCTAssertTrue(a["window"] is NSNull)
        XCTAssertTrue(d["media"] is NSNull)
        XCTAssertEqual((d["lease"] as! [String: Any])["ttlSeconds"] as? Int, 90)
        XCTAssertNil(b["key"])
        XCTAssertFalse(String(data: r.httpBody!, encoding: .utf8)!.contains("private-data"))
        let second = try object(reporter.makeReportRequest(appName: "Arc", iconUrl: nil, iconBase64: nil))
        XCTAssertGreaterThan((second["meta"] as! [String: Any])["sequence"] as! UInt64,
                             (b["meta"] as! [String: Any])["sequence"] as! UInt64)
    }
    func testCompanionRejectsNonHTTPSIconWithoutLosingApp() throws {
        for icon in ["data:image/png;base64,AA", "http://example.com/a.png", "https://user:pass@example.com/a.png"] {
            let b = try object(Reporter(config: companion).makeReportRequest(appName: "Arc", iconUrl: icon, iconBase64: nil))
            XCTAssertTrue(((b["data"] as! [String: Any])["application"] as! [String: Any])["icon"] is NSNull)
        }
    }
    func testLegacyRemoteEnvelopeVariants() {
        for obj: [String: Any] in [["processName": "Arc"], ["data": ["processName": "Arc"]],
            ["data": ["code": 200, "data": ["processInfo": ["name": "Arc"]]]],
            ["data": ["process_name": "Arc"]]] {
            XCTAssertEqual(Reporter.remoteName(from: obj, companion: false), "Arc")
        }
    }
    func testCompanionIgnoresExpiredProjection() {
        let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for seconds: Double in [-10, 60] {
            let obj: [String: Any] = ["data": ["state": ["projection": [
                "expiresAt": format.string(from: Date().addingTimeInterval(seconds)), "application": ["displayName": "Arc"]]]]]
            XCTAssertEqual(Reporter.remoteName(from: obj, companion: true), seconds > 0 ? "Arc" : nil)
        }
    }
    func testHTTP200WithoutAcknowledgementIsFailure() {
        StubProtocol.handler = { _ in (200, #"{"data":{"processName":"Arc"}}"#) }
        let done = expectation(description: "response")
        let reporter = Reporter(config: legacy, session: mockSession())
        reporter.report(appName: "Arc") { ok in
            XCTAssertFalse(ok); XCTAssertNil(reporter.lastSuccessAt); done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
    func testWrappedLegacyAcknowledgementIsSuccess() {
        StubProtocol.handler = { _ in (200, #"{"data":{"ok":1}}"#) }
        let done = expectation(description: "response")
        let reporter = Reporter(config: legacy, session: mockSession())
        reporter.report(appName: "Arc") { ok in
            XCTAssertTrue(ok); XCTAssertEqual(reporter.lastReportedName, "Arc"); done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
    func testErrorDoesNotEchoCredentialOrUpstreamMessage() {
        StubProtocol.handler = { _ in (401, #"{"error":{"code":"COMPANION_DEVICE_REVOKED","message":"secret-token-echo"}}"#) }
        let done = expectation(description: "response")
        let reporter = Reporter(config: companion, session: mockSession())
        reporter.report(appName: "Arc") { ok in
            XCTAssertFalse(ok); XCTAssertTrue(reporter.lastError!.contains("401"))
            XCTAssertFalse(reporter.lastError!.contains("secret-token-echo")); done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
    func testPublicReadUsesGETWithoutDeviceToken() {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url!.path, "/api/v3/companion/presence/public")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (200, #"{"data":{"state":{"projection":null}}}"#)
        }
        let done = expectation(description: "response")
        let reporter = Reporter(config: companion, session: mockSession())
        reporter.fetchRemoteState { name in XCTAssertNil(name); done.fulfill() }
        wait(for: [done], timeout: 3)
    }
    func testPauseClearsPresenceWithDeviceAuthentication() {
        StubProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url!.path, "/api/v3/companion/presence/clear")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-device-token")
            return (200, #"{"data":{"acceptedSequence":1}}"#)
        }
        let done = expectation(description: "response")
        let reporter = Reporter(config: companion, session: mockSession())
        reporter.clear { ok in XCTAssertTrue(ok); done.fulfill() }
        wait(for: [done], timeout: 3)
    }
}
