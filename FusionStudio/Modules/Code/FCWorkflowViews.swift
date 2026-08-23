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

    var localizedName: String {
        switch name {
        case "analyze_code": return I18nManager.shared.t(.fc_wf_step_analyze_code)
        case "gen_migration_plan": return I18nManager.shared.t(.fc_wf_step_gen_migration_plan)
        case "execute_migration": return I18nManager.shared.t(.fc_wf_step_execute_migration)
        case "verify_tests": return I18nManager.shared.t(.fc_wf_step_verify_tests)
        case "cleanup_docs": return I18nManager.shared.t(.fc_wf_step_cleanup_docs)
        case "dep_scan": return I18nManager.shared.t(.fc_wf_step_dep_scan)
        case "code_audit": return I18nManager.shared.t(.fc_wf_step_code_audit)
        case "perm_check": return I18nManager.shared.t(.fc_wf_step_perm_check)
        case "gen_report": return I18nManager.shared.t(.fc_wf_step_gen_report)
        case "api_analysis": return I18nManager.shared.t(.fc_wf_step_api_analysis)
        case "batch_generate": return I18nManager.shared.t(.fc_wf_step_batch_generate)
        case "test_verify": return I18nManager.shared.t(.fc_wf_step_test_verify)
        case "understand_code": return I18nManager.shared.t(.fc_wf_step_understand_code)
        case "plan_refactor": return I18nManager.shared.t(.fc_wf_step_plan_refactor)
        case "execute_refactor": return I18nManager.shared.t(.fc_wf_step_execute_refactor)
        case "verify": return I18nManager.shared.t(.fc_wf_step_verify)
        case "gen_cases": return I18nManager.shared.t(.fc_wf_step_gen_cases)
        case "run_tests": return I18nManager.shared.t(.fc_wf_step_run_tests)
        case "analyze_task": return I18nManager.shared.t(.fc_wf_step_analyze_task)
        case "make_plan": return I18nManager.shared.t(.fc_wf_step_make_plan)
        case "execute": return I18nManager.shared.t(.fc_wf_step_execute)
        default: return name
        }
    }

    var localizedDescription: String {
        switch name {
        case "analyze_code": return I18nManager.shared.t(.fc_wf_step_desc_analyze_code)
        case "gen_migration_plan": return I18nManager.shared.t(.fc_wf_step_desc_gen_migration_plan)
        case "execute_migration": return I18nManager.shared.t(.fc_wf_step_desc_execute_migration)
        case "verify_tests": return I18nManager.shared.t(.fc_wf_step_desc_verify_tests)
        case "cleanup_docs": return I18nManager.shared.t(.fc_wf_step_desc_cleanup_docs)
        case "dep_scan": return I18nManager.shared.t(.fc_wf_step_desc_dep_scan)
        case "code_audit": return I18nManager.shared.t(.fc_wf_step_desc_code_audit)
        case "perm_check": return I18nManager.shared.t(.fc_wf_step_desc_perm_check)
        case "gen_report": return I18nManager.shared.t(.fc_wf_step_desc_gen_report)
        case "api_analysis": return I18nManager.shared.t(.fc_wf_step_desc_api_analysis)
        case "batch_generate": return I18nManager.shared.t(.fc_wf_step_desc_batch_generate)
        case "test_verify": return I18nManager.shared.t(.fc_wf_step_desc_test_verify)
        case "understand_code": return I18nManager.shared.t(.fc_wf_step_desc_understand_code)
        case "plan_refactor": return I18nManager.shared.t(.fc_wf_step_desc_plan_refactor)
        case "execute_refactor": return I18nManager.shared.t(.fc_wf_step_desc_execute_refactor)
        case "verify": return I18nManager.shared.t(.fc_wf_step_desc_verify)
        case "gen_cases": return I18nManager.shared.t(.fc_wf_step_desc_gen_cases)
        case "run_tests": return I18nManager.shared.t(.fc_wf_step_desc_run_tests)
        case "analyze_task": return I18nManager.shared.t(.fc_wf_step_desc_analyze_task)
        case "make_plan": return I18nManager.shared.t(.fc_wf_step_desc_make_plan)
        case "execute": return I18nManager.shared.t(.fc_wf_step_desc_execute)
        default: return description
        }
    }
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
                FCWorkflowStep(name: "analyze_code", description: "analyze_code", status: .pending, dependencies: []),
                FCWorkflowStep(name: "gen_migration_plan", description: "gen_migration_plan", status: .pending, dependencies: ["analyze_code"]),
                FCWorkflowStep(name: "execute_migration", description: "execute_migration", status: .pending, dependencies: ["gen_migration_plan"]),
                FCWorkflowStep(name: "verify_tests", description: "verify_tests", status: .pending, dependencies: ["execute_migration"]),
                FCWorkflowStep(name: "cleanup_docs", description: "cleanup_docs", status: .pending, dependencies: ["verify_tests"]),
            ]
        case "security_scan":
            return [
                FCWorkflowStep(name: "dep_scan", description: "dep_scan", status: .pending, dependencies: []),
                FCWorkflowStep(name: "code_audit", description: "code_audit", status: .pending, dependencies: []),
                FCWorkflowStep(name: "perm_check", description: "perm_check", status: .pending, dependencies: ["dep_scan"]),
                FCWorkflowStep(name: "gen_report", description: "gen_report", status: .pending, dependencies: ["code_audit", "perm_check"]),
            ]
        case "batch_api":
            return [
                FCWorkflowStep(name: "api_analysis", description: "api_analysis", status: .pending, dependencies: []),
                FCWorkflowStep(name: "batch_generate", description: "batch_generate", status: .pending, dependencies: ["api_analysis"]),
                FCWorkflowStep(name: "test_verify", description: "test_verify", status: .pending, dependencies: ["batch_generate"]),
            ]
        case "refactor":
            return [
                FCWorkflowStep(name: "understand_code", description: "understand_code", status: .pending, dependencies: []),
                FCWorkflowStep(name: "plan_refactor", description: "plan_refactor", status: .pending, dependencies: ["understand_code"]),
                FCWorkflowStep(name: "execute_refactor", description: "execute_refactor", status: .pending, dependencies: ["plan_refactor"]),
                FCWorkflowStep(name: "verify", description: "verify", status: .pending, dependencies: ["execute_refactor"]),
            ]
        case "test_gen":
            return [
                FCWorkflowStep(name: "analyze_code", description: "analyze_code", status: .pending, dependencies: []),
                FCWorkflowStep(name: "gen_cases", description: "gen_cases", status: .pending, dependencies: ["analyze_code"]),
                FCWorkflowStep(name: "run_tests", description: "run_tests", status: .pending, dependencies: ["gen_cases"]),
            ]
        default:
            return [
                FCWorkflowStep(name: "analyze_task", description: "analyze_task", status: .pending, dependencies: []),
                FCWorkflowStep(name: "make_plan", description: "make_plan", status: .pending, dependencies: ["analyze_task"]),
                FCWorkflowStep(name: "execute", description: "execute", status: .pending, dependencies: ["make_plan"]),
                FCWorkflowStep(name: "verify", description: "verify", status: .pending, dependencies: ["execute"]),
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
            Text(step.localizedName)
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
