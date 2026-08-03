import SwiftUI
import os.log

struct HubDeploymentView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @State private var deployments: [HubDeployment] = []
    @State private var selectedDeployment: HubDeployment?
    @State private var showCreateSheet = false
    @State private var lastError: String?
    @State private var loading = false
    @State private var metrics: HubDeploymentMetricsResponse?

    private let depLog = Logger(subsystem: "com.fusion.studio", category: "HubDeployment")

    var body: some View {
        HStack(spacing: 0) {
            deploymentList
            Divider()
            deploymentDetail
        }
        .onAppear { loadDeployments() }
    }

    private var deploymentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("部署管理")
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus").font(.system(size: theme.textSize)).foregroundStyle(theme.accent)
                }.buttonStyle(.plain)
                Button(action: { loadDeployments() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: theme.textSize)).foregroundStyle(theme.textSecondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM).padding(.vertical, theme.spacingS)

            if loading {
                ProgressView().padding()
            } else if deployments.isEmpty {
                depEmpty("shippingbox", "暂无部署")
            } else {
                List(deployments, selection: $selectedDeployment) { dep in
                    DepRow(deployment: dep, theme: theme)
                        .tag(dep)
                        .onTapGesture { selectedDeployment = dep }
                }
                .listStyle(.sidebar)
            }

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal, theme.spacingM)
            }
        }
        .frame(minWidth: 280)
        .sheet(isPresented: $showCreateSheet) { createSheet }
    }

    private var deploymentDetail: some View {
        Group {
            if let dep = selectedDeployment {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingL) {
                        depHeader(dep)
                        depConfig(dep)
                        depMetrics(dep)
                        depActions(dep)
                    }
                    .padding(theme.spacingL)
                }
            } else {
                depEmpty("shippingbox", "选择一个部署查看详情")
            }
        }
    }

    private func depHeader(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Text(dep.modelName ?? dep.modelId ?? dep.id)
                    .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.text)
                depStatusBadge(dep.status)
            }
            HStack(spacing: theme.spacingM) {
                if let mid = dep.modelId {
                    Label(mid, systemImage: "cpu").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
                if let s = dep.scale {
                    Label("\(s) 副本", systemImage: "server.rack").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
                if let c = dep.canaryPercent {
                    Label("灰度 \(c)%", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private func depConfig(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("配置").font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            VStack(spacing: 4) {
                depConfigRow("ID", value: dep.id)
                if let m = dep.modelId { depConfigRow("模型", value: m) }
                if let n = dep.modelName { depConfigRow("模型名称", value: n) }
                if let s = dep.strategy { depConfigRow("策略", value: s) }
                if let sc = dep.scale { depConfigRow("副本数", value: "\(sc)") }
                if let c = dep.canaryPercent { depConfigRow("灰度比例", value: "\(c)%") }
                if let t = dep.createdAt { depConfigRow("创建时间", value: t) }
                if let t = dep.updatedAt { depConfigRow("更新时间", value: t) }
            }
            .padding(theme.spacingS)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
        }
    }

    private func depMetrics(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("指标").font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)

            HStack(spacing: theme.spacingM) {
                depMetricCard("请求/秒", value: metrics.flatMap { $0.requestsPerSecond.map { String(format: "%.1f", $0) } } ?? "--")
                depMetricCard("延迟(ms)", value: metrics.flatMap { $0.avgLatencyMs.map { String(format: "%.0f", $0) } } ?? "--")
                depMetricCard("错误率", value: metrics.flatMap { $0.errorRate.map { String(format: "%.2f%%", $0 * 100) } } ?? "--")
                depMetricCard("Tokens/s", value: metrics.flatMap { $0.tokensPerSecond.map { String(format: "%.0f", $0) } } ?? "--")
            }

            Button("刷新指标") { loadMetrics(dep) }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private func depActions(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("操作").font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingS) {
                if dep.isRunning {
                    Button("停止部署") { stopDep(dep) }
                        .buttonStyle(.bordered).foregroundStyle(.red)
                }
                Button("扩缩容") { scaleDep(dep) }
                    .buttonStyle(.bordered)
                Button("灰度发布") { grayDep(dep) }
                    .buttonStyle(.bordered)
                Button("删除部署") { deleteDep(dep) }
                    .buttonStyle(.bordered).foregroundStyle(.red)
            }
        }
    }

    private var createSheet: some View {
        CreateDepSheet(client: client, isPresented: $showCreateSheet) { loadDeployments() }
    }

    private func depStatusBadge(_ status: String?) -> some View {
        let (label, color) = depStatusInfo(status)
        return Text(label)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private func depStatusInfo(_ status: String?) -> (String, Color) {
        switch status {
        case "running", "active": return ("运行中", .green)
        case "stopped": return ("已停止", .gray)
        case "pending": return ("启动中", .orange)
        case "failed", "error": return ("失败", .red)
        default: return ("未知", .secondary)
        }
    }

    private func depMetricCard(_ title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            Text(title).font(.system(size: 9)).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(theme.spacingS)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
    }

    private func depConfigRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.text)
        }
    }

    private func depEmpty(_ icon: String, _ msg: String) -> some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: icon).font(.system(size: 32)).foregroundStyle(theme.textTertiary)
            Text(msg).font(.system(size: theme.textSize)).foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadDeployments() {
        loading = true
        Task { @MainActor in
            do {
                let resp = try await client.listDeployments()
                deployments = resp.deployments
                depLog.info("Loaded \(deployments.count) deployments")
            } catch {
                lastError = error.localizedDescription
                depLog.error("Load deployments failed: \(error.localizedDescription)")
            }
            loading = false
        }
    }

    private func stopDep(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                _ = try await client.stopDeployment(id: dep.id)
                depLog.info("Stopped deployment: \(dep.id)")
                loadDeployments()
            } catch {
                lastError = "停止失败: \(error.localizedDescription)"
            }
        }
    }

    private func scaleDep(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                _ = try await client.scaleDeployment(id: dep.id, scale: (dep.scale ?? 1) + 1)
                depLog.info("Scaled deployment: \(dep.id)")
                loadDeployments()
            } catch {
                lastError = "扩缩容失败: \(error.localizedDescription)"
            }
        }
    }

    private func grayDep(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                _ = try await client.grayReleaseDeployment(id: dep.id, canaryPercent: 10)
                depLog.info("Gray release: \(dep.id)")
                loadDeployments()
            } catch {
                lastError = "灰度发布失败: \(error.localizedDescription)"
            }
        }
    }

    private func deleteDep(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                _ = try await client.deleteDeployment(id: dep.id)
                deployments.removeAll { $0.id == dep.id }
                if selectedDeployment?.id == dep.id { selectedDeployment = nil }
                depLog.info("Deleted deployment: \(dep.id)")
            } catch {
                lastError = "删除失败: \(error.localizedDescription)"
            }
        }
    }

    private func loadMetrics(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                metrics = try await client.getDeploymentMetrics(id: dep.id)
                depLog.info("Loaded metrics for \(dep.id)")
            } catch {
                lastError = "获取指标失败: \(error.localizedDescription)"
            }
        }
    }
}

