// Importers/callers: ModuleDetailView (routing .submitTask), ClusterOverviewView (提交任务 button)
// Affected API: engine.submitTask(), dismiss environment
// Data schemas: TaskSubmitRequest fields (name, mode, model_name, priority, required_capability)
// User instruction: "做一遍检查，所有需要GUI的都要在fusion-studio落地"

import SwiftUI
import os.log

private let submitLog = Logger(subsystem: "com.fusion.studio", category: "SubmitTask")

struct SubmitTaskView: View {
    @EnvironmentObject var engine: MultiNodeEngine
    @Environment(\.studioTheme) var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var taskName = ""
    @State private var taskMode = "pipeline"
    @State private var modelName = ""
    @State private var priority = 5
    @State private var requiredCapability = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let modes = ["pipeline", "data_parallel", "inference"]
    private let priorities = Array(1...10)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(eyebrow: "Multi-Node", title: i18n.t(.mn_submit_title), subtitle: i18n.t(.mn_submit_subtitle))

                formSection
                actionSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
    }

    private var formSection: some View {
        ListGroup {
            StudioSectionHeader(title: i18n.t(.mn_submit_configTitle))

            StudioRow(label: i18n.t(.mn_submit_taskNameLabel), sublabel: i18n.t(.mn_submit_taskNameSub)) {
                TextField(i18n.t(.mn_submit_taskNamePh), text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .frame(maxWidth: 200)
            }

            StudioRow(label: i18n.t(.mn_submit_execModeLabel), sublabel: i18n.t(.mn_submit_execModeSub)) {
                Picker("", selection: $taskMode) {
                    ForEach(modes, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }

            StudioRow(label: i18n.t(.mn_submit_modelLabel), sublabel: i18n.t(.mn_submit_modelSub)) {
                TextField(i18n.t(.mn_submit_modelPh), text: $modelName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .frame(maxWidth: 200)
            }

            StudioRow(label: i18n.t(.mn_submit_priorityLabel), sublabel: i18n.t(.mn_submit_prioritySub)) {
                Picker("", selection: $priority) {
                    ForEach(priorities, id: \.self) { p in
                        Text("\(p)").tag(p)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 80)
            }

            StudioRow(label: i18n.t(.mn_submit_capabilityLabel), sublabel: i18n.t(.mn_submit_capabilitySub), isLast: true) {
                TextField(i18n.t(.mn_submit_capabilityPh), text: $requiredCapability)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .frame(maxWidth: 200)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            if let err = errorMessage {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.redDot)
                    Text(err)
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.errorText)
                }
                .padding(.horizontal, theme.spacingL)
            }

            if let msg = successMessage {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.greenDot)
                    Text(msg)
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.successText)
                }
                .padding(.horizontal, theme.spacingL)
            }

            HStack(spacing: theme.spacingM) {
                FusionButton(i18n.t(.mn_submit_submitBtn), icon: "paperplane.fill", style: .primary, size: .regular, isLoading: isSubmitting, isDisabled: !canSubmit) {
                    submitTask()
                }
                FusionButton(i18n.t(.cancel), style: .ghost, size: .regular, isLoading: false, isDisabled: false) {
                    dismiss()
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingS)
        }
    }

    private var canSubmit: Bool {
        !taskName.trimmingCharacters(in: .whitespaces).isEmpty
            && !modelName.trimmingCharacters(in: .whitespaces).isEmpty
            && !isSubmitting
    }

    private func submitTask() {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        submitLog.info("Submitting task: \(taskName), mode=\(taskMode), model=\(modelName)")

        Task {
            do {
                let result = try await engine.submitTask(
                    name: taskName.trimmingCharacters(in: .whitespaces),
                    mode: taskMode,
                    modelName: modelName.trimmingCharacters(in: .whitespaces),
                    priority: priority,
                    requiredCapability: requiredCapability.isEmpty ? nil : requiredCapability
                )
                submitLog.info("Task submitted successfully: \(result)")
                await MainActor.run {
                    isSubmitting = false
                    successMessage = String(format: i18n.t(.mn_submit_successFmt), result["task_id"] as? String ?? "unknown")
                }
            } catch {
                submitLog.error("Task submission failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
