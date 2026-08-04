// Callers: SectionContentView (.simulation section), ModuleDetailView (.simulation module).
// Affected API: SimulationWorkbenchView - 4-zone GUI for fusion-sim (scene/entity mgmt, monitor, inspector, transport).
// Data schemas: SimulationBridge @Published state (status/lastStepResult/envCheck/observations/agents/sensors).
// User instruction: "fusion-studio负责GUI，和~/fusion/fuison-simulation项目集成起来，包括GUI和workflow，usercase，全面集成"

import SwiftUI
import os.log

private let simViewLog = Logger(subsystem: "com.fusion.studio", category: "SimulationWorkbenchView")

struct SimulationWorkbenchView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var bridge: SimulationBridge
    @EnvironmentObject var upstream: UpstreamServiceManager

    @State private var selectedScene = "default"
    @State private var pollTimer: Timer?

    @State private var agentName = "agent0"
    @State private var agentRole = "robot"
    @State private var agentActionDim = "6"
    @State private var agentEntityId = ""
    @State private var agentModel = "qwen3.5-9b"

    @State private var sensorType = "rgb_camera"
    @State private var sensorName = "cam0"
    @State private var sensorEntityId = ""

    @State private var stepCount = 1
    @State private var inspectorTab = 0

    @State private var snapshotName = ""
    @State private var restoreId = ""
    @State private var lastSavedId: String?

    private let scenes = ["default", "pick", "push"]
    private let roles = ["robot", "observer", "controller"]
    private let sensorTypes = ["rgb_camera", "depth_camera", "segmentation_camera", "imu", "force_torque", "joint_encoder", "contact"]
    private let stepOptions = [1, 10, 100]

    var body: some View {
        VStack(spacing: 0) {
            UpstreamServiceStatusBanner(serviceId: "fusion-simulation")
            Rectangle().fill(theme.separator).frame(height: 1)

            HSplitView {
                entityPanel.frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
                monitorPanel.frame(minWidth: 360, idealWidth: 560)
                inspectorPanel.frame(minWidth: 240, idealWidth: 300, maxWidth: 380)
            }
            .background(theme.contentBg)

            Rectangle().fill(theme.separator).frame(height: 1)
            transportBar
        }
        .background(theme.contentBg)
        .onAppear {
            bridge.checkHealth()
            bridge.envCheckRequest()
            simViewLog.info("SimulationWorkbenchView appeared")
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: bridge.status?.running) { _, running in
            if running == true { startPolling() } else { stopPolling() }
        }
    }

    // MARK: - Left: Scene / Agent / Sensor management

    private var entityPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                sceneSection
                agentSection
                sensorSection
            }
            .padding(theme.spacingL)
        }
        .background(theme.surfacePrimary)
    }

    private var sceneSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("场景", systemImage: "cube.box.fill").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            Picker("Scene", selection: $selectedScene) {
                ForEach(scenes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            FusionButton("加载场景", icon: "square.and.arrow.down", style: .secondary, size: .small) {
                simViewLog.info("Load scene: \(self.selectedScene)")
                bridge.loadScene(name: selectedScene)
            }
        }
    }

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("智能体", systemImage: "person.crop.square.filled.and.at.rectangle").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            labeledField("名称", text: $agentName)
            Picker("Role", selection: $agentRole) {
                ForEach(roles, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.segmented)
            HStack(spacing: theme.spacingS) {
                labeledField("动作维度", text: $agentActionDim)
                labeledField("Entity", text: $agentEntityId)
            }
            labeledField("模型", text: $agentModel)
            FusionButton("添加智能体", icon: "plus.circle", style: .secondary, size: .small) {
                let dim = Int(agentActionDim) ?? 0
                simViewLog.info("Add agent: \(self.agentName) role=\(self.agentRole) dim=\(dim) model=\(self.agentModel)")
                bridge.addAgent(name: agentName, role: agentRole, actionDim: dim, entityId: agentEntityId, modelName: agentModel)
            }
            entityList(bridge.agents, icon: "person.fill")
        }
    }

    private var sensorSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("传感器", systemImage: "camera.metering.matrix").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            Picker("Type", selection: $sensorType) {
                ForEach(sensorTypes, id: \.self) { Text($0).tag($0) }
            }.pickerStyle(.menu)
            labeledField("名称", text: $sensorName)
            labeledField("Entity", text: $sensorEntityId)
            FusionButton("添加传感器", icon: "plus.viewfinder", style: .secondary, size: .small) {
                simViewLog.info("Add sensor: \(self.sensorName) type=\(self.sensorType)")
                bridge.addSensor(type: sensorType, name: sensorName, entityId: sensorEntityId)
            }
            entityList(bridge.sensors, icon: "camera.fill")
        }
    }

    // MARK: - Center: Monitor

    private var monitorPanel: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                statusGrid
                timingSection
                observationsSection
            }
            .padding(theme.spacingL)
        }
        .background(theme.contentBg)
    }

    private var statusGrid: some View {
        let s = bridge.status
        let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: cols, spacing: theme.spacingS) {
            metricCell("状态", s?.state ?? "-", color: s?.running == true ? theme.greenDot : (s?.paused == true ? theme.amberDot : theme.textTertiary))
            metricCell("仿真时间", String(format: "%.2f s", s?.simTime ?? 0))
            metricCell("帧数", "\(s?.frameCount ?? 0)")
            metricCell("实体数", "\(s?.entityCount ?? 0)")
            metricCell("实时因子", String(format: "%.2fx", s?.realTimeFactor ?? 0))
            metricCell("已初始化", (s?.initialized ?? false) ? "是" : "否")
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("最近一步耗时", systemImage: "timer").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            if let step = bridge.lastStepResult {
                timingBar("物理", step.physicsStepMs, total: step.totalMs)
                timingBar("传感器", step.sensorCollectMs, total: step.totalMs)
                timingBar("决策", step.agentDecideMs, total: step.totalMs)
                timingBar("渲染", step.renderMs, total: step.totalMs)
                HStack {
                    Text("合计").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
                    Spacer()
                    Text(String(format: "%.2f ms", step.totalMs)).font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.accent)
                }
            } else {
                Text("尚未执行 step").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
            }
        }
    }

    private var observationsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Label("观测", systemImage: "eye").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button { bridge.fetchObservations() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless).help("刷新观测")
            }
            if bridge.observations.isEmpty {
                Text("无观测数据").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(bridge.observations.keys.sorted(), id: \.self) { key in
                    observationRow(name: key, payload: bridge.observations[key] ?? [:])
                }
            }
        }
    }

    // MARK: - Right: Inspector

    private var inspectorPanel: some View {
        VStack(spacing: 0) {
            FusionTabBar(selected: $inspectorTab, tabs: [
                FusionTabItem(title: "状态", icon: "chart.bar"),
                FusionTabItem(title: "环境", icon: "checkmark.shield"),
                FusionTabItem(title: "快照", icon: "camera.metering.center.weighted"),
            ])
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView(showsIndicators: false) {
                Group {
                    switch inspectorTab {
                    case 0: statusInspector
                    case 1: envInspector
                    default: snapshotInspector
                    }
                }
                .padding(theme.spacingL)
            }
        }
        .background(theme.surfacePrimary)
    }

    private var statusInspector: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            if let s = bridge.status {
                statusRow("initialized", s.initialized == true ? "true" : "false")
                statusRow("running", s.running == true ? "true" : "false")
                statusRow("state", s.state ?? "-")
                statusRow("sim_time", String(format: "%.3f", s.simTime ?? 0))
                statusRow("frame_count", "\(s.frameCount ?? 0)")
                statusRow("entity_count", "\(s.entityCount ?? 0)")
                statusRow("real_time_factor", String(format: "%.3f", s.realTimeFactor ?? 0))
                statusRow("paused", s.paused == true ? "true" : "false")
            } else {
                Text("无状态数据").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
            }
        }
    }

    private var envInspector: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            if bridge.envCheck.isEmpty {
                Text("环境检查未运行").font(.system(size: theme.footnoteSize)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(bridge.envCheck.keys.sorted(), id: \.self) { key in
                    let comp = bridge.envCheck[key]
                    HStack(spacing: theme.spacingS) {
                        Circle().fill(comp?.available == true ? theme.greenDot : theme.redDot).frame(width: 8, height: 8)
                        Text(key).font(.system(size: theme.footnoteSize)).foregroundStyle(theme.text)
                        Spacer()
                        Text(comp?.version ?? "").font(.system(size: 11)).foregroundStyle(theme.textTertiary)
                    }
                }
            }
            FusionButton("重新检查", icon: "arrow.clockwise", style: .secondary, size: .small) {
                bridge.envCheckRequest()
            }
        }
    }

    private var snapshotInspector: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("保存快照", systemImage: "square.and.arrow.down").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            labeledField("名称(可选)", text: $snapshotName)
            FusionButton("保存", icon: "camera", style: .secondary, size: .small) {
                bridge.saveSnapshot(name: snapshotName) { result in
                    if case .success(let resp) = result, let id = resp.snapshotId {
                        DispatchQueue.main.async { self.lastSavedId = id }
                    }
                }
            }
            if let id = lastSavedId {
                Text("最近快照: \(id)").font(.system(size: 11)).foregroundStyle(theme.textSecondary).lineLimit(1)
            }
            Divider().background(theme.separator)
            Label("恢复快照", systemImage: "arrow.uturn.backward").font(.system(size: theme.footnoteSize, weight: .semibold)).foregroundStyle(theme.text)
            labeledField("Snapshot ID", text: $restoreId)
            FusionButton("恢复", icon: "arrow.uturn.backward.circle", style: .secondary, size: .small) {
                bridge.restoreSnapshot(snapshotId: restoreId)
            }
        }
    }

    // MARK: - Bottom: Transport

    private var transportBar: some View {
        HStack(spacing: theme.spacingM) {
            FusionButton("初始化", icon: "power", style: .secondary, size: .small, isLoading: bridge.isLoading) {
                simViewLog.info("Init sim")
                bridge.initSim()
            }
            Divider().frame(height: 20)
            Picker("Steps", selection: $stepCount) {
                ForEach(stepOptions, id: \.self) { Text("\($0) 步").tag($0) }
            }.pickerStyle(.segmented).frame(width: 200)
            FusionButton("Step", icon: "forward.fill", style: .primary, size: .small, isLoading: bridge.isLoading) {
                simViewLog.info("Step \(self.stepCount)")
                bridge.step(numSteps: stepCount) { _ in bridge.fetchObservations() }
            }
            Divider().frame(height: 20)
            FusionButton("暂停", icon: "pause.fill", style: .secondary, size: .small) {
                bridge.pause()
            }
            FusionButton("继续", icon: "play.fill", style: .secondary, size: .small) {
                bridge.resume()
            }
            Divider().frame(height: 20)
            FusionButton("重置", icon: "arrow.counterclockwise", style: .secondary, size: .small) {
                simViewLog.info("Reset sim")
                bridge.reset()
            }
            Spacer()
            if let err = bridge.lastError {
                Text(err).font(.system(size: 11)).foregroundStyle(theme.accentDestructive).lineLimit(1)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    // MARK: - Helpers

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            bridge.fetchStatus()
            bridge.fetchObservations()
        }
        simViewLog.info("Polling started (1s)")
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: theme.footnoteSize))
        }
    }

    private func entityList(_ items: [SimEntityInfo], icon: String) -> some View {
        Group {
            if items.isEmpty {
                Text("暂无").font(.system(size: 11)).foregroundStyle(theme.textTertiary)
            } else {
                ForEach(items) { info in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: icon).font(.system(size: 11)).foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(info.name).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.text)
                            Text("\(info.kind) · \(info.detail)").font(.system(size: 10)).foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
        }
    }

    private func metricCell(_ label: String, _ value: String, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
            HStack(spacing: 4) {
                if let c = color { Circle().fill(c).frame(width: 6, height: 6) }
                Text(value).font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            }
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
    }

    private func timingBar(_ label: String, _ ms: Double, total: Double) -> some View {
        let ratio = total > 0 ? min(ms / total, 1.0) : 0
        return VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 11)).foregroundStyle(theme.textSecondary)
                Spacer()
                Text(String(format: "%.2f ms", ms)).font(.system(size: 11, weight: .medium)).foregroundStyle(theme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.surfaceSecondary).frame(height: 6)
                    Capsule().fill(theme.accent).frame(width: geo.size.width * ratio, height: 6)
                }
            }.frame(height: 6)
        }
    }

    private func observationRow(name: String, payload: [String: Any]) -> some View {
        let summary = observationSummary(payload)
        return HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: "sensor.tag.radiowaves.forward").font(.system(size: 11)).foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.text)
                Text(summary).font(.system(size: 10)).foregroundStyle(theme.textTertiary).lineLimit(3)
            }
        }
        .padding(theme.spacingS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceSecondary)
        .cornerRadius(6)
    }

    private func observationSummary(_ payload: [String: Any]) -> String {
        if payload.isEmpty { return "空" }
        var parts: [String] = []
        for (k, v) in payload.sorted(by: { $0.key < $1.key }).prefix(6) {
            if let arr = v as? [Any] {
                parts.append("\(k): [\(arr.count)]")
            } else if let d = v as? [String: Any] {
                parts.append("\(k): {\(d.count)}")
            } else {
                parts.append("\(k): \(v)")
            }
        }
        return parts.joined(separator: "  ")
    }

    private func statusRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.system(size: 12)).foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium)).foregroundStyle(theme.text)
        }
    }
}
