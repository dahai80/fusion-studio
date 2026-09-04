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
}
