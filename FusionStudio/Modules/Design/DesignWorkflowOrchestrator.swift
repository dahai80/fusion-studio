// Callers: DesignView (toolbar buttons), CodeDesignPreviewPanel (sync bar), AppState (module switch notification).
// Affected API: DesignWorkflowOrchestrator (new @MainActor ObservableObject singleton), WorkflowRecipe enum, WorkflowStep enum, WorkflowRecipePicker, Notification.Name.switchToCodeModule.
// Data schemas: orchestrator tracks activeRecipe, currentStepIndex, stepHistory, isRunning, statusMessage; uses DesignBridge + DesignCodeLink + DesignArtifactExporter.
// User instruction: "启动 Phase 4" — Task #48 端到端工作流编排

import SwiftUI
import Combine
import os.log

private let workflowLog = Logger(subsystem: "com.fusion.studio", category: "DesignWorkflowOrchestrator")

enum WorkflowRecipe: String, CaseIterable {
    case designToCode = "Design → Code"
    case codeToDesign = "Code → Design"
    case screenshotToDesignToCode = "Screenshot → Design → Code"

    var icon: String {
        switch self {
        case .designToCode: return "paintbrush.arrow.right"
        case .codeToDesign: return "chevron.left.forwardslash.chevron.right.arrow.right.paintbrush"
        case .screenshotToDesignToCode: return "camera.arrow.right.paintbrush.arrow.right.chevron.left.forwardslash.chevron.right"
        }
    }

    var steps: [WorkflowStep] {
        switch self {
        case .designToCode:
            return [.createDesign, .previewDesign, .exportToCode, .openInEditor]
        case .codeToDesign:
            return [.selectCodeFile, .importToDesign, .editDesign, .syncBack]
        case .screenshotToDesignToCode:
            return [.captureScreenshot, .analyzeScreenshot, .generateDesign, .exportToCode, .openInEditor]
        }
    }

    var description: String {
        switch self {
        case .designToCode: return "Create design in Design module, export to code files"
        case .codeToDesign: return "Import existing code into Design module for visual editing"
        case .screenshotToDesignToCode: return "Capture screenshot, AI-generate design, export to code"
        }
    }
}

enum WorkflowStep: String {
    case createDesign = "Create Design"
    case previewDesign = "Preview Design"
    case exportToCode = "Export to Code"
    case openInEditor = "Open in Editor"
    case selectCodeFile = "Select Code File"
    case importToDesign = "Import to Design"
    case editDesign = "Edit Design"
    case syncBack = "Sync Back to File"
    case captureScreenshot = "Capture Screenshot"
    case analyzeScreenshot = "Analyze Screenshot"
    case generateDesign = "Generate Design"

    var icon: String {
        switch self {
        case .createDesign: return "plus.rectangle"
        case .previewDesign: return "eye"
        case .exportToCode: return "square.and.arrow.up"
        case .openInEditor: return "chevron.left.forwardslash.chevron.right"
        case .selectCodeFile: return "doc.text"
        case .importToDesign: return "square.and.arrow.down"
        case .editDesign: return "pencil"
        case .syncBack: return "arrow.uturn.right"
        case .captureScreenshot: return "camera"
        case .analyzeScreenshot: return "brain"
        case .generateDesign: return "wand.and.stars"
        }
    }
}

@MainActor
class DesignWorkflowOrchestrator: ObservableObject {
    static let shared = DesignWorkflowOrchestrator()

    @Published var activeRecipe: WorkflowRecipe?
    @Published var currentStepIndex: Int = 0
    @Published var stepHistory: [WorkflowStep] = []
    @Published var isRunning: Bool = false
    @Published var statusMessage: String?

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    var currentStep: WorkflowStep? {
        guard let recipe = activeRecipe, currentStepIndex < recipe.steps.count else { return nil }
        return recipe.steps[currentStepIndex]
    }

    var progress: Double {
        guard let recipe = activeRecipe, !recipe.steps.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(recipe.steps.count)
    }

