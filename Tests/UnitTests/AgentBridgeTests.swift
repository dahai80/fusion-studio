import XCTest
@testable import FusionStudio

@MainActor
final class AgentBridgeTests: XCTestCase {
    // F-A1/F-I1: AgentBridge 持 7 域 let 引用 (稳定身份, SwiftUI 自动追踪)。
    func testDomainRefsExist() {
        let bridge = AgentBridge()
        XCTAssertNotNil(bridge.runtimeState as RuntimeState?)
        XCTAssertNotNil(bridge.mlxState as MLXState?)
        XCTAssertNotNil(bridge.agentState as AgentState?)
        XCTAssertNotNil(bridge.moduleState as ModuleState?)
        XCTAssertNotNil(bridge.taskState as TaskState?)
        XCTAssertNotNil(bridge.configState as ConfigState?)
        XCTAssertNotNil(bridge.projectChatState as ProjectChatState?)
    }

    // 域引用稳定身份: 多次访问同一实例 (SwiftUI 追踪前提)。
    func testDomainRefsStableIdentity() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.mlxState === bridge.mlxState)
        XCTAssertTrue(bridge.agentState === bridge.agentState)
    }
}
