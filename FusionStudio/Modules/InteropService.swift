import SwiftUI
import Foundation
import Combine

/// 模块间联动事件
enum InteropEvent {
    /// 设计 → 代码：导出设计稿为代码
    case designExportedCode(designId: String, code: String, language: String)
    /// 代码 → 仿真：部署控制面板
    case codeDeployedToSimulation(codeId: String, code: String, platform: String)
    /// 仿真 → 设计：反馈优化建议
    case simulationFeedbackToDesign(sceneId: String, feedback: String, suggestions: [String])
    /// 设计 → 仿真：生成仿真场景
    case designToSimulation(designId: String, sceneConfig: [String: Any])
}

/// 联动数据流
struct InteropPayload: Identifiable {
    let id = UUID()
    let sourceModule: String
    let targetModule: String
    let data: [String: Any]
    let timestamp: Date
}

/// 模块间联动服务
class ModuleInteropService: ObservableObject {
    static let shared = ModuleInteropService()

    @Published var recentTransfers: [InteropPayload] = []
    @Published var lastEvent: InteropEvent?

    private let maxHistory = 20

    // MARK: - Design → Code

    /// 从设计导出代码到 Code 模块
    func exportDesignToCode(designId: String, code: String, language: String) {
        let payload = InteropPayload(
            sourceModule: "design",
            targetModule: "code",
            data: [
                "designId": designId,
                "code": code,
                "language": language,
                "action": "export_code"
            ],
            timestamp: Date()
        )
        recordTransfer(payload)
        lastEvent = .designExportedCode(designId: designId, code: code, language: language)
        NotificationCenter.default.post(
            name: .interopDesignToCode,
            object: nil,
            userInfo: payload.data
        )
    }

    // MARK: - Code → Simulation

    /// 从代码部署到仿真模块
    func deployCodeToSimulation(codeId: String, code: String, platform: String) {
        let payload = InteropPayload(
            sourceModule: "code",
            targetModule: "simulation",
            data: [
                "codeId": codeId,
                "code": code,
                "platform": platform,
                "action": "deploy_panel"
            ],
            timestamp: Date()
        )
        recordTransfer(payload)
        lastEvent = .codeDeployedToSimulation(codeId: codeId, code: code, platform: platform)
        NotificationCenter.default.post(
            name: .interopCodeToSimulation,
            object: nil,
            userInfo: payload.data
        )
    }

    // MARK: - Simulation → Design

    /// 从仿真反馈到设计模块
    func feedbackToDesign(sceneId: String, feedback: String, suggestions: [String]) {
        let payload = InteropPayload(
            sourceModule: "simulation",
            targetModule: "design",
            data: [
                "sceneId": sceneId,
                "feedback": feedback,
                "suggestions": suggestions,
                "action": "feedback_optimize"
            ],
            timestamp: Date()
        )
        recordTransfer(payload)
        lastEvent = .simulationFeedbackToDesign(sceneId: sceneId, feedback: feedback, suggestions: suggestions)
        NotificationCenter.default.post(
            name: .interopSimulationToDesign,
            object: nil,
            userInfo: payload.data
        )
    }

    // MARK: - Design → Simulation

    /// 从设计生成仿真场景
    func designToSimulation(designId: String, sceneConfig: [String: Any]) {
        let payload = InteropPayload(
            sourceModule: "design",
            targetModule: "simulation",
            data: [
                "designId": designId,
                "sceneConfig": sceneConfig,
                "action": "create_scene"
            ],
            timestamp: Date()
        )
        recordTransfer(payload)
        lastEvent = .designToSimulation(designId: designId, sceneConfig: sceneConfig)
        NotificationCenter.default.post(
            name: .interopDesignToSimulation,
            object: nil,
            userInfo: payload.data
        )
    }

    // MARK: - History

    private func recordTransfer(_ payload: InteropPayload) {
        DispatchQueue.main.async {
            self.recentTransfers.append(payload)
            if self.recentTransfers.count > self.maxHistory {
                self.recentTransfers.removeFirst()
            }
        }
    }

