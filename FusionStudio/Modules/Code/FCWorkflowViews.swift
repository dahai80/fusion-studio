import SwiftUI
import Foundation
import os.log

private let workflowLog = Logger(subsystem: "com.fusion.studio", category: "FCWorkflow")

enum FCWorkflowStepStatus: String, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case skipped = "skipped"

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .skipped: return "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .orange
        }
    }
}

struct FCWorkflowStep: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var status: FCWorkflowStepStatus
    var dependencies: [String]
    var output: String = ""
}

struct FCWorkflowPlan: Identifiable {
    let id = UUID()
    var name: String
    var goal: String
    var template: String
    var steps: [FCWorkflowStep]
    var maxParallel: Int
    var createdAt: Date

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        let done = steps.filter { $0.status == .completed }.count
        return Double(done) / Double(steps.count)
    }

    var statusText: String {
        let done = steps.filter { $0.status == .completed }.count
        let failed = steps.filter { $0.status == .failed }.count
        let running = steps.filter { $0.status == .running }.count
        if failed > 0 { return String(format: I18nManager.shared.t(.fc_wf_status_failed), failed) }
        if running > 0 { return String(format: I18nManager.shared.t(.fc_wf_status_running), done, steps.count) }
        if done == steps.count { return I18nManager.shared.t(.fc_wf_status_completed) }
        return String(format: I18nManager.shared.t(.fc_wf_status_pending), done, steps.count)
    }
}

class FCWorkflowStore: ObservableObject {
    static let shared = FCWorkflowStore()

    @Published var plans: [FCWorkflowPlan] = []
    @Published var activePlanId: UUID?

    var templates: [(name: String, icon: String, desc: String)] {
        [
            ("generic", "square.grid.3x3", I18nManager.shared.t(.fc_wf_template_generic)),
            ("legacy_migration", "arrow.right.circle", I18nManager.shared.t(.fc_wf_template_legacy)),
            ("security_scan", "shield.checkered", I18nManager.shared.t(.fc_wf_template_security)),
            ("batch_api", "server.rack", I18nManager.shared.t(.fc_wf_template_batch)),
            ("refactor", "hammer", I18nManager.shared.t(.fc_wf_template_refactor)),
            ("test_gen", "checkmark.shield", I18nManager.shared.t(.fc_wf_template_test)),
        ]
    }

    func createPlan(goal: String, template: String = "generic") -> FCWorkflowPlan {
        let steps = decomposeSteps(goal: goal, template: template)
        let plan = FCWorkflowPlan(
            name: goal,
            goal: goal,
            template: template,
            steps: steps,
            maxParallel: 3,
            createdAt: Date()
        )
        plans.insert(plan, at: 0)
        workflowLog.info("workflow plan created: \(goal), \(steps.count) steps")
        return plan
    }

    func startStep(planId: UUID, stepId: UUID) {
        guard let pIdx = self.plans.firstIndex(where: { $0.id == planId }),
              let sIdx = self.plans[pIdx].steps.firstIndex(where: { $0.id == stepId }) else { return }
        self.plans[pIdx].steps[sIdx].status = .running
        self.activePlanId = planId
        let stepName = self.plans[pIdx].steps[sIdx].name
        workflowLog.info("step started: \(stepName)")
    }

    func completeStep(planId: UUID, stepId: UUID, output: String = "") {
        guard let pIdx = self.plans.firstIndex(where: { $0.id == planId }),
              let sIdx = self.plans[pIdx].steps.firstIndex(where: { $0.id == stepId }) else { return }
        self.plans[pIdx].steps[sIdx].status = .completed
        self.plans[pIdx].steps[sIdx].output = output
        let stepName = self.plans[pIdx].steps[sIdx].name
        workflowLog.info("step completed: \(stepName)")
    }

    func failStep(planId: UUID, stepId: UUID, error: String = "") {
        guard let pIdx = self.plans.firstIndex(where: { $0.id == planId }),
              let sIdx = self.plans[pIdx].steps.firstIndex(where: { $0.id == stepId }) else { return }
        self.plans[pIdx].steps[sIdx].status = .failed
        self.plans[pIdx].steps[sIdx].output = error
        let stepName = self.plans[pIdx].steps[sIdx].name
        workflowLog.error("step failed: \(stepName) — \(error)")
    }

    func deletePlan(id: UUID) {
        plans.removeAll { $0.id == id }
        if activePlanId == id { activePlanId = nil }
    }