    func start(recipe: WorkflowRecipe, designBridge: DesignBridge) {
        activeRecipe = recipe
        currentStepIndex = 0
        stepHistory = []
        isRunning = true
        statusMessage = "开始工作流: \(recipe.rawValue)"
        workflowLog.info("Workflow started: \(recipe.rawValue)")
        executeCurrentStep(designBridge: designBridge)
    }

    func cancel() {
        activeRecipe = nil
        currentStepIndex = 0
        isRunning = false
        statusMessage = "工作流已取消"
        workflowLog.info("Workflow cancelled")
    }

    func advanceStep(designBridge: DesignBridge) {
        if let step = currentStep {
            stepHistory.append(step)
        }
        guard let recipe = activeRecipe else { return }
        self.currentStepIndex += 1
        if self.currentStepIndex >= recipe.steps.count {
            self.isRunning = false
            self.statusMessage = "✅ 工作流完成: \(recipe.rawValue)"
            workflowLog.info("Workflow completed: \(recipe.rawValue)")
        } else {
            executeCurrentStep(designBridge: designBridge)
        }
    }

    private func executeCurrentStep(designBridge: DesignBridge) {
        guard let step = currentStep else { return }
        statusMessage = "执行: \(step.rawValue)"
        workflowLog.info("Step \(self.currentStepIndex + 1): \(step.rawValue)")

        switch step {
        case .exportToCode:
            let projectId = FusionProjectManager.shared.activeProject?.id.uuidString
            DesignCodeLink.shared.pushDesignToFile(designBridge: designBridge, projectId: projectId)
            advanceStep(designBridge: designBridge)

        case .openInEditor:
            NotificationCenter.default.post(name: .switchToCodeModule, object: nil)
            advanceStep(designBridge: designBridge)

        case .syncBack:
            let projectId = FusionProjectManager.shared.activeProject?.id.uuidString
            DesignCodeLink.shared.pushDesignToFile(designBridge: designBridge, projectId: projectId)
            advanceStep(designBridge: designBridge)

        case .captureScreenshot:
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            task.launch()
            statusMessage = "截图已保存到剪贴板，请粘贴到 Design 聊天中"
            workflowLog.info("Screenshot captured")

        case .previewDesign, .createDesign, .editDesign, .generateDesign, .analyzeScreenshot:
            statusMessage = "请在 Design 模块中完成: \(step.rawValue)"

        case .selectCodeFile, .importToDesign:
            statusMessage = "请选择文件并导入到 Design 模块"
        }
    }
}

extension Notification.Name {
    static let switchToCodeModule = Notification.Name("switchToCodeModule")
}

struct WorkflowRecipePicker: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var designBridge: DesignBridge
    @ObservedObject var orchestrator = DesignWorkflowOrchestrator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("设计工作流")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.text)

            ForEach(WorkflowRecipe.allCases, id: \.self) { recipe in
                Button(action: {
                    orchestrator.start(recipe: recipe, designBridge: designBridge)
                }) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: recipe.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recipe.rawValue)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            Text(recipe.description)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, theme.spacingXS)
                    .padding(.horizontal, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceSecondary)
                    )
                }
                .buttonStyle(.plain)
            }

            if orchestrator.isRunning {
                Divider()
                workflowProgress
            }
        }
        .padding(theme.spacingM)
        .frame(width: 280)
    }

    private var workflowProgress: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(orchestrator.activeRecipe?.rawValue ?? "")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Spacer()
                Text("\(Int(orchestrator.progress * 100))%")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            ProgressView(value: orchestrator.progress)
                .tint(theme.accent)

            if let step = orchestrator.currentStep {
                HStack(spacing: 4) {
                    Image(systemName: step.icon)
                        .font(.system(size: 9))
                    Text(step.rawValue)
                        .font(.system(size: 9))
                }
                .foregroundStyle(theme.textSecondary)
            }

            if let msg = orchestrator.statusMessage {
                Text(msg)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }

            Button("取消工作流") {
                orchestrator.cancel()
            }
            .font(.system(size: 9))
            .foregroundStyle(.red)
            .buttonStyle(.plain)
        }
    }
}