    func clearHistory() {
        recentTransfers.removeAll()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let interopDesignToCode = Notification.Name("interop.design-to-code")
    static let interopCodeToSimulation = Notification.Name("interop.code-to-simulation")
    static let interopSimulationToDesign = Notification.Name("interop.simulation-to-design")
    static let interopDesignToSimulation = Notification.Name("interop.design-to-simulation")
}

// MARK: - 联动面板视图

struct InteropPanelView: View {
    @StateObject private var interop = ModuleInteropService.shared
    @State private var selectedTab: InteropTab = .flow

    enum InteropTab: String, CaseIterable {
        case flow    = "联动流程"
        case history = "数据传输"
        case config  = "联动配置"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(InteropTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            switch selectedTab {
            case .flow:
                InteropFlowView()
            case .history:
                InteropHistoryView()
            case .config:
                InteropConfigView()
            }
        }
    }
}

// MARK: - 联动流程可视化

struct InteropFlowView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 三模块联动图
            HStack(spacing: 0) {
                ModuleNode(name: "🎨 Design", color: .blue, action: "UI 设计")
                ArrowLabel(label: "导出代码")
                ModuleNode(name: "💻 Code", color: .green, action: "代码生成")
                ArrowLabel(label: "部署面板")
                ModuleNode(name: "🤖 Simulation", color: .orange, action: "仿真运行")
            }
            .padding(20)

            Divider()

            // 联动能力列表
            GroupBox("联动能力") {
                VStack(alignment: .leading, spacing: 12) {
                    InteropCapabilityRow(icon: "arrow.right.doc.on.clipboard", from: "Design", to: "Code", description: "设计稿一键导出 SwiftUI/React 代码")
                    InteropCapabilityRow(icon: "arrow.right.square", from: "Code", to: "Simulation", description: "代码部署为仿真控制面板")
                    InteropCapabilityRow(icon: "arrow.left.arrow.right", from: "Simulation", to: "Design", description: "仿真反馈驱动设计优化")
                    InteropCapabilityRow(icon: "arrow.right.circle", from: "Design", to: "Simulation", description: "设计稿生成仿真场景")
                }
                .padding()
            }
            .padding(.horizontal)
        }
    }
}

struct ModuleNode: View {
    let name: String
    let color: Color
    let action: String

    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(8)
            Text(action)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ArrowLabel: View {
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "arrow.right")
                .foregroundColor(.accentColor)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 60)
    }
}

struct InteropCapabilityRow: View {
    let icon: String
    let from: String
    let to: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text("\(from) → \(to)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 联动历史

struct InteropHistoryView: View {
    @StateObject private var interop = ModuleInteropService.shared

    var body: some View {
        if interop.recentTransfers.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
                Text("暂无数据传输")
                    .foregroundColor(.secondary)
                Text("在 Design/Code/Simulation 模块间联动时，数据传输记录将显示在这里")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            }
        } else {
            List(interop.recentTransfers.reversed()) { payload in
                HStack(spacing: 10) {
                    Image(systemName: moduleIcon(payload.sourceModule))
                        .foregroundColor(.blue)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: moduleIcon(payload.targetModule))
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(payload.sourceModule) → \(payload.targetModule)")
                            .font(.subheadline)
                        if let action = payload.data["action"] as? String {
                            Text(action)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Text(payload.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func moduleIcon(_ name: String) -> String {
        switch name {
        case "design":     return "pencil.and.outline"
        case "code":       return "chevron.left.forwardslash.chevron.right"
        case "simulation": return "gearshape.2"
        default:           return "square.grid.2x2"
        }
    }
}

// MARK: - 联动配置

struct InteropConfigView: View {
    @AppStorage("interop.autoExport") private var autoExport = true
    @AppStorage("interop.autoDeploy") private var autoDeploy = false
    @AppStorage("interop.autoFeedback") private var autoFeedback = true
    @AppStorage("interop.maxHistory") private var maxHistory = 50

    var body: some View {
        Form {
            Section("自动联动") {
                Toggle("设计完成后自动导出代码", isOn: $autoExport)
                Toggle("代码完成后自动部署仿真", isOn: $autoDeploy)
                Toggle("仿真完成后自动反馈设计", isOn: $autoFeedback)
            }

            Section("数据管理") {
                Stepper("最大历史记录: \(maxHistory)", value: $maxHistory, in: 10...200, step: 10)
            }

            Section("说明") {
                Text("联动功能使 Design、Code、Simulation 三个模块之间可以自动流转数据，实现设计→代码→仿真的完整闭环。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}