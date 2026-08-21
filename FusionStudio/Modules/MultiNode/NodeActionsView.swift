import SwiftUI
import os.log

private let actionsLog = Logger(subsystem: "com.fusion.studio", category: "NodeActions")

struct NodeActionsView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_node_title), subtitle: i18n.t(.mn_node_subtitle))

                pendingApprovalSection
                autoscalerSection
                nodeManagementSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
        .onAppear { engine.startPolling() }
        .onDisappear { engine.stopPolling() }
    }

    private var pendingApprovalSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_node_pendingTitle))

            ForEach(engine.pendingNodes) { node in
                HStack(spacing: theme.spacingM) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.hostname)
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        Text("\(node.ipAddress):\(node.port)")
                            .font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Spacer()
                    FusionButton(i18n.t(.mn_node_approveBtn), style: .primary, size: .small) {
                        Task { try? await engine.approveNode(nodeId: node.id) }
                    }
                    FusionButton(i18n.t(.mn_node_rejectBtn), style: .destructive, size: .small) {
                        Task { try? await engine.rejectNode(nodeId: node.id) }
                    }
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
            }

            if engine.pendingNodes.isEmpty {
                Text(i18n.t(.mn_node_pendingEmpty))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacing2XL)
            }
        }
    }

    private var autoscalerSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_node_autoscalerTitle))
            AutoscalerConfigView()
        }
    }

    private var nodeManagementSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_node_mgmtTitle))

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
                    FusionButton(i18n.t(.mn_node_removeBtn), style: .destructive, size: .small) {
                        Task { try? await engine.removeNode(nodeId: node.id) }
                    }
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
            }

            if engine.nodes.isEmpty {
                Text(i18n.t(.mn_node_emptyNodes))
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
    @StateObject private var i18n = I18nManager.shared

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
            sliderRow(label: i18n.t(.mn_node_minNodes), value: $minNodes, range: 1...32, step: 1, format: "%.0f")
            sliderRow(label: i18n.t(.mn_node_maxNodes), value: $maxNodes, range: 1...32, step: 1, format: "%.0f")
            sliderRow(label: i18n.t(.mn_node_scaleUpThreshold), value: $scaleUpThreshold, range: 0.1...1.0, step: 0.05, format: "%.2f")
            sliderRow(label: i18n.t(.mn_node_scaleDownThreshold), value: $scaleDownThreshold, range: 0.0...0.9, step: 0.05, format: "%.2f")
            sliderRow(label: i18n.t(.mn_node_cooldownLabel), value: $cooldownSeconds, range: 10...300, step: 10, format: "%.0f")

            HStack(spacing: theme.spacingM) {
                Text(i18n.t(.mn_node_strategyLabel))
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
                FusionButton(isApplying ? i18n.t(.mn_node_applying) : i18n.t(.mn_node_applyBtn), style: .primary, size: .regular) {
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
