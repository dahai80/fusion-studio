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

    // F-A1 Phase 1: MLXState 4 props 迁入域类后初值正确。
    func testMLXStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.mlxState.models.isEmpty)
        XCTAssertFalse(bridge.mlxState.mlxRunning)
        XCTAssertTrue(bridge.mlxState.mlxLoadedModels.isEmpty)
        XCTAssertEqual(bridge.mlxState.mlxPort, 0)
    }

    // F-A1 Phase 5: ModuleState 13 @Published 初值 (类型 + 默认对齐 AgentBridge 原 decl)。
    func testModuleStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.moduleState.plans.isEmpty)
        XCTAssertNil(bridge.moduleState.currentPlan)
        XCTAssertTrue(bridge.moduleState.ragResults.isEmpty)
        XCTAssertTrue(bridge.moduleState.memoryEntries.isEmpty)
        XCTAssertEqual(bridge.moduleState.memoryCount, 0)
        XCTAssertNil(bridge.moduleState.safetyCheckResult)
        XCTAssertTrue(bridge.moduleState.safetyPendingActions.isEmpty)
        XCTAssertTrue(bridge.moduleState.templates.isEmpty)
        XCTAssertTrue(bridge.moduleState.deployFormats.isEmpty)
        XCTAssertTrue(bridge.moduleState.tools.isEmpty)
        XCTAssertTrue(bridge.moduleState.ragSources.isEmpty)
        XCTAssertEqual(bridge.moduleState.lastSkillResult, "")
        XCTAssertEqual(bridge.moduleState.lastResearchResult, "")
    }

    // F-A1 Phase 6: AgentState 15 @Published 初值 (13 AgentOps + graphs + dashboardData)。
    func testAgentStateDefaults() {
        let bridge = AgentBridge()
        XCTAssertTrue(bridge.agentState.agents.isEmpty)
        XCTAssertNil(bridge.agentState.currentAgent)
        XCTAssertTrue(bridge.agentState.agentSkills.isEmpty)
        XCTAssertTrue(bridge.agentState.agentSoul.isEmpty)
        XCTAssertTrue(bridge.agentState.marketplaceEntries.isEmpty)
        XCTAssertTrue(bridge.agentState.marketplaceCategories.isEmpty)
        XCTAssertTrue(bridge.agentState.agentVersionHistory.isEmpty)
        XCTAssertTrue(bridge.agentState.auditTrail.isEmpty)
        XCTAssertTrue(bridge.agentState.sessionLogs.isEmpty)
        XCTAssertTrue(bridge.agentState.activeSessionId.isEmpty)
        XCTAssertTrue(bridge.agentState.streamingContent.isEmpty)
        XCTAssertFalse(bridge.agentState.isAgentStreaming)
        XCTAssertTrue(bridge.agentState.lastToolCalls.isEmpty)
        XCTAssertTrue(bridge.agentState.graphs.isEmpty)
        XCTAssertTrue(bridge.agentState.dashboardData.isEmpty)
    }
}
