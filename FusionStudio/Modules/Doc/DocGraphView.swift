// Callers: DocView toolbar button, DocSidebar graph mode.
// Affected API: DocBridge fetchGraph, fetchPage, addPageLink.
// Data schemas: DocGraph, DocGraphNode, DocGraphEdge (from DocBridge.swift).
// User instruction: "按照prd文档和fusion-doc配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let graphLog = Logger(subsystem: "com.fusion.studio", category: "DocGraph")

struct DocGraphView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @ObservedObject var bridge: DocBridge
    @State private var selectedNode: DocGraphNode?
    @State private var searchText = ""
    @State private var filterType: String = "all"
    @State private var dragOffset: [String: CGSize] = [:]

    var body: some View {
        VStack(spacing: 0) {
            graphToolbar
            Divider()
            ZStack {
                graphCanvas
                if selectedNode != nil {
                    nodeDetailPanel
                }
            }
        }
        .background(theme.surfacePrimary)
        .onAppear {
            bridge.fetchGraph()
        }
    }

    private var graphToolbar: some View {
        HStack {
            Text(i18n.t(.doc_graph_title))
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()

            HStack(spacing: 4) {
                FilterChip(label: i18n.t(.doc_graph_filterAll), isSelected: filterType == "all") { filterType = "all" }
                FilterChip(label: i18n.t(.doc_graph_filterLink), isSelected: filterType == "link") { filterType = "link" }
                FilterChip(label: i18n.t(.doc_graph_filterSemantic), isSelected: filterType == "semantic") { filterType = "semantic" }
                FilterChip(label: i18n.t(.doc_graph_filterTag), isSelected: filterType == "tag") { filterType = "tag" }
            }

            Divider().frame(height: 16)

            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(i18n.t(.doc_graph_searchNode), text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 120)
            }

            Button(action: { bridge.fetchGraph() }) {
                Image(systemName: "arrow.clockwise")
            }
            .help(i18n.t(.doc_graph_refreshHelp))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.surfaceSecondary)
    }

    private var graphCanvas: some View {
        ZStack {
            if let graph = bridge.graph {
                if graph.nodes.isEmpty {
                    emptyGraph
                } else {
                    canvasWithNodes(graph)
                }
            } else {
                ProgressView(i18n.t(.doc_graph_loading))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func canvasWithNodes(_ graph: DocGraph) -> some View {
        let filteredNodes = graph.nodes.filter { node in
            if !searchText.isEmpty && !node.title.localizedCaseInsensitiveContains(searchText) { return false }
            return true
        }
        let filteredEdges = graph.edges.filter { edge in
            if filterType != "all" {
                return edge.link_type == filterType
            }
            return true
        }

        return Canvas { context, size in
            let nodeMap = Dictionary(uniqueKeysWithValues: filteredNodes.map { ($0.id, $0) })
            let positions = computePositions(nodes: filteredNodes, size: size)

            for edge in filteredEdges {
                guard let from = positions[edge.source], let to = positions[edge.target] else { continue }
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                let edgeColor: Color = {
                    switch edge.link_type {
                    case "semantic": return theme.accent.opacity(0.4)
                    case "tag": return Color.orange.opacity(0.4)
                    default: return Color.gray.opacity(0.3)
                    }
                }()

                context.stroke(path, with: .color(edgeColor), lineWidth: 1.5)
            }

            for node in filteredNodes {
                guard let pos = positions[node.id] else { continue }
                let isSelected = selectedNode?.id == node.id
                let nodeColor: Color = {
                    switch node.type {
                    case "book": return Color.purple
                    case "chapter": return Color.orange
                    default: return theme.accent
                    }
                }()

                let circleSize: CGFloat = isSelected ? 28 : 22
                let rect = CGRect(x: pos.x - circleSize / 2, y: pos.y - circleSize / 2, width: circleSize, height: circleSize)

                context.fill(Path(ellipseIn: rect), with: .color(nodeColor.opacity(isSelected ? 1.0 : 0.7)))

                if isSelected {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(nodeColor), lineWidth: 2)
                }

                let titleRect = CGRect(x: pos.x - 50, y: pos.y + circleSize / 2 + 4, width: 100, height: 16)
                context.draw(Text(node.title).font(.caption2).foregroundColor(.primary), in: titleRect)
            }
        }
        .gesture(
            TapGesture()
                .onEnded { _ in selectedNode = nil }
        )
    }

    private var nodeDetailPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let node = selectedNode {
                HStack {
                    Text(node.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: { selectedNode = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if let tags = node.tags, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accentSoft)
                                .cornerRadius(4)
                        }
                    }
                }
                if let count = node.linkCount {
                    Text(String(format: i18n.t(.doc_graph_linkCountFmt), count))
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                Button(i18n.t(.doc_graph_openPage)) {
                    bridge.fetchPage(id: node.id)
                }
                .buttonStyle(.plain)
                .foregroundColor(theme.accent)
            }
        }
        .padding(12)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
        .shadow(radius: 4)
        .frame(maxWidth: 240, alignment: .topLeading)
        .padding(12)
    }

    private var emptyGraph: some View {
        VStack(spacing: 12) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(i18n.t(.doc_graph_empty))
                .font(.title3)
                .foregroundColor(.secondary)
            Text(i18n.t(.doc_graph_emptyHint))
                .font(.caption)
                .foregroundColor(theme.textTertiary)
        }
    }

    // MARK: - Layout

    private func computePositions(nodes: [DocGraphNode], size: CGSize) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        let centerX = size.width / 2
        let centerY = size.height / 2
        let radius = min(size.width, size.height) * 0.35

        for (i, node) in nodes.enumerated() {
            let angle = 2.0 * Double.pi * Double(i) / Double(nodes.count) - Double.pi / 2
            let offset = dragOffset[node.id] ?? .zero
            positions[node.id] = CGPoint(
                x: centerX + radius * Foundation.cos(angle) + offset.width,
                y: centerY + radius * Foundation.sin(angle) + offset.height
            )
        }
        return positions
    }
}
