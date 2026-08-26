// Callers: DesignView (toolbar buttons), CodeDesignPreviewPanel (sync bar), AppState (module switch notification).
// Affected API: DesignWorkflowOrchestrator — 7-step design automation workflow.
// Data schemas: WorkflowStep actions use DesignBridge (skillTextToUI, skillImageToUI, clearCanvas, etc.),
//   NSOpenPanel for file selection, NSPasteboard for screenshot reading.

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

    var localLabel: String {
        switch self {
        case .designToCode: return I18nManager.shared.t(.design_wf_recipe_designToCode)
        case .codeToDesign: return I18nManager.shared.t(.design_wf_recipe_codeToDesign)
        case .screenshotToDesignToCode: return I18nManager.shared.t(.design_wf_recipe_screenshot)
        }
    }

    var localDescription: String {
        switch self {
        case .designToCode: return I18nManager.shared.t(.design_wf_recipe_designToCodeDesc)
        case .codeToDesign: return I18nManager.shared.t(.design_wf_recipe_codeToDesignDesc)
        case .screenshotToDesignToCode: return I18nManager.shared.t(.design_wf_recipe_screenshotDesc)
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

    var localLabel: String {
        switch self {
        case .createDesign: return I18nManager.shared.t(.design_wf_step_createDesign)
        case .previewDesign: return I18nManager.shared.t(.design_wf_step_previewDesign)
        case .exportToCode: return I18nManager.shared.t(.design_wf_step_exportToCode)
        case .openInEditor: return I18nManager.shared.t(.design_wf_step_openInEditor)
        case .selectCodeFile: return I18nManager.shared.t(.design_wf_step_selectCodeFile)
        case .importToDesign: return I18nManager.shared.t(.design_wf_step_importToDesign)
        case .editDesign: return I18nManager.shared.t(.design_wf_step_editDesign)
        case .syncBack: return I18nManager.shared.t(.design_wf_step_syncBack)
        case .captureScreenshot: return I18nManager.shared.t(.design_wf_step_captureScreenshot)
        case .analyzeScreenshot: return I18nManager.shared.t(.design_wf_step_analyzeScreenshot)
        case .generateDesign: return I18nManager.shared.t(.design_wf_step_generateDesign)
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
        statusMessage = String(format: I18nManager.shared.t(.design_wf_startFmt), recipe.rawValue)
        workflowLog.info("Workflow started: \(recipe.rawValue)")
        executeCurrentStep(designBridge: designBridge)
    }

    func cancel() {
        activeRecipe = nil
        currentStepIndex = 0
        isRunning = false
        statusMessage = I18nManager.shared.t(.design_wf_cancelled)
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
            self.statusMessage = String(format: I18nManager.shared.t(.design_wf_doneFmt), recipe.rawValue)
            workflowLog.info("Workflow completed: \(recipe.rawValue)")
        } else {
            executeCurrentStep(designBridge: designBridge)
        }
    }

    private func executeCurrentStep(designBridge: DesignBridge) {
        guard let step = currentStep else { return }
        statusMessage = String(format: I18nManager.shared.t(.design_wf_execFmt), step.rawValue)
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
            // HIGH-4: 旧 fire-and-forget Process 出作用域被 ARC 回收, 交互截图变孤儿。
            // 改用 ScreenCapture 单例保活 + terminationHandler, 不阻塞协作线程池。
            Task {
                let code = await ScreenCapture.shared.captureInteractive()
                await MainActor.run {
                    if code == 0 {
                        workflowLog.info("Screenshot captured code=\(code)")
                    } else {
                        workflowLog.warning("Screenshot 取消或失败 code=\(code)")
                    }
                }
            }
            statusMessage = I18nManager.shared.t(.design_wf_ssSaved)

        case .createDesign:
            designBridge.clearCanvas()
            statusMessage = I18nManager.shared.t(.design_wf_canvasCleared)
            NotificationCenter.default.post(name: .focusDesignChat, object: nil)
            advanceStep(designBridge: designBridge)

        case .previewDesign:
            statusMessage = I18nManager.shared.t(.design_wf_previewing)
            advanceStep(designBridge: designBridge)

        case .editDesign:
            NotificationCenter.default.post(name: .focusDesignChat, object: nil)
            statusMessage = I18nManager.shared.t(.design_wf_editHint)
            advanceStep(designBridge: designBridge)

        case .generateDesign:
            let prompt = I18nManager.shared.t(.design_wf_seedPrompt)
            designBridge.skillTextToUI(prompt: prompt)
            statusMessage = I18nManager.shared.t(.design_wf_generating)
            advanceStep(designBridge: designBridge)

        case .analyzeScreenshot:
            if let clipImage = NSPasteboard.general.data(forType: .tiff) ?? NSPasteboard.general.data(forType: .png) {
                // F-I6: 固定名 fd_screenshot.png 散落系统 /tmp + 无 0600 → TOCTOU + 路径泄露。
                // 改统一目录 + UUID + 0600。用 writeTmpFile (Data 字节写入, .png ext)。
                guard let tmpPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_screenshot", ext: "png", contents: clipImage) else {
                    statusMessage = I18nManager.shared.t(.design_wf_noScreenshot)
                    workflowLog.error("F-I6 screenshot tmp write failed")
                    advanceStep(designBridge: designBridge)
                    return
                }
                designBridge.skillImageToUI(imagePath: tmpPath, hint: I18nManager.shared.t(.design_wf_regenHint))
                statusMessage = I18nManager.shared.t(.design_wf_analyzing)
                try? FileManager.default.removeItem(atPath: tmpPath)
            } else {
                statusMessage = I18nManager.shared.t(.design_wf_noScreenshot)
                workflowLog.warning("No screenshot in clipboard for analyzeScreenshot step")
            }
            advanceStep(designBridge: designBridge)

        case .selectCodeFile:
            let panel = NSOpenPanel()
            panel.title = I18nManager.shared.t(.design_wf_selectCodeFile)
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.html, .svg]
            if panel.runModal() == .OK, let url = panel.url {
                selectedFilePath = url.path
                statusMessage = String(format: I18nManager.shared.t(.design_wf_selectedFmt), url.lastPathComponent)
                workflowLog.info("Selected file: \(url.path)")
            } else {
                statusMessage = I18nManager.shared.t(.design_wf_notSelected)
            }
            advanceStep(designBridge: designBridge)

        case .importToDesign:
            if let path = selectedFilePath, FileManager.default.fileExists(atPath: path) {
                if let content = try? String(contentsOfFile: path, encoding: .utf8), !content.isEmpty {
                    if path.hasSuffix(".html"), let docJSON = designBridge.parseHtmlViaCLI(content) {
                        designBridge.loadDocumentJSON(docJSON)
                        statusMessage = String(format: I18nManager.shared.t(.design_wf_importedFmt), URL(fileURLWithPath: path).lastPathComponent)
                        workflowLog.info("Imported HTML file to design: \(path)")
                    } else {
                        designBridge.loadDocumentJSON(content)
                        statusMessage = I18nManager.shared.t(.design_wf_importedDoc)
                        workflowLog.info("Imported file to design: \(path)")
                    }
                }
            } else {
                statusMessage = I18nManager.shared.t(.design_wf_noFileSelected)
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
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.design_wf_panelTitle))
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
                            Text(recipe.localLabel)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                                .foregroundStyle(theme.text)
                            Text(recipe.localDescription)
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
                Text(orchestrator.activeRecipe?.localLabel ?? "")
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
                    Text(step.localLabel)
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

            Button(i18n.t(.design_wf_cancelBtn)) {
                orchestrator.cancel()
            }
            .font(.system(size: 9))
            .foregroundStyle(.red)
            .buttonStyle(.plain)
        }
    }
}
