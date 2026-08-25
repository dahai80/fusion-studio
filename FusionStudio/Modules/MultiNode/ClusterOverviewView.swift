import SwiftUI
import os.log

private let overviewLog = Logger(subsystem: "com.fusion.studio", category: "ClusterOverview")

struct ClusterOverviewView: View {
    @EnvironmentObject var uiPanelState: UIPanelState
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_overview_title), subtitle: i18n.t(.mn_overview_subtitle))

                UpstreamServiceStatusBanner(serviceId: "multi-node")

                clusterSyncBanner

                if !engine.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(String(format: i18n.t(.mn_overview_disconnectedFmt), FusionConfig.shared.multiNodePort))
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
    }

    private var metricsStrip: some View {
        HStack(spacing: theme.spacingM) {
            MetricStripCard(icon: "server.rack", label: i18n.t(.mn_overview_metricNodes), value: "\(engine.clusterStats.totalNodes)", subtitle: i18n.t(.mn_overview_metricTotal), dotColor: theme.accent)
            MetricStripCard(icon: "checkmark.circle", label: i18n.t(.mn_overview_metricOnline), value: "\(engine.clusterStats.onlineNodes)", subtitle: i18n.t(.mn_overview_metricOnlineRun), dotColor: theme.greenDot)
            MetricStripCard(icon: "list.bullet.clipboard", label: i18n.t(.mn_overview_metricActiveTasks), value: "\(engine.clusterStats.activeTasks)", subtitle: i18n.t(.mn_overview_metricExecuting))
            MetricStripCard(icon: "memorychip", label: i18n.t(.mn_overview_metricClusterMem), value: String(format: "%.0fGB", engine.clusterStats.availableMemoryGB), subtitle: String(format: i18n.t(.mn_overview_metricTotalMemFmt), String(format: "%.0f", engine.clusterStats.totalMemoryGB)))
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingL)
    }

    private var actionBar: some View {
        HStack(spacing: theme.spacingM) {
            FusionButton(i18n.t(.mn_overview_submitTaskBtn), style: .primary, size: .small) {
                uiPanelState.inspectorContext = .custom(title: "Submit Task")
            }
            FusionButton("Autoscaler", style: .secondary, size: .small) {
                uiPanelState.inspectorContext = .custom(title: "Autoscaler Config")
            }
            Spacer()
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField(i18n.t(.mn_overview_searchPh), text: $searchText)
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
            StudioSectionHeader(title: String(format: i18n.t(.mn_overview_nodeListFmt), filteredNodes.count))
            ForEach(filteredNodes) { node in
                NodeRow(node: node, nodeLoad: engine.nodeLoads[node.id], isSelected: selectedNodeId == node.id) {
                    uiPanelState.inspectorContext = .node(id: node.id)
                    uiPanelState.isInspectorVisible = true
                }
                .contextMenu {
                    Button(i18n.t(.mn_overview_viewMetrics)) { engine.fetchNodeMetrics(nodeId: node.id) }
                    Button(i18n.t(.mn_overview_removeNode), role: .destructive) {
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
        if case .node(let id) = uiPanelState.inspectorContext { return id }
        return nil
    }

    private var clusterSyncBanner: some View {
        Group {
            if let status = engine.clusterSyncStatus {
                HStack(spacing: 8) {
                    Image(systemName: status.isDegraded ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(status.isDegraded ? .orange : .green)
                    Text(status.isDegraded
                         ? String(format: i18n.t(.mn_overview_degradedFmt), status.partitionState)
                         : String(format: i18n.t(.mn_overview_normalFmt), status.partitionState))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundColor(.secondary)
                    Spacer()
                    NavigationLink(value: Module.clusterSync) {
                        Text(i18n.t(.mn_overview_detailLink))
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
