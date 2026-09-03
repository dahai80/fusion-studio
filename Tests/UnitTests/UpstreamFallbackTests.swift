import XCTest
@testable import FusionStudio

@MainActor
final class UpstreamFallbackTests: XCTestCase {

    // MARK: - Deprecated module sidebar filter

    func test_upstream_deprecatedModulesHiddenByDefault() {
        let visible = SidebarSection.visibleSections(showDeprecated: false)
        XCTAssertFalse(visible.contains(.simulation), "simulation hidden when showDeprecated=false")
        XCTAssertFalse(visible.contains(.trainer), "trainer hidden when showDeprecated=false")
    }

    func test_upstream_deprecatedModulesShownWhenFlagTrue() {
        let visible = SidebarSection.visibleSections(showDeprecated: true)
        XCTAssertTrue(visible.contains(.simulation), "simulation shown when showDeprecated=true")
        XCTAssertTrue(visible.contains(.trainer), "trainer shown when showDeprecated=true")
    }

    func test_upstream_isDeprecatedClassification() {
        XCTAssertTrue(SidebarSection.simulation.isDeprecated, "simulation is deprecated")
        XCTAssertTrue(SidebarSection.trainer.isDeprecated, "trainer is deprecated")
        XCTAssertFalse(SidebarSection.code.isDeprecated, "code is not deprecated")
        XCTAssertFalse(SidebarSection.multiNode.isDeprecated, "multiNode is not deprecated")
    }

    // MARK: - Idempotency key

    func test_upstream_idempotencyKeyGeneratedPerSubmit() {
        let key1 = MultiNodeEngine.generateIdempotencyKey()
        let key2 = MultiNodeEngine.generateIdempotencyKey()
        XCTAssertFalse(key1.isEmpty, "key non-empty")
        XCTAssertFalse(key2.isEmpty, "key non-empty")
        XCTAssertNotEqual(key1, key2, "two calls differ")
    }
}
