import Foundation
import Combine
import os.log

// #394: 非 actor 隔离的 identity 快照 — sync/completion-based 桥 (DocBridge/SimulationBridge)
//   在 completion handler 内构造 URLRequest, 不能 await MainActor 读 session。
//   此 enum 持锁镜像 jwt+tid, 由 IdentityService 在 session build/clear 时同步更新。
//   前瞻: 上游未消费 identity 头前为 no-op (已记 issue)。NEVER log jwt 值。
enum IdentityAuthSnapshot {
    private struct Data { let jwt: String; let tid: String }
    private static var _data: Data?
    private static let _lock = NSLock()

    static func set(jwt: String, tid: String) {
        _lock.lock()
        _data = Data(jwt: jwt, tid: tid)
        _lock.unlock()
    }

    static func clear() {
        _lock.lock()
        _data = nil
        _lock.unlock()
    }

    static func headers() -> [String: String] {
        _lock.lock()
        let d = _data
        _lock.unlock()
        guard let d = d else { return [:] }
        return ["Authorization": "Bearer \(d.jwt)", "X-Tenant-Id": d.tid]
    }

    static func authParams() -> [String: Any] {
        _lock.lock()
        let d = _data
        _lock.unlock()
        guard let d = d else { return [:] }
        return ["_auth": ["jwt": d.jwt, "tid": d.tid] as [String: Any]]
    }
}

// #394 fusion-identity integration — single auth-state source of truth.
// Contract (read from fusion-identity routes/auth.py + models.py, not modified):
//   POST /api/v1/auth/login   {username, password, tenant_id} -> {access_token, refresh_token, expires_in}
//   POST /api/v1/auth/refresh {refresh_token}                  -> TokenResponse
//   POST /api/v1/auth/revoke  {refresh_token} (tenant_admin)   -> {}
//   GET  /health                                                -> 200
//   JWT claims: tid, role, scope, sub, exp, jti, iss, aud
//   bootstrap tenant="default", admin/adminpass (FUSION_BOOTSTRAP_*).
// Forward-looking: header/param attachment is no-op until upstream enforces.
@MainActor
final class IdentityService: ObservableObject {

    static let shared = IdentityService()

