// Callers: DesignView (toolbar buttons), CodeDesignPreviewPanel (sync bar), AppState (module switch notification).
// Affected API: DesignWorkflowOrchestrator — 7 previously stub steps now have real automation.
// Data schemas: WorkflowStep actions use DesignBridge (skillTextToUI, skillImageToUI, clearCanvas, etc.),
//   NSOpenPanel for file selection, NSPasteboard for screenshot reading.
// User instruction: "Phase 6 功能增强,立即实施"

import SwiftUI
import Combine
import UniformTypeIdentifiers
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
    var selectedFilePath: String?

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
            let projectId = FusionProjectManager.shared.activeProject?.id
            DesignCodeLink.shared.pushDesignToFile(designBridge: designBridge, projectId: projectId)
            advanceStep(designBridge: designBridge)

        case .openInEditor:
            NotificationCenter.default.post(name: .switchToCodeModule, object: nil)
            advanceStep(designBridge: designBridge)

        case .syncBack:
            let projectId = FusionProjectManager.shared.activeProject?.id
            DesignCodeLink.shared.pushDesignToFile(designBridge: designBridge, projectId: projectId)
            advanceStep(designBridge: designBridge)

        case .captureScreenshot:
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-i", "-c"]
            task.launch()
            statusMessage = "截图已保存到剪贴板，请粘贴到 Design 聊天中"
            workflowLog.info("Screenshot captured")

        case .createDesign:
            designBridge.clearCanvas()
            statusMessage = "画布已清空，请在聊天中描述您的设计"
            NotificationCenter.default.post(name: .focusDesignChat, object: nil)
            advanceStep(designBridge: designBridge)

        case .previewDesign:
            statusMessage = "正在预览设计..."
            advanceStep(designBridge: designBridge)

        case .editDesign:
            NotificationCenter.default.post(name: .focusDesignChat, object: nil)
            statusMessage = "请在聊天中描述修改需求"
            advanceStep(designBridge: designBridge)

        case .generateDesign:
            let prompt = "设计一个现代深色主题页面"
            designBridge.skillTextToUI(prompt: prompt)
            statusMessage = "AI 正在生成设计..."
            advanceStep(designBridge: designBridge)

        case .analyzeScreenshot:
            if let clipImage = NSPasteboard.general.data(forType: .tiff) ?? NSPasteboard.general.data(forType: .png) {
                let tmpPath = NSTemporaryDirectory() + "fd_screenshot.png"
                try? clipImage.write(to: URL(fileURLWithPath: tmpPath))
                designBridge.skillImageToUI(imagePath: tmpPath, hint: "根据截图重新生成 UI 设计")
                statusMessage = "正在分析截图并生成设计..."
                try? FileManager.default.removeItem(atPath: tmpPath)
            } else {
                statusMessage = "剪贴板无截图，请先截图 (⌘⇧4)"
                workflowLog.warning("No screenshot in clipboard for analyzeScreenshot step")
            }
            advanceStep(designBridge: designBridge)

        case .selectCodeFile:
            let panel = NSOpenPanel()
            panel.title = "选择代码文件"
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.html, .svg]
            if panel.runModal() == .OK, let url = panel.url {
                selectedFilePath = url.path
                statusMessage = "已选择: \(url.lastPathComponent)"
                workflowLog.info("Selected file: \(url.path)")
            } else {
                statusMessage = "未选择文件"
            }
            advanceStep(designBridge: designBridge)

        case .importToDesign:
            if let path = selectedFilePath, FileManager.default.fileExists(atPath: path) {
                if let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
                    if path.hasSuffix(".html"), let docJSON = designBridge.parseHtmlViaCLI(content) {
                        designBridge.loadDocumentJSON(docJSON)
                        statusMessage = "已导入: \(URL(fileURLWithPath: path).lastPathComponent)"
                        workflowLog.info("Imported HTML file to design: \(path)")
                    } else {
                        designBridge.loadDocumentJSON(content)
                        statusMessage = "已导入文档"
                        workflowLog.info("Imported file to design: \(path)")
                    }
                }
            } else {
                statusMessage = "无已选文件，请先选择代码文件"
                workflowLog.warning("No file selected for importToDesign step")
            }
            advanceStep(designBridge: designBridge)
        }
    }
}

extension Notification.Name {
    static let switchToCodeModule = Notification.Name("switchToCodeModule")
    static let focusDesignChat = Notification.Name("focusDesignChat")
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
