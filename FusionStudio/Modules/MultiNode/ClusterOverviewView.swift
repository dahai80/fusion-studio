import SwiftUI
import os.log

private let overviewLog = Logger(subsystem: "com.fusion.studio", category: "ClusterOverview")

struct ClusterOverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "集群总览", subtitle: "实时监控集群节点状态与资源")

                UpstreamServiceStatusBanner(serviceId: "multi-node")

                clusterSyncBanner

                if !engine.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Multi-Node 服务未连接 — 请确认服务已启动 (port \(FusionConfig.shared.multiNodePort))")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundColor(.secondary)
                        if let err = engine.lastError {
                            Text(err)
                                .font(.system(size: theme.captionSize))
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(Color.orange.opacity(0.08))
                }

                metricsStrip
                actionBar
                nodeListSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear { engine.startPolling() }
        .onDisappear { engine.stopPolling() }
    }

    private var metricsStrip: some View {
        HStack(spacing: theme.spacingM) {
            MetricStripCard(icon: "server.rack", label: "节点", value: "\(engine.clusterStats.totalNodes)", subtitle: "总计", dotColor: theme.accent)
            MetricStripCard(icon: "checkmark.circle", label: "在线", value: "\(engine.clusterStats.onlineNodes)", subtitle: "在线运行", dotColor: theme.greenDot)
            MetricStripCard(icon: "list.bullet.clipboard", label: "活跃任务", value: "\(engine.clusterStats.activeTasks)", subtitle: "正在执行")
            MetricStripCard(icon: "memorychip", label: "集群内存", value: String(format: "%.0fGB", engine.clusterStats.availableMemoryGB), subtitle: String(format: "共 %.0fGB", engine.clusterStats.totalMemoryGB))
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingL)
    }

    private var actionBar: some View {
        HStack(spacing: theme.spacingM) {
            FusionButton("提交任务", style: .primary, size: .small) {
                appState.inspectorContext = .custom(title: "Submit Task")
            }
            FusionButton("Autoscaler", style: .secondary, size: .small) {
                appState.inspectorContext = .custom(title: "Autoscaler Config")
            }
            Spacer()
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("搜索节点...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
            .frame(width: 200)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingM)
    }

    private var filteredNodes: [ClusterNode] {
        if searchText.isEmpty { return engine.nodes }
        return engine.nodes.filter {
            $0.hostname.localizedCaseInsensitiveContains(searchText) ||
            $0.ipAddress.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var nodeListSection: some View {
        ListGroup {
            StudioSectionHeader(title: "节点列表 (\(filteredNodes.count))")
            ForEach(filteredNodes) { node in
                NodeRow(node: node, nodeLoad: engine.nodeLoads[node.id], isSelected: selectedNodeId == node.id) {
                    appState.inspectorContext = .node(id: node.id)
                    appState.isInspectorVisible = true
                }
                .contextMenu {
                    Button("查看指标") { engine.fetchNodeMetrics(nodeId: node.id) }
                    Button("移除节点", role: .destructive) {
                        Task { try? await engine.removeNode(nodeId: node.id) }
                    }
                }
                .overlay(alignment: .bottom) {
                    if node.id != filteredNodes.last?.id {
                        Rectangle().fill(theme.rowSep).frame(height: 0.5).padding(.horizontal, theme.spacingL)
                    }
                }
            }
        }
    }

    private var selectedNodeId: String? {
        if case .node(let id) = appState.inspectorContext { return id }
        return nil
    }

    private var clusterSyncBanner: some View {
        Group {
            if let status = engine.clusterSyncStatus {
                HStack(spacing: 8) {
                    Image(systemName: status.isDegraded ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(status.isDegraded ? .orange : .green)
                    Text(status.isDegraded
                         ? "集群处于降级状态 — 分区: \(status.partitionState)"
                         : "集群同步正常 — 分区: \(status.partitionState)")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundColor(.secondary)
                    Spacer()
                    NavigationLink(value: Module.clusterSync) {
                        Text("详情")
                            .font(.system(size: theme.captionSize, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(status.isDegraded ? Color.orange.opacity(0.08) : Color.green.opacity(0.06))
            }
        }
    }
}
