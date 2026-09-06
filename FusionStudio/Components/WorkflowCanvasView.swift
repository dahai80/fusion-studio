import SwiftUI

struct CanvasNode<NodeType: Hashable & RawRepresentable>: Identifiable where NodeType.RawValue == String {
    let id: String
    var type: NodeType
    var label: String
    var position: CGPoint
    var config: [String: JSONValue]
    init(id: String = "n_\(UUID().uuidString.prefix(8))", type: NodeType, label: String, position: CGPoint, config: [String: JSONValue] = [:]) {
        self.id = id
        self.type = type
        self.label = label
        self.position = position
        self.config = config
    }
}

struct CanvasEdge: Identifiable {
    let id: String
    var sourceId: String
    var targetId: String
    var condition: String?
    init(id: String = "e_\(UUID().uuidString.prefix(8))", sourceId: String, targetId: String, condition: String? = nil) {
        self.id = id
        self.sourceId = sourceId
        self.targetId = targetId
        self.condition = condition
    }
}

enum CanvasToolbarLabel: String, CaseIterable {
    case autoLayout, saveLayout, testRun, save, running, saving
    case nodeTypes, hintDrag, hintRightClick, hintConnect
    case nodeName, deleteNode, inspectorReadOnly, inspectorEdit, wfName
    case addNode
}

@MainActor
protocol WorkflowCanvasDelegate: AnyObject, ObservableObject {
    associatedtype NodeType: Hashable, CaseIterable, RawRepresentable where NodeType.RawValue == String

    var canvasNodeTypes: [NodeType] { get }
    func displayName(_ t: NodeType) -> String
    func icon(_ t: NodeType) -> String
    func color(_ t: NodeType) -> Color
    func defaultLabel(_ t: NodeType) -> String
    func nodeID() -> String
    func edgeID(from: String, to: String) -> String
    func toolbarLabel(_ kind: CanvasToolbarLabel) -> String

    @ViewBuilder func configSection(for node: Binding<CanvasNode<NodeType>>) -> AnyView?

    func save(graphName: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge]) async throws
    func load() async throws -> (name: String, nodes: [CanvasNode<NodeType>], edges: [CanvasEdge])
    func persistLayout(_ layout: [String: CGPoint]) async
}
