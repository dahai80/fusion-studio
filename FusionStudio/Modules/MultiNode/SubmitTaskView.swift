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
                ScreenHeader(eyebrow: "Multi-Node", title: "提交任务", subtitle: "向集群提交新的推理或计算任务")

                formSection
                actionSection
            }
            .padding(.bottom, theme.spacing2XL)
        }
        .background(theme.contentBg)
    }

    private var formSection: some View {
        ListGroup {
            StudioSectionHeader(title: "任务配置")

            StudioRow(label: "任务名称", sublabel: "用于标识任务的描述性名称") {
                TextField("例: llama-inference-batch", text: $taskName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .frame(maxWidth: 200)
            }

            StudioRow(label: "执行模式", sublabel: "pipeline=流水线, data_parallel=数据并行, inference=单节点推理") {
                Picker("", selection: $taskMode) {
                    ForEach(modes, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }

            StudioRow(label: "模型名称", sublabel: "目标推理模型") {
                TextField("例: mlx-community/Llama-3.2-1B", text: $modelName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.smallTextSize, design: .monospaced))
                    .frame(maxWidth: 200)
            }

            StudioRow(label: "优先级", sublabel: "1=最低, 10=最高") {
                Picker("", selection: $priority) {
                    ForEach(priorities, id: \.self) { p in
                        Text("\(p)").tag(p)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 80)
            }

            StudioRow(label: "所需能力", sublabel: "可选: 如 gpu, high_memory 等", isLast: true) {
                TextField("可选", text: $requiredCapability)
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
                FusionButton("提交", icon: "paperplane.fill", style: .primary, size: .regular, isLoading: isSubmitting, isDisabled: !canSubmit) {
                    submitTask()
                }
                FusionButton("取消", style: .ghost, size: .regular, isLoading: false, isDisabled: false) {
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
                    successMessage = "任务已提交 (ID: \(result["task_id"] as? String ?? "unknown"))"
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
