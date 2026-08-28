import SwiftUI
import Combine
import os.log

// MARK: - SafetyTabView

struct SafetyTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCheckSheet = false
    @State private var checkContent = ""
    @State private var checkContext = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Safety & Compliance")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Check", icon: "checkmark.shield") { showCheckSheet = true }
            }
            .padding(theme.spacingM)

            if let result = bridge.moduleState.safetyCheckResult {
                StudioSectionHeader(title: "Last Check Result")
                ListGroup {
                    StudioRow(label: "Level", sublabel: result.level, isLast: false) {
                        FusionTag(result.level, color: levelColor(result.level))
                    }
                    StudioRow(label: "Approved", sublabel: nil, isLast: result.violations.isEmpty) {
                        FusionTag(result.approved ? "yes" : "no", color: result.approved ? .green : .red)
                    }
                    if !result.violations.isEmpty {
                        StudioRow(label: "Violations", sublabel: result.violations.joined(separator: ", "), isLast: true) {
                            FusionTag("\(result.violations.count)", color: .red)
                        }
                    }
                }
            }

            StudioSectionHeader(title: "Pending Actions")
            if bridge.moduleState.safetyPendingActions.isEmpty {
                Text("No pending safety actions")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.moduleState.safetyPendingActions.enumerated()), id: \.element.id) { idx, action in
                        StudioRow(label: action.category, sublabel: action.content, isLast: idx == bridge.moduleState.safetyPendingActions.count - 1) {
                            HStack(spacing: 6) {
                                FusionButton("Approve", icon: "checkmark", style: .secondary, size: .small) {
                                    Task { await approveAction(action.id) }
                                }
                                FusionButton("Reject", icon: "xmark", style: .destructive, size: .small) {
                                    Task { await rejectAction(action.id) }
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchPendingSafetyActions()
                } catch {
                    agentStudioLog.warning("fetchPendingSafetyActions failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showCheckSheet) {
            checkSheet
        }
    }

    private var checkSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Safety Check")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Content to check", text: $checkContent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            TextField("Context (optional)", text: $checkContext, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                FusionButton("Cancel") { showCheckSheet = false }
                Spacer()
                FusionButton("Check", icon: "shield", isDisabled: checkContent.isEmpty) {
                    Task { await runCheck() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 360)
    }

    private func runCheck() async {
        guard !checkContent.isEmpty else { return }
        do {
            let result = try await bridge.safetyCheck(content: checkContent, context: checkContext)
            toastManager.show(style: result.approved ? .success : .warning, title: result.level, message: result.approved ? "Approved" : "\(result.violations.count) violations")
            showCheckSheet = false
            checkContent = ""
            checkContext = ""
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func approveAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyApproveAction(actionId: actionId)
            toastManager.show(style: .success, title: "Approved", message: "Safety action approved")
            try await bridge.fetchPendingSafetyActions()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func rejectAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyRejectAction(actionId: actionId)
            toastManager.show(style: .success, title: "Rejected", message: "Safety action rejected")
            try await bridge.fetchPendingSafetyActions()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func levelColor(_ level: String) -> TagColor {
        switch level.uppercased() {
        case "L4", "L5": return .red
        case "L3": return .orange
        case "L2": return .blue
        default: return .green
        }
    }
}
