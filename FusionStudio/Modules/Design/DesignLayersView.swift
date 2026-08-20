// Callers: DesignView.designInfoPanel (ModuleDetailView.swift InfoPanelTab.layers).
// Affected API: DesignBridge.pages, DesignBridge.currentPageIndex, DesignInspectorState.shared, BridgeCommand.SelectNode.
// Data schemas: PenDocument JSON (pages[].nodes[{id,kind,text,children}]), LayerNode struct.

import SwiftUI
import UniformTypeIdentifiers
import os.log

private let layersLog = Logger(subsystem: "com.fusion.studio", category: "DesignLayers")

struct LayerNode: Identifiable {
    let id: String
    let kind: String
    let label: String
    let depth: Int
    let hasChildren: Bool
    var visible: Bool = true
    var locked: Bool = false
}

struct DesignLayersView: View {
    @Binding var selectedNodeID: String?
    @EnvironmentObject var designBridge: DesignBridge
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var expandedNodes: Set<String> = []
    @State private var flatNodes: [LayerNode] = []
    @State private var hiddenNodeIDs: Set<String> = []
    @State private var lockedNodeIDs: Set<String> = []
    @State private var dragSourceIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            if flatNodes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(flatNodes.enumerated()), id: \.element.id) { index, node in
                            layerRow(node, index: index)
                                .onDrag {
                                    dragSourceIndex = index
                                    return NSItemProvider(object: node.id as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: LayerDropDelegate(
                                    destinationIndex: index,
                                    flatNodes: $flatNodes,
                                    dragSourceIndex: $dragSourceIndex,
                                    hiddenNodeIDs: $hiddenNodeIDs,
                                    designBridge: designBridge
                                ))
                        }
                    }
                }
            }
        }
        .onAppear { rebuildNodes() }
        .onChange(of: designBridge.pages.count) { _ in rebuildNodes() }
        .onChange(of: designBridge.currentPageIndex) { _ in rebuildNodes() }
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "square.3.layers.3d")
                .foregroundColor(theme.accent)
            Text(i18n.t(.design_ly_title))
                .font(.system(size: theme.bodySize, weight: .semibold))
                .foregroundColor(theme.text)
            Spacer()
            Text(String(format: i18n.t(.design_ly_countFmt), flatNodes.count))
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.textTertiary)
            Button(action: {
                expandedNodes.removeAll()
                rebuildNodes()
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 32))
                .foregroundColor(theme.textTertiary)
            Text(i18n.t(.design_ly_empty))
                .font(.system(size: theme.captionSize))
                .foregroundColor(theme.textTertiary)
            Text(i18n.t(.design_ly_emptyHint))
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacingL)
    }

    @ViewBuilder
    private func layerRow(_ node: LayerNode, index: Int) -> some View {
        let isSelected = selectedNodeID == node.id
        let isExpanded = expandedNodes.contains(node.id)
        let isHidden = hiddenNodeIDs.contains(node.id)

        HStack(spacing: theme.spacingXS) {
            Spacer()
                .frame(width: CGFloat(node.depth) * 16)

            if node.hasChildren {
                Button(action: {
                    if isExpanded {
                        expandedNodes.remove(node.id)
                    } else {
                        expandedNodes.insert(node.id)
                    }
                    rebuildNodes()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(theme.textTertiary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 12)
            }

            Image(systemName: kindIcon(node.kind))
                .font(.system(size: 10))
                .foregroundColor(isSelected ? theme.accent : theme.textSecondary)
                .frame(width: 14)

            Text(node.label)
                .font(.system(size: theme.captionSize))
                .foregroundColor(isSelected ? theme.accentText : (isHidden ? theme.textTertiary : theme.text))
                .lineLimit(1)
                .truncationMode(.tail)
                .strikethrough(isHidden)

            Spacer()

            Button(action: {
                toggleVisibility(node.id)
            }) {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .font(.system(size: 10))
                    .foregroundColor(isHidden ? theme.textTertiary : theme.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: {
                toggleLocked(node.id)
            }) {
                Image(systemName: lockedNodeIDs.contains(node.id) ? "lock.fill" : "lock.open")
                    .font(.system(size: 10))
                    .foregroundColor(lockedNodeIDs.contains(node.id) ? theme.accent : theme.textTertiary)
            }
            .buttonStyle(.plain)

            Text(node.id)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(isSelected ? theme.accentSoft : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedNodeID = node.id
            DesignInspectorState.shared.selectedElement = node.id
            designBridge.selectCanvasNode(node.id)
            layersLog.info("DesignLayers: selected node \(node.id)")
        }
    }

    private func toggleVisibility(_ nodeID: String) {
        if hiddenNodeIDs.contains(nodeID) {
            hiddenNodeIDs.remove(nodeID)
            designBridge.setNodeVisibility(nodeID, visible: true)
        } else {
            hiddenNodeIDs.insert(nodeID)
            designBridge.setNodeVisibility(nodeID, visible: false)
        }
        layersLog.info("DesignLayers: toggle visibility node \(nodeID)")
    }

    private func toggleLocked(_ nodeID: String) {
        if lockedNodeIDs.contains(nodeID) {
            lockedNodeIDs.remove(nodeID)
            designBridge.setNodeLocked(nodeID, locked: false)
        } else {
            lockedNodeIDs.insert(nodeID)
            designBridge.setNodeLocked(nodeID, locked: true)
        }
        layersLog.info("DesignLayers: toggle locked node \(nodeID)")
    }

    private func kindIcon(_ kind: String) -> String {
        switch kind {
        case "Text": return "textformat"
        case "Image": return "photo"
        case "Rect": return "square"
        case "Circle": return "circle"
        case "Group": return "square.3.layers.3d"
        default: return "square.dashed"
        }
    }

    private func rebuildNodes() {
        var result: [LayerNode] = []

        let pageIndex = designBridge.currentPageIndex
        guard pageIndex >= 0 && pageIndex < designBridge.pages.count else {
            flatNodes = result
            return
        }

        if let penDocJSON = designBridge.lastRenderedDocumentJSON {
            if let data = penDocJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let pages = json["pages"] as? [[String: Any]] {
                let targetPage: [String: Any]?
                if pageIndex < pages.count {
                    targetPage = pages[pageIndex]
                } else if let first = pages.first {
                    targetPage = first
                } else {
                    targetPage = nil
                }
                if let pageDict = targetPage,
                   let nodes = pageDict["nodes"] as? [[String: Any]] {
                    for nodeDict in nodes {
                        flattenNodeInto(&result, dict: nodeDict, depth: 0)
                    }
                }
            }
        }
        flatNodes = result
    }

    private func flattenNodeInto(_ result: inout [LayerNode], dict: [String: Any], depth: Int) {
        let id = dict["id"] as? String ?? "?"
        let kind = dict["kind"] as? String ?? "Rect"
        let text = dict["text"] as? String
        let children = dict["children"] as? [[String: Any]] ?? []

        let label: String
        if let t = text, !t.isEmpty {
            label = String(t.prefix(20))
        } else {
            label = kind
        }

        let isVisible = !hiddenNodeIDs.contains(id)
        result.append(LayerNode(
            id: id,
            kind: kind,
            label: label,
            depth: depth,
            hasChildren: !children.isEmpty,
            visible: isVisible
        ))

        if expandedNodes.contains(id) {
            for child in children {
                flattenNodeInto(&result, dict: child, depth: depth + 1)
            }
        }
    }
}

// MARK: - Drag & Drop Delegate

private struct LayerDropDelegate: DropDelegate {
    let destinationIndex: Int
    @Binding var flatNodes: [LayerNode]
    @Binding var dragSourceIndex: Int?
    @Binding var hiddenNodeIDs: Set<String>
    let designBridge: DesignBridge

    func performDrop(info: DropInfo) -> Bool {
        guard let srcIdx = dragSourceIndex else { return false }
        guard srcIdx != destinationIndex else { return false }
        guard srcIdx < flatNodes.count, destinationIndex < flatNodes.count else { return false }

        let moved = flatNodes.remove(at: srcIdx)
        let insertIdx = srcIdx < destinationIndex ? destinationIndex - 1 : destinationIndex
        flatNodes.insert(moved, at: insertIdx)

        designBridge.reorderNode(moved.id, newIndex: insertIdx)
        layersLog.info("DesignLayers: reorder \(moved.id) to \(insertIdx)")
        dragSourceIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
