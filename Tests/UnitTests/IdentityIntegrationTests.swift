import XCTest
@testable import FusionStudio

// #394 fusion-identity integration — behavior-locking tests.
//   Pattern mirrors Audit0902Tests: @testable import FusionStudio, @MainActor, Keychain round-trip.
@MainActor
final class IdentityIntegrationTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        KeychainStore.clearIdentity()
    }

    override func tearDown() async throws {
        KeychainStore.clearIdentity()
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
}
