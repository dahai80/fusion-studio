import SwiftUI
import Combine
import os.log

// MARK: - PlannerTabView

struct PlannerTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newTask = ""
    @State private var newContext = ""
    @State private var expandedPlanId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Planner")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("New Plan", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.moduleState.plans.isEmpty {
                Spacer()
                Text("No plans yet")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.plans.enumerated()), id: \.element.id) { idx, plan in
                            planRow(plan, isLast: idx == bridge.moduleState.plans.count - 1)
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchPlans()
                } catch {
                    agentStudioLog.warning("fetchPlans failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createSheet
        }
    }

    @ViewBuilder
    private func planRow(_ plan: PlanModel, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: theme.spacingM) {
                Button {
                    withAnimation(theme.springSnappy) {
                        expandedPlanId = expandedPlanId == plan.id ? nil : plan.id
                    }
                } label: {
                    Image(systemName: expandedPlanId == plan.id ? "chevron.down" : "chevron.right")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.task)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                    Text("\(plan.steps.count) steps · \(plan.created_at)")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                FusionTag(plan.status, color: planStatusColor(plan.status))
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS + 2)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(theme.rowSep).frame(height: 0.5).padding(.horizontal, theme.spacingL)
                }
            }

            if expandedPlanId == plan.id {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    if !plan.context.isEmpty {
                        Text(plan.context)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    ForEach(plan.steps) { step in
                        HStack(alignment: .top, spacing: theme.spacingS) {
                            Image(systemName: stepIcon(step.status))
                                .foregroundStyle(stepColor(step.status))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.description)
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.text)
                                if let result = step.result, !result.isEmpty {
                                    Text(result)
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                            Spacer()
                            if plan.status == "approved" || plan.status == "executing" {
                                FusionButton("Run", icon: "play", style: .secondary, size: .small) {
                                    Task { await executeStep(plan.id, step.id) }
                                }
                            }
                        }
                    }
                    HStack(spacing: theme.spacingS) {
                        if plan.status == "pending" || plan.status == "draft" {
                            FusionButton("Approve", icon: "checkmark", style: .secondary, size: .small) {
                                Task { await approvePlan(plan.id) }
                            }
                            FusionButton("Reject", icon: "xmark", style: .destructive, size: .small) {
                                Task { await rejectPlan(plan.id) }
                            }
                        }
                        if plan.status == "approved" {
                            FusionButton("Execute All", icon: "play.fill", size: .small) {
                                Task { await executePlan(plan.id) }
                            }
                        }
                        if plan.status != "completed" && plan.status != "cancelled" {
                            FusionButton("Cancel", icon: "stop", style: .ghost, size: .small) {
                                Task { await cancelPlan(plan.id) }
                            }
                        }
                    }
                    .padding(.top, theme.spacingXS)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.bottom, theme.spacingM)
                .background(theme.surfaceSecondary)
            }
        }
    }

    private var createSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Create Plan")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Task description", text: $newTask, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            TextField("Context (optional)", text: $newContext, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus", isDisabled: newTask.isEmpty) {
                    Task { await createPlan() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 360)
    }

    private func createPlan() async {
        guard !newTask.isEmpty else { return }
        do {
            _ = try await bridge.plannerCreatePlan(task: newTask, context: newContext)
            toastManager.show(style: .success, title: "Plan Created", message: newTask)
            showCreateSheet = false
            newTask = ""
            newContext = ""
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func approvePlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerApprovePlan(planId: planId)
            toastManager.show(style: .success, title: "Approved", message: "Plan approved")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func rejectPlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerRejectPlan(planId: planId)
            toastManager.show(style: .success, title: "Rejected", message: "Plan rejected")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func executeStep(_ planId: String, _ stepId: String) async {
        do {
            _ = try await bridge.plannerExecuteStep(planId: planId, stepId: stepId)
            toastManager.show(style: .success, title: "Step Done", message: "Step executed")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func executePlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerExecutePlan(planId: planId)
            toastManager.show(style: .success, title: "Executing", message: "Plan execution started")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func cancelPlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerCancelPlan(planId: planId)
            toastManager.show(style: .success, title: "Cancelled", message: "Plan cancelled")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func planStatusColor(_ status: String) -> TagColor {
        switch status.lowercased() {
        case "completed": return .green
        case "approved", "executing": return .blue
        case "cancelled", "rejected", "failed": return .red
        case "pending", "draft": return .orange
        default: return .gray
        }
    }

    private func stepIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "completed", "done": return "checkmark.circle.fill"
        case "running", "executing": return "arrow.triangle.2.circlepath"
        case "failed", "error": return "xmark.circle.fill"
        case "skipped": return "minus.circle"
        default: return "circle"
        }
    }

    private func stepColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "done": return theme.successText
        case "running", "executing": return theme.infoText
        case "failed", "error": return theme.errorText
        default: return theme.textTertiary
        }
    }
}
