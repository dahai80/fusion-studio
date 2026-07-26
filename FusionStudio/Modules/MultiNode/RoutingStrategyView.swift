// Importers/callers: ModuleDetailView (routing .routingStrategy)
// Affected API: engine.fetchRoutingSummary(), engine.setRoutingStrategy()
// Data schemas: RoutingSummary, RoutingNodeInfo
// User verbatim: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let routingLog = Logger(subsystem: "com.fusion.studio", category: "RoutingStrategy")

struct RoutingStrategyView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme

    @State private var summary: RoutingSummary?
    @State private var selectedStrategy = "least_loaded"
    @State private var isApplying = false
    @State private var message: String?
    @State private var isError = false

    private let strategies = ["least_loaded", "round_robin", "random", "capability_aware"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "路由策略", subtitle: "配置集群任务路由策略与负载均衡")

                strategySection
                loadSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear {
            engine.startPolling()
            loadSummary()
        }
        .onDisappear { engine.stopPolling() }
    }

    private var strategySection: some View {
        ListGroup {
            StudioSectionHeader(title: "当前策略")

            StudioRow(label: "路由策略", sublabel: strategyDescription(selectedStrategy)) {
                Picker("", selection: $selectedStrategy) {
                    ForEach(strategies, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }

            if let msg = message {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(isError ? theme.redDot : theme.greenDot)
                    Text(msg)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(isError ? theme.errorText : theme.successText)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingXS)
            }

            HStack(spacing: theme.spacingM) {
                FusionButton("应用策略", icon: "arrow.triangle.branch", style: .primary, size: .small, isLoading: isApplying, isDisabled: isApplying) {
                    applyStrategy()
                }
                FusionButton("刷新", icon: "arrow.clockwise", style: .secondary, size: .small, isLoading: false, isDisabled: false) {
                    loadSummary()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
        }
    }

    private var loadSection: some View {
        Group {
            if let nodes = summary?.nodes, !nodes.isEmpty {
                ListGroup {
                    StudioSectionHeader(title: "节点负载分布")
                    ForEach(nodes) { node in
                        HStack(spacing: theme.spacingM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.nodeId)
                                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                                    .foregroundStyle(theme.text)
                                Text("\(node.activeTasks)/\(node.maxTasks) tasks")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", node.load * 100))
                                .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                                .foregroundStyle(loadColor(node.load))
                            ProgressView(value: node.load)
                                .progressViewStyle(.linear)
                                .tint(loadColor(node.load))
                                .frame(width: 80)
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingS)
                    }

                    if let avg = summary?.avgLoad {
                        HStack {
                            Text("平均负载")
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                            Spacer()
                            Text(String(format: "%.0f%%", avg * 100))
                                .font(.system(size: theme.footnoteSize, weight: .semibold, design: .monospaced))
                                .foregroundStyle(theme.text)
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.vertical, theme.spacingM)
                    }
                }
            }
        }
    }

    private func strategyDescription(_ s: String) -> String {
        switch s {
        case "least_loaded": return "优先分配给负载最低的节点"
        case "round_robin": return "轮流分配到各节点"
        case "random": return "随机选择节点"
        case "capability_aware": return "根据节点能力和任务需求匹配"
        default: return s
        }
    }

    private func loadColor(_ load: Double) -> Color {
        if load < 0.5 { return theme.greenDot }
        if load < 0.8 { return theme.amberDot }
        return theme.redDot
    }

    private func loadSummary() {
        engine.fetchRoutingSummary { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let s):
                    self.summary = s
                    self.selectedStrategy = s.strategy
                    routingLog.info("Routing summary loaded, strategy=\(s.strategy)")
                case .failure(let err):
                    routingLog.error("Routing summary failed: \(err.localizedDescription)")
                }
            }
        }
    }

    private func applyStrategy() {
        isApplying = true
        message = nil
        routingLog.info("Applying strategy: \(selectedStrategy)")

        Task {
            do {
                try await engine.setRoutingStrategy(selectedStrategy)
                await MainActor.run {
                    isApplying = false
                    message = "策略已更新为 \(selectedStrategy)"
                    isError = false
                    loadSummary()
                }
            } catch {
                routingLog.error("Strategy apply failed: \(error.localizedDescription)")
                await MainActor.run {
                    isApplying = false
                    message = error.localizedDescription
                    isError = true
                }
            }
        }
    }
}
