import SwiftUI
import os.log

private let topologyLog = Logger(subsystem: "com.fusion.studio", category: "ClusterTopology")

struct ClusterTopologyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var nodePositions: [String: CGPoint] = [:]
    @State private var dragOffset: [String: CGSize] = [:]

    private var masterNodes: [ClusterNode] { engine.nodes.filter { $0.isMaster } }
    private var workerNodes: [ClusterNode] { engine.nodes.filter { !$0.isMaster } }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_topo_title), subtitle: i18n.t(.mn_topo_subtitle))
                .frame(maxWidth: .infinity, alignment: .leading)

            // F-A11: 脑裂告警 banner。>1 master = 网络分区, 阻断写操作直到 quorum 恢复。
            if engine.splitBrainDetected {
                HStack(alignment: .top, spacing: theme.spacingS) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(theme.redDot)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.mn_topo_splitBrainTitle))
                            .font(.system(size: theme.bodySize, weight: .semibold))
                            .foregroundStyle(theme.redDot)
                        Text(i18n.t(.mn_topo_splitBrainMsg))
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(theme.spacingM)
                .background(theme.redDot.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
                .padding(.horizontal, theme.spacingL)
                .padding(.top, theme.spacingS)
            }

            GeometryReader { geo in
                ZStack {
                    connectionsLayer(in: geo.size)
                    nodesLayer(in: geo.size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            .studioShadow(theme.shadowSmall)
            .padding(.horizontal, theme.spacingL)

            legendBar
        }
        .background(theme.contentBg)
        .onAppear {
            engine.startPolling()
            layoutNodes()
        }
        .onDisappear { engine.stopPolling() }
        .onChange(of: engine.nodes.count) { _ in layoutNodes() }
    }

    private func layoutNodes() {
        let positions = computeLayout(masterCount: masterNodes.count, workerCount: workerNodes.count)
        for (i, node) in masterNodes.enumerated() where i < positions.master.count {
            nodePositions[node.id] = positions.master[i]
        }
        for (i, node) in workerNodes.enumerated() where i < positions.workers.count {
            nodePositions[node.id] = positions.workers[i]
        }
    }

    private func computeLayout(masterCount: Int, workerCount: Int) -> (master: [CGPoint], workers: [CGPoint]) {
        let cx: CGFloat = 400
        let masterY: CGFloat = 120
        let workerY: CGFloat = 320
        let masterPts = (0..<masterCount).map { i -> CGPoint in
            let offset = CGFloat(i - (masterCount - 1) / 2) * 140
            return CGPoint(x: cx + offset, y: masterY)
        }
        let workerPts = (0..<workerCount).map { i -> CGPoint in
            let spacing: CGFloat = 160
            let totalW = CGFloat(workerCount - 1) * spacing
            let startX = cx - totalW / 2
            return CGPoint(x: startX + CGFloat(i) * spacing, y: workerY)
        }
        return (masterPts, workerPts)
    }

    @ViewBuilder
    private func connectionsLayer(in size: CGSize) -> some View {
        Canvas { ctx, _ in
            for worker in workerNodes {
                guard let wPos = positionFor(worker.id, in: size) else { continue }
                for master in masterNodes {
                    guard let mPos = positionFor(master.id, in: size) else { continue }
                    var path = Path()
                    path.move(to: mPos)
                    path.addLine(to: wPos)
                    ctx.stroke(path, with: .color(theme.accent.opacity(0.25)), lineWidth: 2)
                }
            }
        }
    }

    @ViewBuilder
    private func nodesLayer(in size: CGSize) -> some View {
        ForEach(engine.nodes) { node in
            if let pos = positionFor(node.id, in: size) {
                topologyNodeView(node, at: pos)
            }
        }
    }

    private func positionFor(_ id: String, in size: CGSize) -> CGPoint? {
        guard let base = nodePositions[id] else { return nil }
        let offset = dragOffset[id] ?? .zero
        return CGPoint(x: base.x + offset.width, y: base.y + offset.height)
    }

    @ViewBuilder
    private func topologyNodeView(_ node: ClusterNode, at pos: CGPoint) -> some View {
        let isMaster = node.isMaster
        let size: CGFloat = isMaster ? 64 : 48
        let borderColor = node.isMaster ? theme.accent : statusColor(for: node)

        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(theme.surfaceElevated)
                    .frame(width: size, height: size)
                    .overlay(Circle().stroke(borderColor, lineWidth: 2))
                if node.effectiveStatus == .online {
                    PulseCircle(color: theme.greenDot, size: size + 8)
                }
                Text(String(node.hostname.prefix(2)))
                    .font(.system(size: isMaster ? 18 : 14, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)
            }
            Text(node.hostname)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .position(pos)
        .gesture(DragGesture()
            .onChanged { value in dragOffset[node.id] = value.translation }
            .onEnded { _ in
                if let base = nodePositions[node.id], let offset = dragOffset[node.id] {
                    nodePositions[node.id] = CGPoint(x: base.x + offset.width, y: base.y + offset.height)
                    dragOffset[node.id] = nil
                }
            }
        )
        .onTapGesture {
            appState.inspectorContext = .node(id: node.id)
            appState.isInspectorVisible = true
        }
    }

    private func statusColor(for node: ClusterNode) -> Color {
        switch node.effectiveStatus {
        case .online: theme.greenDot
        case .busy: theme.amberDot
        case .offline: theme.textTertiary
        case .fault: theme.redDot
        }
    }

    private var legendBar: some View {
        HStack(spacing: theme.spacingXL) {
            Label(i18n.t(.mn_topo_legendOnline), systemImage: "circle.fill")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.greenDot)
            Label(i18n.t(.mn_topo_legendBusy), systemImage: "circle.fill")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.amberDot)
            Label(i18n.t(.mn_topo_legendOffline), systemImage: "circle.fill")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            Label(i18n.t(.mn_topo_legendFault), systemImage: "circle.fill")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.redDot)
            Spacer()
            Text(String(format: i18n.t(.mn_topo_statsFmt), engine.nodes.count, onlineRate))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
        }
        .padding(theme.spacingM)
        .padding(.horizontal, theme.spacingL)
    }

    private var onlineRate: Int {
        guard engine.clusterStats.totalNodes > 0 else { return 0 }
        return Int(Double(engine.clusterStats.onlineNodes) / Double(engine.clusterStats.totalNodes) * 100)
    }
}

struct PulseCircle: View {
    let color: Color
    let size: CGFloat
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.25))
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0 : 0.5)
            .animation(.easeOut(duration: 2.0).repeatForever(autoreverses: false), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
