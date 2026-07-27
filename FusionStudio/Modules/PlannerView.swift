import SwiftUI
import os.log

struct PlannerView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var selectedStatus: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showCreateSheet: Bool = false
    @State private var selectedPlan: PlanModel?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "PlannerView")

    var body: some View {
        VStack(spacing: 0) {
            plannerToolbar
            Divider()
            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                HSplitView {
                    planListView
                        .frame(minWidth: 280)
                    planDetailView
                        .frame(minWidth: 400)
                }
            }
        }
        .onAppear {
            Task { await loadPlans() }
        }
    }

    private var plannerToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { showCreateSheet = true }) {
                Label("New Plan", systemImage: "plus")
            }
            Button(action: { Task { await loadPlans() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
            Picker("Status", selection: $selectedStatus) {
                Text("All").tag("")
                Text("Draft").tag("draft")
                Text("Approved").tag("approved")
                Text("Executing").tag("executing")
                Text("Completed").tag("completed")
                Text("Cancelled").tag("cancelled")
            }
            .frame(width: 140)
        }
        .padding(8)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(msg)
                .foregroundColor(.secondary)
            Button("Retry") { Task { await loadPlans() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var planListView: some View {
        List(bridge.plans, selection: $selectedPlan) { plan in
            PlanRowView(plan: plan, isSelected: selectedPlan?.id == plan.id)
                .tag(plan)
                .onTapGesture {
                    selectedPlan = plan
                    bridge.currentPlan = plan
                }
        }
        .listStyle(.sidebar)
    }

    private var planDetailView: some View {
        Group {
            if let plan = selectedPlan {
                PlanDetailView(plan: plan)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a plan to view details")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadPlans() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await bridge.fetchPlans(status: selectedStatus)
        } catch {
            errorMessage = error.localizedDescription
            logger.error("loadPlans: \(error)")
        }
        isLoading = false
    }
}

struct PlanRowView: View {
    let plan: PlanModel
    let isSelected: Bool

    var statusColor: Color {
        switch plan.status {
        case "draft": return .gray
        case "approved": return .blue
        case "executing": return .orange
        case "completed": return .green
        case "cancelled": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.task)
                    .lineLimit(1)
                    .font(.headline)
                Text("\(plan.steps.count) steps · \(plan.status)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

struct PlanDetailView: View {
    @EnvironmentObject var bridge: AgentBridge
    let plan: PlanModel
    @State private var isActing: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "PlanDetailView")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                planHeader
                Divider()
                stepList
                Divider()
                actionBar
            }
            .padding()
        }
    }

    private var planHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.task)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                statusBadge(plan.status)
            }
            if !plan.context.isEmpty {
                Text("Context: \(plan.context)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text("Created: \(plan.created_at)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.uppercased())
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status).opacity(0.2))
            .foregroundColor(statusColor(status))
            .cornerRadius(4)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "draft": return .gray
        case "approved": return .blue
        case "executing": return .orange
        case "completed": return .green
        case "cancelled": return .red
        default: return .secondary
        }
    }

    private var stepList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps")
                .font(.headline)
            ForEach(plan.steps) { step in
                StepRowView(step: step, planId: plan.id, planStatus: plan.status)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if plan.status == "draft" {
                Button("Approve") {
                    Task { await approvePlan() }
                }
                .disabled(isActing)
                Button("Reject") {
                    Task { await rejectPlan() }
                }
                .disabled(isActing)
            }
            if plan.status == "approved" {
                Button("Execute All") {
                    Task { await executePlan() }
                }
                .disabled(isActing)
            }
            if plan.status == "executing" || plan.status == "approved" || plan.status == "draft" {
                Button("Cancel") {
                    Task { await cancelPlan() }
                }
                .disabled(isActing)
                .foregroundColor(.red)
            }
            Spacer()
            if isActing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
    }

    private func approvePlan() async {
        isActing = true
        do {
            _ = try await bridge.plannerApprovePlan(planId: plan.id)
            _ = try await bridge.plannerGetPlan(planId: plan.id)
            _ = try await bridge.fetchPlans()
        } catch {
            logger.error("approvePlan: \(error)")
        }
        isActing = false
    }

    private func rejectPlan() async {
        isActing = true
        do {
            _ = try await bridge.plannerRejectPlan(planId: plan.id)
            _ = try await bridge.plannerGetPlan(planId: plan.id)
            _ = try await bridge.fetchPlans()
        } catch {
            logger.error("rejectPlan: \(error)")
        }
        isActing = false
    }

    private func executePlan() async {
        isActing = true
        do {
            _ = try await bridge.plannerExecutePlan(planId: plan.id)
            _ = try await bridge.plannerGetPlan(planId: plan.id)
            _ = try await bridge.fetchPlans()
        } catch {
            logger.error("executePlan: \(error)")
        }
        isActing = false
    }

    private func cancelPlan() async {
        isActing = true
        do {
            _ = try await bridge.plannerCancelPlan(planId: plan.id)
            _ = try await bridge.plannerGetPlan(planId: plan.id)
            _ = try await bridge.fetchPlans()
        } catch {
            logger.error("cancelPlan: \(error)")
        }
        isActing = false
    }
}

struct StepRowView: View {
    @EnvironmentObject var bridge: AgentBridge
    let step: PlanStepModel
    let planId: String
    let planStatus: String
    @State private var isExecuting: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "StepRowView")

    var stepColor: Color {
        switch step.status {
        case "pending": return .gray
        case "in_progress": return .orange
        case "completed": return .green
        case "failed": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.status == "completed" ? "checkmark.circle.fill" : step.status == "failed" ? "xmark.circle.fill" : "circle")
                .foregroundColor(stepColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.description)
                    .font(.body)
                if let result = step.result, !result.isEmpty {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            if planStatus == "approved" || planStatus == "executing" {
                if step.status == "pending" {
                    Button("Run") {
                        Task { await executeStep() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isExecuting)
                }
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                    Button(action: {
                        bridge.cancelExecution()
                        isExecuting = false
                    }) {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func executeStep() async {
        isExecuting = true
        do {
            _ = try await bridge.plannerExecuteStep(planId: planId, stepId: step.id)
            _ = try await bridge.plannerGetPlan(planId: planId)
            _ = try await bridge.fetchPlans()
        } catch {
            logger.error("executeStep: \(error)")
        }
        isExecuting = false
    }
}

struct CreatePlanSheet: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.dismiss) private var dismiss
    @State private var task: String = ""
    @State private var context: String = ""
    @State private var isCreating: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "CreatePlanSheet")

    var body: some View {
        VStack(spacing: 16) {
            Text("Create Plan")
                .font(.headline)
            TextField("Task description", text: $task)
                .textFieldStyle(.roundedBorder)
            TextField("Context (optional)", text: $context)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create") {
                    Task { await createPlan() }
                }
                .disabled(task.isEmpty || isCreating)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func createPlan() async {
        isCreating = true
        do {
            _ = try await bridge.plannerCreatePlan(task: task, context: context)
            dismiss()
        } catch {
            logger.error("createPlan: \(error)")
        }
        isCreating = false
    }
}
