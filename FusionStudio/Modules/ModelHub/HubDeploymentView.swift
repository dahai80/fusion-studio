import SwiftUI
import os.log

struct HubDeploymentView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
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
                Text(i18n.t(.hub_dep_management))
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
                depEmpty("shippingbox", i18n.t(.hub_dep_empty))
            } else {
                List(deployments, selection: $selectedDeployment) { dep in
                    DepRow(deployment: dep, theme: theme)
                        .tag(dep)
                        .onTapGesture { selectedDeployment = dep }
                }
                .listStyle(.sidebar)
            }

            if let error = lastError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, theme.spacingM)
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
                depEmpty("shippingbox", i18n.t(.hub_dep_selectHint))
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
                    Label(String(format: i18n.t(.hub_dep_replicasFmt), "\(s)"), systemImage: "server.rack").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
                if let c = dep.canaryPercent {
                    Label(String(format: i18n.t(.hub_dep_canaryFmt), c), systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textSecondary)
                }
            }
        }
    }

    private func depConfig(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.hub_dep_config)).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            VStack(spacing: 4) {
                depConfigRow("ID", value: dep.id)
                if let m = dep.modelId { depConfigRow(i18n.t(.hub_dep_model), value: m) }
                if let n = dep.modelName { depConfigRow(i18n.t(.hub_dep_modelName), value: n) }
                if let s = dep.strategy { depConfigRow(i18n.t(.hub_dep_strategy), value: s) }
                if let sc = dep.scale { depConfigRow(i18n.t(.hub_dep_replicasCount), value: "\(sc)") }
                if let c = dep.canaryPercent { depConfigRow(i18n.t(.hub_dep_canaryRatio), value: "\(c)%") }
                if let t = dep.createdAt { depConfigRow(i18n.t(.hub_dep_createdAt), value: t) }
                if let t = dep.updatedAt { depConfigRow(i18n.t(.hub_dep_updatedAt), value: t) }
            }
            .padding(theme.spacingS)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3)).cornerRadius(8)
        }
    }

    private func depMetrics(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.hub_dep_metrics)).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)

            HStack(spacing: theme.spacingM) {
                depMetricCard(i18n.t(.hub_dep_reqPerSec), value: metrics.flatMap { $0.requestsPerSecond.map { String(format: "%.1f", $0) } } ?? "--")
                depMetricCard(i18n.t(.hub_dep_latencyMs), value: metrics.flatMap { $0.avgLatencyMs.map { String(format: "%.0f", $0) } } ?? "--")
                depMetricCard(i18n.t(.hub_dep_errorRate), value: metrics.flatMap { $0.errorRate.map { String(format: "%.2f%%", $0 * 100) } } ?? "--")
                depMetricCard("Tokens/s", value: metrics.flatMap { $0.tokensPerSecond.map { String(format: "%.0f", $0) } } ?? "--")
            }

            Button(i18n.t(.hub_dep_refreshMetrics)) { loadMetrics(dep) }
                .buttonStyle(.bordered).controlSize(.small)
        }
    }

    private func depActions(_ dep: HubDeployment) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.hub_dep_actions)).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingS) {
                if dep.isRunning {
                    Button(i18n.t(.hub_dep_stopDep)) { stopDep(dep) }
                        .buttonStyle(.bordered).foregroundStyle(.red)
                }
                Button(i18n.t(.hub_dep_scale)) { scaleDep(dep) }
                    .buttonStyle(.bordered)
                Button(i18n.t(.hub_dep_grayRelease)) { grayDep(dep) }
                    .buttonStyle(.bordered)
                Button(i18n.t(.hub_dep_deleteDep)) { deleteDep(dep) }
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
        case "running", "active": return (i18n.t(.hub_dep_stRunning), .green)
        case "stopped": return (i18n.t(.hub_dep_stStopped), .gray)
        case "pending": return (i18n.t(.hub_dep_stPending), .orange)
        case "failed", "error": return (i18n.t(.hub_dep_stFailed), .red)
        default: return (i18n.t(.hub_dep_stUnknown), .secondary)
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
                lastError = BridgeError.sanitize(error)
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
                lastError = String(format: i18n.t(.hub_dep_stopFailFmt), error.localizedDescription)
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
                lastError = String(format: i18n.t(.hub_dep_scaleFailFmt), error.localizedDescription)
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
                lastError = String(format: i18n.t(.hub_dep_grayFailFmt), error.localizedDescription)
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
                lastError = String(format: i18n.t(.hub_dep_deleteFailFmt), error.localizedDescription)
            }
        }
    }

    private func loadMetrics(_ dep: HubDeployment) {
        Task { @MainActor in
            do {
                metrics = try await client.getDeploymentMetrics(id: dep.id)
                depLog.info("Loaded metrics for \(dep.id)")
            } catch {
                lastError = String(format: i18n.t(.hub_dep_metricsFailFmt), error.localizedDescription)
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
    @StateObject private var i18n = I18nManager.shared
    @State private var modelId = ""
    @State private var strategy = ""
    @State private var scale = 1
    @State private var canaryPercent = 0
    @State private var error: String?
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.hub_dep_createDep)).font(.title2).bold()
            Form {
                TextField(i18n.t(.hub_dep_modelId), text: $modelId)
                TextField(i18n.t(.hub_dep_depStrategy), text: $strategy)
                Stepper(String(format: i18n.t(.hub_dep_replicasStepperFmt), scale), value: $scale, in: 1...20)
                Stepper(String(format: i18n.t(.hub_dep_canaryStepperFmt), canaryPercent), value: $canaryPercent, in: 0...100)
            }
            .formStyle(.grouped)
            if let error = error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Button(i18n.t(.cancel)) { isPresented = false }.buttonStyle(.bordered)
                Button(i18n.t(.hub_dep_createDep)) { create() }
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
            } catch { self.error = BridgeError.sanitize(error) }
        }
    }
}
