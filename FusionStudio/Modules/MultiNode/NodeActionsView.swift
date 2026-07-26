import SwiftUI
import os.log

private let actionsLog = Logger(subsystem: "com.fusion.studio", category: "NodeActions")

struct NodeActionsView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: "节点操作", subtitle: "弹性伸缩配置与节点管理")

                autoscalerSection
                nodeManagementSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear { engine.startPolling() }
        .onDisappear { engine.stopPolling() }
    }

    private var autoscalerSection: some View {
        ListGroup {
            StudioSectionHeader(title: "Autoscaler 弹性配置")
            AutoscalerConfigView()
        }
    }

    private var nodeManagementSection: some View {
        ListGroup {
            StudioSectionHeader(title: "节点管理")

            ForEach(engine.nodes) { node in
                HStack(spacing: theme.spacingM) {
                    Circle()
                        .fill(node.status == .online ? theme.greenDot : theme.redDot)
                        .frame(width: 8, height: 8)
                    Text(node.hostname)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text(node.ipAddress)
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    FusionButton("移除", style: .destructive, size: .small) {
                        Task { try? await engine.removeNode(nodeId: node.id) }
                    }
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
            }

            if engine.nodes.isEmpty {
                Text("暂无节点")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacing2XL)
            }
        }
    }
}

struct AutoscalerConfigView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme

    @State private var minNodes: Double = 2
    @State private var maxNodes: Double = 8
    @State private var scaleUpThreshold: Double = 0.8
    @State private var scaleDownThreshold: Double = 0.3
    @State private var cooldownSeconds: Double = 60
    @State private var strategy: String = "threshold"
    @State private var isApplying = false

    private let strategies = ["threshold", "queue_depth", "cpu_memory"]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            sliderRow(label: "最小节点", value: $minNodes, range: 1...32, step: 1, format: "%.0f")
            sliderRow(label: "最大节点", value: $maxNodes, range: 1...32, step: 1, format: "%.0f")
            sliderRow(label: "扩容阈值", value: $scaleUpThreshold, range: 0.1...1.0, step: 0.05, format: "%.2f")
            sliderRow(label: "缩容阈值", value: $scaleDownThreshold, range: 0.0...0.9, step: 0.05, format: "%.2f")
            sliderRow(label: "冷却时间 (s)", value: $cooldownSeconds, range: 10...300, step: 10, format: "%.0f")

            HStack(spacing: theme.spacingM) {
                Text("策略")
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Picker("", selection: $strategy) {
                    ForEach(strategies, id: \.self) { s in
                        Text(s).tag(s)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding(.horizontal, theme.spacingL)

            HStack {
                Spacer()
                FusionButton(isApplying ? "应用中..." : "应用配置", style: .primary, size: .regular) {
                    applyConfig()
                }
                .disabled(isApplying)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingM)
        }
        .onAppear { loadCurrentConfig() }
    }

    @ViewBuilder
    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) -> some View {
        HStack(spacing: theme.spacingM) {
            Text(label)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 120, alignment: .leading)
            Slider(value: value, in: range, step: step)
            Text(String(format: format, value.wrappedValue))
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func loadCurrentConfig() {
        let config = engine.autoscalerConfig
        minNodes = Double(config.minNodes)
        maxNodes = Double(config.maxNodes)
        scaleUpThreshold = config.scaleUpThreshold
        scaleDownThreshold = config.scaleDownThreshold
        cooldownSeconds = Double(config.cooldownSeconds)
        strategy = config.policy
    }

    private func applyConfig() {
        isApplying = true
        let config = AutoscalerConfig(
            enabled: true,
            minNodes: Int(minNodes),
            maxNodes: Int(maxNodes),
            scaleUpThreshold: scaleUpThreshold,
            scaleDownThreshold: scaleDownThreshold,
            cooldownSeconds: Int(cooldownSeconds),
            idleTimeoutSeconds: nil,
            policy: strategy,
            checkInterval: nil,
            rebalanceThreshold: nil
        )
        Task {
            do {
                try await engine.updateAutoscalerConfig(config)
                actionsLog.info("Autoscaler config applied successfully")
            } catch {
                actionsLog.error("Failed to apply autoscaler config: \(error.localizedDescription)")
            }
            isApplying = false
        }
    }
}