    @Published private(set) var state: AuthState = .loggedOut
    @Published private(set) var session: IdentitySession?
    @Published private(set) var isIdentityReachable: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "identity")
    private let base = "http://127.0.0.1:11470"
    private var refreshInFlight = false

    var isLoggedIn: Bool {
        if case .loggedIn = state { return true }
        return false
    }

    var useIdentity: Bool {
        isIdentityReachable && session != nil
    }

    // MARK: - Nonisolated snapshot (sync/completion-based bridge call sites)
    // SimulationBridge/DocBridge build URLRequest in completion handlers (not async),
    // cannot await MainActor. Thread-safe mirror of session jwt+tid, updated on
    // session build/clear. Forward-looking: headers no-op until upstream enforces.
    private func updateSnapshot(jwt: String, tid: String) {
        IdentityAuthSnapshot.set(jwt: jwt, tid: tid)
    }

    private func clearSnapshot() {
        IdentityAuthSnapshot.clear()
    }

    nonisolated static func currentHeaders() -> [String: String] {
        IdentityAuthSnapshot.headers()
    }

    nonisolated static func currentAuthParams() -> [String: Any] {
        IdentityAuthSnapshot.authParams()
    }

    // #394: HTTP 桥 (DocBridge/SimulationBridge) 在 completion handler 内构造 URLRequest,
    //   不能 await MainActor。nonisolated 应用 identity 头: X-Tenant-Id 恒注,
    //   Authorization 仅当请求未自带时注 (DocBridge 已有自身 Bearer token, 不覆盖)。
    //   前瞻: 上游未消费前为 no-op (已记 issue)。
    nonisolated static func applyIdentityHeaders(to request: inout URLRequest) {
        for (k, v) in IdentityAuthSnapshot.headers() {
            if k == "Authorization", request.value(forHTTPHeaderField: "Authorization") != nil {
                continue
            }
            request.setValue(v, forHTTPHeaderField: k)
        }
    }

    // MARK: - Health

    func probeHealth() async -> Bool {
        guard let url = URL(string: "\(base)/health") else {
            isIdentityReachable = false
            return false
        }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let ok = (resp as? HTTPURLResponse)?.statusCode == 200
            isIdentityReachable = ok
            logger.info("probeHealth: reachable=\(ok, privacy: .public)")
            return ok
        } catch {
            isIdentityReachable = false
            logger.info("probeHealth: not reachable (\(error.localizedDescription, privacy: .public))")
            return false
        }
    }

    // MARK: - Login

    func login(username: String, password: String, tenantId: String = "default") async throws {
        state = .loggingIn
        guard let url = URL(string: "\(base)/api/v1/auth/login") else {
            state = .error("bad identity URL")
            throw IdentityError.badUrl
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": username, "password": password, "tenant_id": tenantId]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            state = .error("no response")
            throw IdentityError.noResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            state = .error("login \(http.statusCode)")
            logger.error("login: http \(http.statusCode)")
            throw IdentityError.http(http.statusCode)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String,
              !access.isEmpty else {
            state = .error("bad login response")
            throw IdentityError.badResponse
        }
        let expiresIn = obj["expires_in"] as? Int ?? 3600
        try persistAndBuild(jwt: access, refreshToken: refresh, expiresIn: expiresIn, tenantId: tenantId)
        logger.info("login: ok tenant=\(tenantId, privacy: .public)")
    }

    // MARK: - Resolve (launch)

    func resolveSession() async {
        let cachedJwt = KeychainStore.readIdentityJWT()
        guard !cachedJwt.isEmpty else {
            state = .loggedOut
            logger.info("resolveSession: no cached jwt, loggedOut")
            return
        }
        guard let claims = IdentityService.decodeClaims(jwt: cachedJwt) else {
            logger.error("resolveSession: cached jwt undecodable, clearing")
            KeychainStore.clearIdentity()
            state = .loggedOut
            clearSnapshot()
            return
        }
        let now = Date().timeIntervalSince1970
        let exp = (claims["exp"] as? Double) ?? 0
        if exp < now {
            logger.info("resolveSession: cached jwt expired, refresh")
            do {
                try await refresh()
            } catch {
                logger.error("resolveSession: refresh failed, loggedOut: \(error.localizedDescription)")
                KeychainStore.clearIdentity()
                session = nil
                state = .loggedOut
                clearSnapshot()
            }
            return
        }
        buildSessionFromClaims(jwt: cachedJwt, refreshToken: KeychainStore.readIdentityRefresh(), claims: claims)
        state = .loggedIn
        logger.info("resolveSession: restored session from cached jwt (tenant=\(claims["tid"] as? String ?? "?", privacy: .public))")
    }

    // MARK: - Refresh

    func refresh() async throws {
        let rfToken = KeychainStore.readIdentityRefresh()
        guard !rfToken.isEmpty else {
            throw IdentityError.noRefreshToken
        }
        guard let url = URL(string: "\(base)/api/v1/auth/refresh") else {
            throw IdentityError.badUrl
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": rfToken])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw IdentityError.http((resp as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String,
              let refresh = obj["refresh_token"] as? String,
              !access.isEmpty else {
            throw IdentityError.badResponse
        }
        let expiresIn = obj["expires_in"] as? Int ?? 3600
        let tid = (IdentityService.decodeClaims(jwt: access)?["tid"] as? String) ?? "default"
        try persistAndBuild(jwt: access, refreshToken: refresh, expiresIn: expiresIn, tenantId: tid)
        logger.info("refresh: ok tenant=\(tid, privacy: .public)")
    }

    // MARK: - Logout

    func logout() async {
        let rfToken = KeychainStore.readIdentityRefresh()
        if !rfToken.isEmpty, let url = URL(string: "\(base)/api/v1/auth/revoke") {
            var req = URLRequest(url: url, timeoutInterval: 5)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let jwt = session?.jwt { req.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization") }
            if let tid = session?.tenantId { req.setValue(tid, forHTTPHeaderField: "X-Tenant-Id") }
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": rfToken])
            _ = try? await URLSession.shared.data(for: req)
            logger.info("logout: revoke sent (best-effort)")
        }
        KeychainStore.clearIdentity()
        session = nil
        state = .loggedOut
        clearSnapshot()
        logger.info("logout: cleared session")
    }

    // MARK: - 401 handling (single-flight)

    func handle401() async {
        guard !refreshInFlight else { return }
        refreshInFlight = true
        defer { refreshInFlight = false }
        do {
            try await refresh()
            logger.info("handle401: refresh succeeded, staying loggedIn")
        } catch {
            logger.error("handle401: refresh failed, logging out: \(error.localizedDescription)")
            await logout()
        }
    }

    // MARK: - Downstream attachment

    func downstreamHeaders() -> [String: String] {
        guard let s = session else { return [:] }
        return ["Authorization": "Bearer \(s.jwt)", "X-Tenant-Id": s.tenantId]
    }

    func downstreamAuthParams() -> [String: Any] {
        guard let s = session else { return [:] }
        return ["_auth": ["jwt": s.jwt, "tid": s.tenantId] as [String: Any]]
    }

    // MARK: - JWT decode (no HS256 verify client-side; trust issuer)

    static func decodeClaims(jwt: String) -> [String: Any]? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payload = String(parts[1])
        guard let data = base64UrlDecode(payload) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func testBase64Encode(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    private static func base64UrlDecode(_ s: String) -> Data? {
        var b64 = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64.append("=") }
        return Data(base64Encoded: b64)
    }

    // MARK: - Helpers

    private func persistAndBuild(jwt: String, refreshToken: String, expiresIn: Int, tenantId: String) throws {
        KeychainStore.writeIdentityJWT(jwt)
        KeychainStore.writeIdentityRefresh(refreshToken)
        guard let claims = IdentityService.decodeClaims(jwt: jwt) else {
            throw IdentityError.badResponse
        }
        buildSessionFromClaims(jwt: jwt, refreshToken: refreshToken, claims: claims, fallbackTenant: tenantId, expiresInSeconds: expiresIn)
        state = .loggedIn
    }

    private func buildSessionFromClaims(
        jwt: String,
        refreshToken: String,
        claims: [String: Any],
        fallbackTenant: String = "default",
        expiresInSeconds: Int? = nil
    ) {
        let tid = (claims["tid"] as? String) ?? fallbackTenant
        let role = (claims["role"] as? String) ?? "member"
        let scopes: [String]
        if let s = claims["scope"] as? String {
            scopes = s.split(separator: " ").map(String.init)
        } else if let arr = claims["scope"] as? [String] {
            scopes = arr
        } else {
            scopes = []
        }
        let exp: Date
        if let secs = expiresInSeconds {
            exp = Date().addingTimeInterval(TimeInterval(secs))
        } else if let e = claims["exp"] as? Double {
            exp = Date(timeIntervalSince1970: e)
        } else {
            exp = Date().addingTimeInterval(3600)
        }
        let tenantName = (claims["tenant"] as? String) ?? tid
        session = IdentitySession(
            jwt: jwt,
            refreshToken: refreshToken,
            tenantId: tid,
            tenantName: tenantName,
            role: role,
            scopes: scopes,
            expiresAt: exp
        )
        updateSnapshot(jwt: jwt, tid: tid)
    }

    // Test hooks
    func setSessionForTest(_ s: IdentitySession) {
        self.session = s
        self.state = .loggedIn
        updateSnapshot(jwt: s.jwt, tid: s.tenantId)
    }

    func setReachableForTest(_ v: Bool) {
        isIdentityReachable = v
    }

    func clearSessionForTest() {
        self.session = nil
        self.state = .loggedOut
        clearSnapshot()
    }
}

enum IdentityError: Error, LocalizedError {
    case badUrl
    case noResponse
    case http(Int)
    case badResponse
    case noRefreshToken

    var errorDescription: String? {
        switch self {
        case .badUrl: return "bad identity URL"
        case .noResponse: return "no response from identity"
        case .http(let c): return "identity http \(c)"
        case .badResponse: return "bad identity response"
        case .noRefreshToken: return "no refresh token"
        }
    }
}
