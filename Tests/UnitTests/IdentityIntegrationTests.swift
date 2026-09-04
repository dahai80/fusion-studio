import XCTest
@testable import FusionStudio

// #394 fusion-identity integration — behavior-locking tests.
//   Pattern mirrors Audit0902Tests: @testable import FusionStudio, @MainActor, Keychain round-trip.
@MainActor
final class IdentityIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        KeychainStore.clearIdentity()
        IdentityService.shared.clearSessionForTest()
    }

    override func tearDown() async throws {
        KeychainStore.clearIdentity()
        IdentityService.shared.clearSessionForTest()
        try await super.tearDown()
    }

    func test_keychain_identity_roundTrip() {
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "")
        XCTAssertTrue(KeychainStore.writeIdentityJWT("jwt-abc-123"))
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "jwt-abc-123")
        XCTAssertTrue(KeychainStore.writeIdentityRefresh("rf-xyz-789"))
        XCTAssertEqual(KeychainStore.readIdentityRefresh(), "rf-xyz-789")
        KeychainStore.clearIdentity()
        XCTAssertEqual(KeychainStore.readIdentityJWT(), "")
        XCTAssertEqual(KeychainStore.readIdentityRefresh(), "")
    }

    func test_jwtDecode_claims() {
        let payload = #"{"tid":"default","role":"tenant_admin","scope":"tenants:read models:read","exp":9999999999,"sub":"usr_admin"}"#
        let b64 = IdentityService.testBase64Encode(payload)
        let claims = IdentityService.decodeClaims(jwt: "header.\(b64).sig")
        XCTAssertEqual(claims?["tid"] as? String, "default")
        XCTAssertEqual(claims?["role"] as? String, "tenant_admin")
        XCTAssertEqual(claims?["exp"] as? Int, 9999999999)
    }

    func test_downstreamHeaders_loggedOut() {
        let svc = IdentityService()
        XCTAssertEqual(svc.downstreamHeaders(), [:])
        XCTAssertTrue(svc.downstreamAuthParams().isEmpty)
    }

    func test_downstreamHeaders_loggedIn() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "jwt-123", refreshToken: "rf-456", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: ["tenants:read"], expiresAt: Date().addingTimeInterval(3600)))
        let h = svc.downstreamHeaders()
        XCTAssertEqual(h["Authorization"], "Bearer jwt-123")
        XCTAssertEqual(h["X-Tenant-Id"], "default")
    }

    func test_downstreamAuthParams_loggedIn() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "jwt-123", refreshToken: "rf-456", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: ["tenants:read"], expiresAt: Date().addingTimeInterval(3600)))
        let p = svc.downstreamAuthParams()
        let auth = p["_auth"] as? [String: Any]
        XCTAssertEqual(auth?["jwt"] as? String, "jwt-123")
        XCTAssertEqual(auth?["tid"] as? String, "default")
    }

    func test_handle401_refreshFail_logsOut() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "expired", refreshToken: "bad-rf", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: [], expiresAt: Date().addingTimeInterval(-10)))
        let exp = expectation(description: "logout")
        Task {
            await svc.handle401()
            XCTAssertTrue(svc.session == nil)
            if case .loggedOut = svc.state { exp.fulfill() }
        }
        wait(for: [exp], timeout: 15)
    }

    func test_ipc_callInjectsAuthParams_whenLoggedIn() {
        let svc = IdentityService()
        svc.setSessionForTest(IdentitySession(
            jwt: "jwt-1", refreshToken: "rf-1", tenantId: "t-1",
            tenantName: "T1", role: "member", scopes: [], expiresAt: Date().addingTimeInterval(3600)))
        let merged = IPCClient.mergedAuthParams(params: ["foo": "bar"], service: svc)
        XCTAssertEqual(merged["foo"] as? String, "bar")
        let auth = merged["_auth"] as? [String: Any]
        XCTAssertEqual(auth?["tid"] as? String, "t-1")
    }

    func test_useIdentity_gate() {
        let svc = IdentityService()
        XCTAssertFalse(svc.isIdentityReachable && svc.session != nil)
        svc.setSessionForTest(IdentitySession(
            jwt: "j", refreshToken: "r", tenantId: "default",
            tenantName: "Default", role: "tenant_admin", scopes: [], expiresAt: Date().addingTimeInterval(3600)))
        svc.setReachableForTest(true)
        XCTAssertTrue(svc.useIdentity)
        svc.setReachableForTest(false)
        XCTAssertFalse(svc.useIdentity)
    }

    // MARK: - 审计v0.1.58 residual — JWT keyless claim integrity

    func test_residual_validateClaims_validClaims_ok() {
        let claims: [String: Any] = [
            "iss": IdentityService.expectedIssuer,
            "aud": IdentityService.expectedAudience,
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
            "tid": "default",
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .ok, "valid iss/aud/future-exp → ok")
    }

    func test_residual_validateClaims_expiredToken_expired() {
        let claims: [String: Any] = [
            "iss": IdentityService.expectedIssuer,
            "aud": IdentityService.expectedAudience,
            "exp": Date().addingTimeInterval(-10).timeIntervalSince1970,
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .expired, "past exp → expired")
    }

    func test_residual_validateClaims_notYetValidToken_notYetValid() {
        let claims: [String: Any] = [
            "iss": IdentityService.expectedIssuer,
            "aud": IdentityService.expectedAudience,
            "nbf": Date().addingTimeInterval(600).timeIntervalSince1970,
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .notYetValid, "future nbf → notYetValid")
    }

    func test_residual_validateClaims_wrongIssuer_tampered() {
        let claims: [String: Any] = [
            "iss": "evil-issuer",
            "aud": IdentityService.expectedAudience,
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .tampered, "iss ≠ fusion-identity → tampered")
    }

    func test_residual_validateClaims_wrongAudience_tampered() {
        let claims: [String: Any] = [
            "iss": IdentityService.expectedIssuer,
            "aud": "other-app",
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .tampered, "aud ≠ fusion-studio → tampered")
    }

    func test_residual_validateClaims_emptyIssuerAud_ok() {
        let claims: [String: Any] = [
            "iss": "",
            "aud": "",
            "exp": Date().addingTimeInterval(3600).timeIntervalSince1970,
        ]
        XCTAssertEqual(IdentityService.validateClaims(claims), .ok, "empty iss/aud skipped (old token) → ok")
    }

    func test_residual_validateClaims_missingAllClaims_ok() {
        XCTAssertEqual(IdentityService.validateClaims([:]), .ok, "no claims → ok (keyless, server still final authority)")
    }

    // #394 Task 8: jwt/refreshToken must never leak via String(describing:)
    //   or accidental os_log interpolation. IdentitySession redacts secrets
    //   in its CustomStringConvertible description (structural guarantee).
    func test_jwtNeverLogged_sessionDescriptionRedactsSecrets() {
        let session = IdentitySession(
            jwt: "SECRET-JWT-SHOULD-NOT-APPEAR", refreshToken: "SECRET-REFRESH-SHOULD-NOT-APPEAR",
            tenantId: "default", tenantName: "Default", role: "tenant_admin",
            scopes: ["tenants:read"], expiresAt: Date().addingTimeInterval(3600))
        let described = String(describing: session)
        XCTAssertFalse(described.contains("SECRET-JWT-SHOULD-NOT-APPEAR"), "jwt leaked in description: \(described)")
        XCTAssertFalse(described.contains("SECRET-REFRESH-SHOULD-NOT-APPEAR"), "refreshToken leaked in description: \(described)")
        XCTAssertTrue(described.contains("default"), "tenant id should remain in description: \(described)")
    }
}