private struct DepRow: View {
    let deployment: HubDeployment
    let theme: StudioTheme
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(depColor).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(deployment.modelName ?? deployment.modelId ?? deployment.id)
                    .font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                HStack(spacing: 6) {
                    Text(deployment.statusLabel).font(.caption).foregroundStyle(.secondary)
                    if let s = deployment.strategy { Text(s).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Spacer()
            if let s = deployment.scale { Text("\(s)x").font(.caption).foregroundStyle(theme.textSecondary) }
        }
        .padding(.vertical, 4)
    }
    private var depColor: Color {
        switch deployment.status {
        case "running", "active": .green; case "stopped": .gray; case "pending": .orange
        case "failed", "error": .red; default: .secondary
        }
    }
}

private struct CreateDepSheet: View {
    @ObservedObject var client: ModelHubAPIClient
    @Binding var isPresented: Bool
    let onCreated: () -> Void
    @State private var modelId = ""
    @State private var strategy = ""
    @State private var scale = 1
    @State private var canaryPercent = 0
    @State private var error: String?
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text("创建部署").font(.title2).bold()
            Form {
                TextField("模型ID", text: $modelId)
                TextField("部署策略", text: $strategy)
                Stepper("副本数: \(scale)", value: $scale, in: 1...20)
                Stepper("灰度比例: \(canaryPercent)%", value: $canaryPercent, in: 0...100)
            }
            .formStyle(.grouped)
            if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("取消") { isPresented = false }.buttonStyle(.bordered)
                Button("创建") { create() }
                    .buttonStyle(.borderedProminent).disabled(modelId.isEmpty)
            }
        }
        .padding().frame(width: 420, height: 400)
    }

    private func create() {
        Task { @MainActor in
            do {
                _ = try await client.createDeployment(
                    modelId: modelId,
                    strategy: strategy.isEmpty ? nil : strategy,
                    scale: scale,
                    canaryPercent: canaryPercent > 0 ? canaryPercent : nil
                )
                isPresented = false; onCreated()
            } catch { self.error = error.localizedDescription }
        }
    }
}
