// Callers: ModelHubMainView contentArea switch on .cluster.
// Affected API: ModelHubAPIClient listClusterNodes/syncClusterModel/routeInference/getClusterTopology.
// Data schemas: HubClusterNode, HubClusterTopologyResponse, HubClusterEdge.
// PRD: Cluster scheduling + topology + node management
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

import SwiftUI
import os.log

private let clusterLog = Logger(subsystem: "com.fusion.studio", category: "HubCluster")

struct HubClusterView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var nodes: [HubClusterNode] = []
    @State private var topology: HubClusterTopologyResponse?
    @State private var selectedNode: HubClusterNode?
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var syncModelId = ""
    @State private var showSyncSheet = false
    @State private var pollTimer: Timer?
    @State private var routeModelId = ""
    @State private var routeMode = "auto"
    @State private var routePrompt = ""
    @State private var routeResult: HubInferenceResponse?
    @State private var localModels: [HubModel] = []
    @State private var isRouting = false

    private let routeModes = ["auto", "local", "cluster"]

    var body: some View {
        HStack(spacing: 0) {
            nodeListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            nodeDetailPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAll(); startPolling() }
        .onDisappear { stopPolling() }
        .sheet(isPresented: $showSyncSheet) { syncSheet }
    }

    // MARK: - Node List

    private var nodeListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("集群节点")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                let onlineCount = nodes.filter(\.isOnline).count
                Text("\(onlineCount)/\(nodes.count) 在线")
                    .font(.caption)
                    .foregroundStyle(onlineCount > 0 ? .green : .red)
                Button(action: { Task { await loadAll() } }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                Button("同步模型") { showSyncSheet = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(theme.spacingM)

            Divider()

            if isLoading && nodes.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if nodes.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "server.rack").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("暂无集群节点")
                        .foregroundStyle(theme.textSecondary)
                    Text("确保多台 Mac 在同一网络并启动 Model Hub 服务")
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(nodes, selection: $selectedNode) { node in
                    ClusterNodeRow(node: node)
                        .tag(node)
                        .onTapGesture { selectedNode = node }
                }
                .listStyle(.plain)
            }

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
        .frame(minWidth: 350, maxWidth: 500)
    }

    // MARK: - Node Detail

    private var nodeDetailPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                if let node = selectedNode {
                    nodeDetailContent(node: node)
                } else {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "server.rack").font(.system(size: 48)).foregroundStyle(.secondary)
                        Text("选择节点查看详情")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                inferenceRouteSection
                routeResultSection
            }
            .padding(theme.spacingL)
        }
    }

    private func nodeDetailContent(node: HubClusterNode) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(node.name ?? node.id)
                    .font(.system(size: theme.largeTitleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Image(systemName: node.healthStatus.icon)
                    .foregroundStyle(colorForHealth(node.healthStatus))
            }

            HStack(spacing: theme.spacingM) {
                HubTagBadge(text: node.status ?? "unknown", color: node.isOnline ? .green : .red)
                if let gpu = node.gpuType { HubTagBadge(text: gpu, color: .purple) }
                if let mem = node.memoryGB { HubTagBadge(text: String(format: "%.0f GB", mem), color: .cyan) }
            }

            GroupBox("节点信息") {
                VStack(alignment: .leading, spacing: 6) {
                    HubDetailCell(label: "ID", value: node.id)
                    if let host = node.host, let port = node.port {
                        HubDetailCell(label: "地址", value: "\(host):\(port)")
                    }
                    if let lastSeen = node.lastSeen {
                        HubDetailCell(label: "最近上线", value: lastSeen)
                    }
                }
            }

            GroupBox("资源使用") {
                VStack(spacing: theme.spacingS) {
                    if let cpu = node.cpuUsage {
                        resourceBar(label: "CPU", value: cpu, color: .blue)
                    }
                    if let gpu = node.gpuUsage {
                        resourceBar(label: "GPU", value: gpu, color: .green)
                    }
                    if let memUsed = node.memoryUsed, let memTotal = node.memoryGB {
                        resourceBar(label: "内存", value: memUsed / memTotal, color: .orange)
                    }
                }
            }

            if let models = node.models, !models.isEmpty {
                GroupBox("本地模型 (\(models.count))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(models, id: \.self) { m in
                                Text(m)
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var inferenceRouteSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("自动调度推理")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text("本地优先，集群回退")
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                Picker("模型", selection: $routeModelId) {
                    Text("选择模型...").tag("")
                    ForEach(localModels) { m in
                        Text(m.displayTitle).tag(m.id)
                    }
                }
                .pickerStyle(.menu)

                Picker("调度模式", selection: $routeMode) {
                    ForEach(routeModes, id: \.self) { m in
                        Text(routeModeLabel(m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                TextField("输入推理提示词...", text: $routePrompt)
                    .textFieldStyle(.roundedBorder)

                Button(action: sendRouteRequest) {
                    HStack {
                        if isRouting { ProgressView().controlSize(.small) }
                        Text("发送推理请求")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(routeModelId.isEmpty || routePrompt.isEmpty || isRouting)

                if let err = lastError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(8)
        }
    }

    private var routeResultSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                Text("推理结果")
                    .font(.system(size: theme.headlineSize, weight: .semibold))
                    .foregroundStyle(theme.text)

                if let result = routeResult {
                    if let routedTo = result.routedTo {
                        HStack {
                            Text("路由到:").font(.caption).foregroundStyle(.secondary)
                            Text(routedTo).font(.caption).foregroundStyle(.green)
                            if let mode = result.routeMode {
                                Text("(\(routeModeLabel(mode)))").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let content = result.content {
                        Text(content)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                            .textSelection(.enabled)
                    }
                    if let usage = result.usage {
                        HStack(spacing: theme.spacingM) {
                            if let pt = usage.promptTokens { Text("Prompt: \(pt)").font(.caption).foregroundStyle(.secondary) }
                            if let ct = usage.completionTokens { Text("Completion: \(ct)").font(.caption).foregroundStyle(.secondary) }
                            if let tt = usage.totalTokens { Text("Total: \(tt)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                } else {
                    Text("发送推理请求后查看结果")
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(8)
        }
    }

    private func resourceBar(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: theme.spacingS) {
            Text(label).frame(width: 40, alignment: .leading).font(.caption).foregroundStyle(theme.textSecondary)
            ProgressView(value: value)
                .tint(value > 0.9 ? .red : color)
            Text(String(format: "%.0f%%", value * 100))
                .font(.caption2)
                .foregroundStyle(value > 0.9 ? .red : theme.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Sync Sheet

    private var syncSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("同步模型至集群").font(.title2).bold()
            Picker("模型", selection: $syncModelId) {
                Text("选择模型...").tag("")
                ForEach(localModels) { m in
                    Text(m.displayTitle).tag(m.id)
                }
            }
            .pickerStyle(.menu)
            Text("将指定模型文件同步至所有在线集群节点")
                .font(.caption)
                .foregroundStyle(theme.textTertiary)
            HStack {
                Button("取消") { showSyncSheet = false }.buttonStyle(.bordered)
                Button("开始同步") {
                    syncModel()
                    showSyncSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncModelId.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Helpers

    private func colorForHealth(_ health: HubNodeHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .overloaded: return .orange
        case .offline: return .red
        }
    }

    // MARK: - Data

    private func loadAll() async {
        isLoading = true
        do {
            async let nodesResp = client.listClusterNodes()
            async let topoResp = client.getClusterTopology()
            async let modelsResp = client.listModels()
            let nodesResult = try await nodesResp
            let topoResult = try await topoResp
            let modelsResult = try await modelsResp
            nodes = nodesResult.nodes
            topology = topoResult
            localModels = modelsResult.models.filter { $0.isDownloaded == true }
            clusterLog.info("Cluster: \(nodes.count) nodes, \(localModels.count) models loaded")
        } catch {
            lastError = error.localizedDescription
            clusterLog.warning("Cluster load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func sendRouteRequest() {
        guard !routeModelId.isEmpty, !routePrompt.isEmpty else { return }
        isRouting = true
        lastError = nil
        Task { @MainActor in
            do {
                let messages = [["role": "user", "content": routePrompt]]
                let result = try await client.routeInference(
                    modelId: routeModelId,
                    messages: messages,
                    mode: routeMode
                )
                routeResult = result
                clusterLog.info("Inference routed: \(routeModelId) mode=\(routeMode) -> \(result.routedTo ?? "unknown")")
            } catch {
                lastError = error.localizedDescription
                clusterLog.error("Route inference failed: \(error.localizedDescription)")
            }
            isRouting = false
        }
    }

    private func routeModeLabel(_ m: String) -> String {
        switch m {
        case "auto": return "自动"
        case "local": return "本地优先"
        case "cluster": return "集群"
        default: return m
        }
    }

    private func syncModel() {
        let modelId = syncModelId
        Task { @MainActor in
            do {
                _ = try await client.syncClusterModel(modelId: modelId)
                clusterLog.info("Model sync started: \(modelId)")
                syncModelId = ""
                await loadAll()
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { await loadAll() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

private struct ClusterNodeRow: View {
    let node: HubClusterNode
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: node.healthStatus.icon)
                .foregroundStyle(colorForHealth(node.healthStatus))
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name ?? node.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 8) {
                    if let gpu = node.gpuType { Text(gpu).font(.caption).foregroundStyle(.secondary) }
                    if let mem = node.memoryGB { Text(String(format: "%.0fGB", mem)).font(.caption).foregroundStyle(.secondary) }
                    if let cnt = node.models?.count { Text("\(cnt) 模型").font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if let cpu = node.cpuUsage {
                Text(String(format: "CPU %.0f%%", cpu * 100))
                    .font(.caption2)
                    .foregroundStyle(cpu > 0.9 ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForHealth(_ health: HubNodeHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .overloaded: return .orange
        case .offline: return .red
        }
    }
}