    private func decomposeSteps(goal: String, template: String) -> [FCWorkflowStep] {
        switch template {
        case "legacy_migration":
            return [
                FCWorkflowStep(name: "分析代码", description: "扫描遗留代码结构", status: .pending, dependencies: []),
                FCWorkflowStep(name: "生成迁移方案", description: "制定迁移策略和步骤", status: .pending, dependencies: ["分析代码"]),
                FCWorkflowStep(name: "执行迁移", description: "按方案逐步迁移代码", status: .pending, dependencies: ["生成迁移方案"]),
                FCWorkflowStep(name: "验证测试", description: "运行测试验证迁移结果", status: .pending, dependencies: ["执行迁移"]),
                FCWorkflowStep(name: "清理文档", description: "更新文档和配置", status: .pending, dependencies: ["验证测试"]),
            ]
        case "security_scan":
            return [
                FCWorkflowStep(name: "依赖扫描", description: "检查第三方依赖漏洞", status: .pending, dependencies: []),
                FCWorkflowStep(name: "代码审计", description: "静态分析安全风险", status: .pending, dependencies: []),
                FCWorkflowStep(name: "权限检查", description: "验证文件和API权限", status: .pending, dependencies: ["依赖扫描"]),
                FCWorkflowStep(name: "生成报告", description: "汇总安全问题并生成报告", status: .pending, dependencies: ["代码审计", "权限检查"]),
            ]
        case "batch_api":
            return [
                FCWorkflowStep(name: "接口分析", description: "分析API接口规范", status: .pending, dependencies: []),
                FCWorkflowStep(name: "批量生成", description: "生成API调用代码", status: .pending, dependencies: ["接口分析"]),
                FCWorkflowStep(name: "测试验证", description: "批量测试API响应", status: .pending, dependencies: ["批量生成"]),
            ]
        case "refactor":
            return [
                FCWorkflowStep(name: "理解代码", description: "分析代码结构和模式", status: .pending, dependencies: []),
                FCWorkflowStep(name: "规划重构", description: "制定重构方案", status: .pending, dependencies: ["理解代码"]),
                FCWorkflowStep(name: "执行重构", description: "逐步重构代码", status: .pending, dependencies: ["规划重构"]),
                FCWorkflowStep(name: "验证", description: "运行测试确保功能不变", status: .pending, dependencies: ["执行重构"]),
            ]
        case "test_gen":
            return [
                FCWorkflowStep(name: "分析代码", description: "理解代码逻辑和边界", status: .pending, dependencies: []),
                FCWorkflowStep(name: "生成用例", description: "生成测试用例代码", status: .pending, dependencies: ["分析代码"]),
                FCWorkflowStep(name: "运行测试", description: "执行测试并报告结果", status: .pending, dependencies: ["生成用例"]),
            ]
        default:
            return [
                FCWorkflowStep(name: "分析任务", description: "理解目标和约束", status: .pending, dependencies: []),
                FCWorkflowStep(name: "制定方案", description: "拆分子任务和依赖", status: .pending, dependencies: ["分析任务"]),
                FCWorkflowStep(name: "执行", description: "逐步实现子任务", status: .pending, dependencies: ["制定方案"]),
                FCWorkflowStep(name: "验证", description: "检查结果是否达标", status: .pending, dependencies: ["执行"]),
            ]
        }
    }
}

struct FCWorkflowPanel: View {
    @Environment(\.studioTheme) private var theme
    @ObservedObject var store = FCWorkflowStore.shared
    @State private var showCreateSheet = false
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: theme.spacingS) {
            HStack {
                Text("Workflow")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { showCreateSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if store.plans.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingS) {
                        ForEach(store.plans) { plan in
                            planCard(plan)
                        }
                    }
                }
            }
        }
        .padding(theme.spacingM)
        .frame(minHeight: 200, maxHeight: 450)
        .sheet(isPresented: $showCreateSheet) {
            FCWorkflowCreateSheet(store: store, isPresented: $showCreateSheet)
        }
    }

    private var emptyView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.fc_wf_empty_desc))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            Button(i18n.t(.fc_wf_new)) { showCreateSheet = true }
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func planCard(_ plan: FCWorkflowPlan) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(plan.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                Text(plan.statusText)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }

            ProgressView(value: plan.progress)
                .controlSize(.small)

            let columns = [GridItem(.adaptive(minimum: 120), spacing: 4)]
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(plan.steps) { step in
                    stepChip(step)
                }
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.groupBg))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(theme.groupBorder, lineWidth: 1)
        )
        .contextMenu {
            Button(i18n.t(.fc_delete), role: .destructive) { store.deletePlan(id: plan.id) }
        }
    }

    private func stepChip(_ step: FCWorkflowStep) -> some View {
        HStack(spacing: 3) {
            Image(systemName: step.status.icon)
                .font(.system(size: 8))
                .foregroundColor(step.status.color)
            Text(step.name)
                .font(.system(size: 9))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 3).fill(step.status.color.opacity(0.1)))
    }
}

struct FCWorkflowCreateSheet: View {
    @ObservedObject var store: FCWorkflowStore
    @Binding var isPresented: Bool
    @State private var goal = ""
    @State private var template = "generic"
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Text(i18n.t(.fc_wf_new))
                .font(.system(size: 14, weight: .semibold))

            TextField(i18n.t(.fc_wf_goal_ph), text: $goal)
                .textFieldStyle(.roundedBorder)

            Text(i18n.t(.fc_wf_select_template))
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(store.templates, id: \.name) { tmpl in
                    Button(action: { template = tmpl.name }) {
                        VStack(spacing: 4) {
                            Image(systemName: tmpl.icon)
                                .font(.system(size: 16))
                            Text(tmpl.name)
                                .font(.system(size: 10))
                            Text(tmpl.desc)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(template == tmpl.name ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(template == tmpl.name ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                Button(i18n.t(.fc_cancel)) { isPresented = false }
                Button(i18n.t(.fc_create)) {
                    _ = store.createPlan(goal: goal, template: template)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(goal.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 380)
    }
}
