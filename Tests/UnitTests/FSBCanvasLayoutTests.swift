import XCTest
@testable import FusionStudio

// #395 Workflow Canvas — node position 解析行为锁定。
//   上游 node 模型: position 在顶层 nodes[].position (新) 或 nodes[].config.position (旧)。
//   parseNodePosition 必须先读顶层, 回退 config, 再回退自动错位 (否则 reload 位置丢失→随机)。

final class FSBCanvasLayoutTests: XCTestCase {

    func test_parsePosition_topLevelWins() {
        let node: [String: Any] = [
            "id": "n1",
            "type": "START_NODE",
            "position": ["x": 120.0, "y": 45.0],
            "config": ["position": ["x": 0.0, "y": 0.0]]
        ]
        let p = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 0)
        XCTAssertEqual(p.x, 120.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 45.0, accuracy: 0.001)
    }

    func test_parsePosition_configFallbackWhenNoTopLevel() {
        let node: [String: Any] = [
            "id": "n2",
            "type": "SKILL_NODE",
            "config": ["position": ["x": -80.0, "y": 200.0]]
        ]
        let p = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 0)
        XCTAssertEqual(p.x, -80.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 200.0, accuracy: 0.001)
    }

    func test_parsePosition_intCoordinatesAccepted() {
        let node: [String: Any] = [
            "id": "n3",
            "type": "END_NODE",
            "position": ["x": 10, "y": 20]
        ]
        let p = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 0)
        XCTAssertEqual(p.x, 10.0, accuracy: 0.001)
        XCTAssertEqual(p.y, 20.0, accuracy: 0.001)
    }

    func test_parsePosition_autoStaggerWhenAbsent() {
        let node: [String: Any] = [
            "id": "n4",
            "type": "CONNECTOR_NODE",
            "config": ["label": "x"]
        ]
        let p0 = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 0)
        let p3 = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 3)
        XCTAssertNotEqual(p0, p3, "缺位时按 index 自动错位, 不同 index 不同坐标")
        XCTAssertFalse(p0.x.isNaN || p0.y.isNaN)
    }

    func test_parsePosition_nanGuarded() {
        let node: [String: Any] = [
            "id": "n5",
            "type": "CONDITION_NODE",
            "position": ["x": Double.nan, "y": 50.0]
        ]
        let p = FSBWorkflowCanvasView.parseNodePosition(node: node, fallbackIndex: 1)
        XCTAssertFalse(p.x.isNaN, "NaN x 不得通过, 回退自动错位")
        XCTAssertFalse(p.y.isNaN)
    }
}
