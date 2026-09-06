// Callers: DesignView, DesignChatPanel, DesignPreviewView — all Design module views.
// Affected API: DesignBridge @MainActor ObservableObject (published properties + async methods + memoryCheckMB).
// Data schemas: DesignMessage (role/content/timestamp/artifactInfo), ArtifactParseResult (type/title/identifier/code), DesignPage (id/artifactId/title/type/code/createdAt).
// User instruction: "按照P1~P6顺序实施所有未完成的任务" — Task #37 P6-3 内存泄漏检测+长时间运行稳定性

import AppKit
import Combine
import MachO
import WebKit
import os.log

private let designBridgeLog = Logger(subsystem: "com.fusion.studio", category: "DesignBridge")
struct DesignMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
    let timestamp: Date
    var artifactInfo: ArtifactParseResult?
}

struct ArtifactParseResult {
    var type: String
    var title: String
    var identifier: String
    var code: String
}

struct DesignPage: Identifiable {
    let id = UUID()
    var artifactId: String
    var title: String
    var type: String
    var code: String
    var createdAt: Date

    init(artifactId: String = "", title: String = "Untitled", type: String = "html", code: String = "") {
        self.artifactId = artifactId
        self.title = title
        self.type = type
        self.code = code
        self.createdAt = Date()
    }
}

struct DesignLintIssue: Identifiable {
    let id = UUID()
    let rule: String
    let severity: String
    let message: String
    let nodeID: String?
    let suggestion: String?
}

struct DesignDiffEntry: Identifiable {
    let id = UUID()
    let kind: String
    let path: String
    let oldValue: String?
    let newValue: String?
}

struct VariantPage: Identifiable {
    let id: String
    let title: String
    let documentJSON: String
}

enum DesignSkill: String, CaseIterable, Identifiable {
    case textToUI = "text_to_ui"
    case imageToUI = "image_to_ui"
    case partialEdit = "partial_edit"
    case localEdit = "local_edit"
    case simPanel = "sim_panel"
    case multiVariants = "multi_variants"
    case specDoc = "spec_doc"
    case pageFlow = "page_flow"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .textToUI: return I18nManager.shared.t(.dsk_name_textToUI)
        case .imageToUI: return I18nManager.shared.t(.dsk_name_imageToUI)
        case .partialEdit: return I18nManager.shared.t(.dsk_name_partialEdit)
        case .localEdit: return I18nManager.shared.t(.dsk_name_localEdit)
        case .simPanel: return I18nManager.shared.t(.dsk_name_simPanel)
        case .multiVariants: return I18nManager.shared.t(.dsk_name_multiVariants)
        case .specDoc: return I18nManager.shared.t(.dsk_name_specDoc)
        case .pageFlow: return I18nManager.shared.t(.dsk_name_pageFlow)
        }
    }

    var icon: String {
        switch self {
        case .textToUI: return "text.bubble"
        case .imageToUI: return "photo.on.rectangle"
        case .partialEdit: return "pencil.circle"
        case .localEdit: return "scope"
        case .simPanel: return "square.on.square"
        case .multiVariants: return "square.grid.3x3"
        case .specDoc: return "doc.text.magnifyingglass"
        case .pageFlow: return "arrow.triangle.branch"
        }
    }

    var description: String {
        switch self {
        case .textToUI: return I18nManager.shared.t(.dsk_desc_textToUI)
        case .imageToUI: return I18nManager.shared.t(.dsk_desc_imageToUI)
        case .partialEdit: return I18nManager.shared.t(.dsk_desc_partialEdit)
        case .localEdit: return I18nManager.shared.t(.dsk_desc_localEdit)
        case .simPanel: return I18nManager.shared.t(.dsk_desc_simPanel)
        case .multiVariants: return I18nManager.shared.t(.dsk_desc_multiVariants)
        case .specDoc: return I18nManager.shared.t(.dsk_desc_specDoc)
        case .pageFlow: return I18nManager.shared.t(.dsk_desc_pageFlow)
        }
    }
}

enum DesignTemplateGroup: String, CaseIterable, Identifiable {
    case pages = "pages"
    case components = "components"
    case skills = "skills"

    var id: String { rawValue }

    var localLabel: String {
        switch self {
        case .pages: return I18nManager.shared.t(.design_grp_pages)
        case .components: return I18nManager.shared.t(.design_grp_components)
        case .skills: return I18nManager.shared.t(.design_grp_skills)
        }
    }

    var icon: String {
        switch self {
        case .pages: return "doc.richtext"
        case .components: return "square.on.square.dashed"
        case .skills: return "wand.and.stars"
        }
    }
}


@MainActor
class DesignBridge: ObservableObject {
    // ARCH-1 (审计product-0906 P1): 38 @Published 拆 10 域 ObservableObject。let 域引用 = 稳定身份,
    //   init() objectWillChange.sink 转发每域 (SwiftUI 不自动追踪嵌套 ObservableObject, P0-1 修)。
    //   38 属性经下方计算属性 get/set 转发, 113 view 读站点 + 2 $binding 站点 0 改 (计算属性 get/set
    //   不产 $projectedValue → $designBridge.X 报错; 惟 currentArtifactCode 2 站点改 Binding(get:set:))。
    //   行为按域 Phase 2-8 迁入 Design<Domain>Service.swift extension。
    let chatState = DesignChatState()
    let artifactState = DesignArtifactState()
    let pageState = DesignPageState()
    let canvasState = DesignCanvasState()
    let planPreviewState = DesignPlanPreviewState()
    let skillState = DesignSkillState()
    let versionState = DesignVersionState()
    let themeState = DesignThemeState()
    let exportState = DesignExportState()
    let fileSyncState = DesignFileSyncState()
    private var cancellables = Set<AnyCancellable>()

    init() {
        chatState.bridge = self
        artifactState.bridge = self
        pageState.bridge = self
        canvasState.bridge = self
        planPreviewState.bridge = self
        skillState.bridge = self
        versionState.bridge = self
        themeState.bridge = self
        exportState.bridge = self
        fileSyncState.bridge = self
        chatState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        artifactState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        pageState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        canvasState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        planPreviewState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        skillState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        versionState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        themeState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        exportState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        fileSyncState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        designBridgeLog.info("DesignBridge init: 10 域 objectWillChange 转发已接线 (ARCH-1)")
    }


    // MARK: - Chat State 转发
    var messages: [DesignMessage] {
        get { chatState.messages } set { chatState.messages = newValue }
    }
    var isGenerating: Bool {
        get { chatState.isGenerating } set { chatState.isGenerating = newValue }
    }
    var inferenceStep: String {
        get { chatState.inferenceStep } set { chatState.inferenceStep = newValue }
    }
    var streamTokenCount: Int {
        get { chatState.streamTokenCount } set { chatState.streamTokenCount = newValue }
    }
    var streamPreviewText: String {
        get { chatState.streamPreviewText } set { chatState.streamPreviewText = newValue }
    }
    var errorMessage: String? {
        get { chatState.errorMessage } set { chatState.errorMessage = newValue }
    }
    var selectedModel: String {
        get { chatState.selectedModel } set { chatState.selectedModel = newValue }
    }

    // MARK: - Artifact State 转发
    var currentArtifactCode: String {
        get { artifactState.currentArtifactCode } set { artifactState.currentArtifactCode = newValue }
    }
    var currentArtifactType: String {
        get { artifactState.currentArtifactType } set { artifactState.currentArtifactType = newValue }
    }
    var currentArtifactTitle: String {
        get { artifactState.currentArtifactTitle } set { artifactState.currentArtifactTitle = newValue }
    }
    var artifactSaved: Bool {
        get { artifactState.artifactSaved } set { artifactState.artifactSaved = newValue }
    }
    var artifactId: String {
        get { artifactState.artifactId } set { artifactState.artifactId = newValue }
    }
    var isImportingScreenshot: Bool {
        get { artifactState.isImportingScreenshot } set { artifactState.isImportingScreenshot = newValue }
    }

    // MARK: - Page State 转发
    var pages: [DesignPage] {
        get { pageState.pages } set { pageState.pages = newValue }
    }
    var currentPageIndex: Int {
        get { pageState.currentPageIndex } set { pageState.currentPageIndex = newValue }
    }

    // MARK: - Canvas State 转发
    var selectedNodeID: String? {
        get { canvasState.selectedNodeID } set { canvasState.selectedNodeID = newValue }
    }
    var lastRenderedDocumentJSON: String? {
        get { canvasState.lastRenderedDocumentJSON } set { canvasState.lastRenderedDocumentJSON = newValue }
    }
    var marqueeSelectedNodeIDs: [String] {
        get { canvasState.marqueeSelectedNodeIDs } set { canvasState.marqueeSelectedNodeIDs = newValue }
    }
    var canvasWebView: WKWebView? {
        get { canvasState.canvasWebView } set { canvasState.canvasWebView = newValue }
    }

    // MARK: - Plan Preview State 转发
    var pendingPlanCode: String? {
        get { planPreviewState.pendingPlanCode } set { planPreviewState.pendingPlanCode = newValue }
    }
    var isPlanPreviewActive: Bool {
        get { planPreviewState.isPlanPreviewActive } set { planPreviewState.isPlanPreviewActive = newValue }
    }
    var pendingPlanTitle: String {
        get { planPreviewState.pendingPlanTitle } set { planPreviewState.pendingPlanTitle = newValue }
    }

    // MARK: - Skill State 转发
    var lastSkillOutput: String {
        get { skillState.lastSkillOutput } set { skillState.lastSkillOutput = newValue }
    }
    var isSkillRunning: Bool {
        get { skillState.isSkillRunning } set { skillState.isSkillRunning = newValue }
    }
    var variantPages: [VariantPage] {
        get { skillState.variantPages } set { skillState.variantPages = newValue }
    }

    // MARK: - Version State 转发
    var versionHistory: [[String: Any]] {
        get { versionState.versionHistory } set { versionState.versionHistory = newValue }
    }
    var isLoadingHistory: Bool {
        get { versionState.isLoadingHistory } set { versionState.isLoadingHistory = newValue }
    }
    var versionDiffEntries: [DesignDiffEntry] {
        get { versionState.versionDiffEntries } set { versionState.versionDiffEntries = newValue }
    }
    var isDiffing: Bool {
        get { versionState.isDiffing } set { versionState.isDiffing = newValue }
    }

    // MARK: - Theme State 转发
    var activeTheme: String {
        get { themeState.activeTheme } set { themeState.activeTheme = newValue }
    }
    var activeDesignSystem: String {
        get { themeState.activeDesignSystem } set { themeState.activeDesignSystem = newValue }
    }

    // MARK: - Export State 转发
    var exportedSwiftUICode: String {
        get { exportState.exportedSwiftUICode } set { exportState.exportedSwiftUICode = newValue }
    }
    var isExportingSwiftUI: Bool {
        get { exportState.isExportingSwiftUI } set { exportState.isExportingSwiftUI = newValue }
    }
    var exportedCodegenCode: String {
        get { exportState.exportedCodegenCode } set { exportState.exportedCodegenCode = newValue }
    }
    var isExportingCodegen: Bool {
        get { exportState.isExportingCodegen } set { exportState.isExportingCodegen = newValue }
    }
    var isBatchExporting: Bool {
        get { exportState.isBatchExporting } set { exportState.isBatchExporting = newValue }
    }
    var batchExportResult: String {
        get { exportState.batchExportResult } set { exportState.batchExportResult = newValue }
    }

    // MARK: - FileSync State 转发
    var syncFolderPath: String {
        get { fileSyncState.syncFolderPath } set { fileSyncState.syncFolderPath = newValue }
    }
    var isFileSyncEnabled: Bool {
        get { fileSyncState.isFileSyncEnabled } set { fileSyncState.isFileSyncEnabled = newValue }
    }

    // ARCH-1 Phase 7: internal (非 private) — Theme/Export/RAG 跨文件 extension reach-through (bridge?.ipcClient)。
    var ipcClient: IPCClient?
    // MARK: - Canvas Bridge Commands

    func sendCanvasCommand(_ command: BridgeCommand) { canvasState.sendCanvasCommand(command) }

    // #372 OPS-13: 触发 fd-host-web 日志环形缓冲 dump。
    // 走 window.postMessage({kind:'log.capture.dump',...}) 通道 (非 BridgeCommand, 上游 bridge.rs:187)。
    // 触发源: DesignLintPanel 手动按钮 / WebView 进程崩溃恢复 / App 进入前台 (节流)。
    func dumpWasmLog(clear: Bool) { canvasState.dumpWasmLog(clear: clear) }

    func applyDesignTokensToCanvas(_ css: String) { canvasState.applyDesignTokensToCanvas(css) }

    func renderDocumentToCanvas(_ documentJSON: String) { canvasState.renderDocumentToCanvas(documentJSON) }

    func clearCanvas() { canvasState.clearCanvas() }

    func selectCanvasNode(_ nodeID: String) { canvasState.selectCanvasNode(nodeID) }

    func mutateCanvasNode(_ nodeID: String, x: Float?, y: Float?, w: Float?, h: Float?,
                          fill: String? = nil, stroke: String? = nil, strokeWidth: Float? = nil,
                          radius: Float? = nil, fontSize: Float? = nil, fontFamily: String? = nil,
                          opacity: Float? = nil) {
        canvasState.mutateCanvasNode(nodeID, x: x, y: y, w: w, h: h,
                                     fill: fill, stroke: stroke, strokeWidth: strokeWidth,
                                     radius: radius, fontSize: fontSize, fontFamily: fontFamily,
                                     opacity: opacity)
    }

    func setNodeLocked(_ nodeID: String, locked: Bool) { canvasState.setNodeLocked(nodeID, locked: locked) }

    func undo() { canvasState.undo() }

    func redo() { canvasState.redo() }

    func setNodeVisibility(_ nodeID: String, visible: Bool) { canvasState.setNodeVisibility(nodeID, visible: visible) }

    func reorderNode(_ nodeID: String, newIndex: Int) { canvasState.reorderNode(nodeID, newIndex: newIndex) }

    func deleteNode(_ nodeID: String) { canvasState.deleteNode(nodeID) }

    func duplicateNode(_ nodeID: String) { canvasState.duplicateNode(nodeID) }

    func bringToFront(_ nodeID: String) { canvasState.bringToFront(nodeID) }

    func sendToBack(_ nodeID: String) { canvasState.sendToBack(nodeID) }

    func applyLocalEdit(nodesJSON: String, instruction: String) {
        guard !marqueeSelectedNodeIDs.isEmpty else {
            designBridgeLog.warning("DesignBridge: applyLocalEdit with no marquee selection")
            return
        }
        // 审计0830 P1-资源-3: 旧 Task { @MainActor in ... runFusionDesign(...) } 把 180s CLI 阻塞调用
        //   放 MainActor → UI 完全冻结 180s (同步 Process.run)。修正: MainActor 仅采集输入 + 回写结果,
        //   CLI 阻塞调用移 Task.detached 跑在后台线程, 不阻塞主线程渲染。
        Task { @MainActor in
            let effectiveNodesJSON: String
            if nodesJSON.isEmpty || nodesJSON == "[]" {
                effectiveNodesJSON = canvasState.extractSelectedNodesJSON()
            } else {
                effectiveNodesJSON = nodesJSON
            }
            let contextMsg = DesignPrompts.dispatcher.applyLocalEditContext(effectiveNodesJSON, instruction)
            // CLI 阻塞调用移出 MainActor, 后台线程执行。effectiveNodesJSON/contextMsg/cliPath 已是值快照, 无共享态竞争。
            //   旧 runFusionDesign 整体 MainActor-isolated (依赖 resolveCLIPath 读缓存态), 不能直接 detached 调。
            //   预解析 cliPath 在 MainActor, 传 nonisolated static runCLIProcess 跑 Process, 不阻塞主线程。
            let cliPath = resolveCLIPath()
            let result = await Task.detached(priority: .userInitiated) {
                Self.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", contextMsg, "--page", "LocalEdit"],
                    stdin: effectiveNodesJSON
                )
            }.value
            if result.exitCode == 0, !result.output.isEmpty {
                if let data = result.output.data(using: .utf8),
                   let _ = try? JSONSerialization.jsonObject(with: data) {
                    canvasState.applyPartialEditResult(result.output)
                } else {
                    await sendDesignChat(instruction)
                }
            } else {
                designBridgeLog.info("DesignBridge: local-edit CLI unavailable, falling back to MLX chat")
                await sendDesignChat(instruction)
            }
        }
    }

    func startObservingInspectorChanges() { canvasState.startObservingInspectorChanges() }

    deinit {
        // ARCH-1 Phase 5: canvasState.cleanup() nonisolated + codeWatchTimer/mutateObserver nonisolated(unsafe),
        //   Timer.invalidate / NotificationCenter.removeObserver 线程安全 (镜像 AgentBridge F-R9 deinit 模式)。
        canvasState.cleanup()
    }

    // MARK: - Reverse Code Watch (Fusion Code → Canvas)

    /// 启动反向监听：每 3 秒扫描 fusion-code IPC 目录的 style-change 消息。
    func startWatchingCodeChanges() { canvasState.startWatchingCodeChanges() }

    func stopWatchingCodeChanges() { canvasState.stopWatchingCodeChanges() }

    // MARK: - AI Artifact → Canvas Rendering

    /// AI artifact 完成后：HTML→PenDocument→Plan Preview + Token CSS 注入。
    /// 预览模式下先暂存，用户确认后才写入画布。
    private func renderArtifactToCanvas() async {
        // 1. HTML → PenDocument JSON via CLI
        guard let penDocJSON = await parseHtmlViaCLI(currentArtifactCode) else {
            designBridgeLog.warning("DesignBridge: parseHtmlViaCLI failed, skipping canvas render")
            return
        }
        // 2. 注入设计 Token CSS
        if let tokenCSS = await fetchTokenCSSViaCLI() {
            applyDesignTokensToCanvas(tokenCSS)
            designBridgeLog.info("DesignBridge: token CSS injected (\(tokenCSS.count) chars)")
        }
        // 3. Plan 预览：暂存到 pendingPlanCode，不直接渲染
        pendingPlanCode = penDocJSON
        pendingPlanTitle = currentArtifactTitle
        isPlanPreviewActive = true
        // 发送 PlanPreview 命令到 wasm，让画布显示虚线预览
        sendCanvasCommand(.planPreview(documentJSON: penDocJSON))
        designBridgeLog.info("DesignBridge: Plan preview staged, title=\(self.currentArtifactTitle)")
    }

    /// 确认 Plan：将暂存的 PenDocument 写入画布。ARCH-1 Phase 6: 行为迁 DesignPlanPreviewService。
    func acceptPlan() { planPreviewState.acceptPlan() }

    /// 拒绝 Plan：清除预览，恢复画布状态。ARCH-1 Phase 6: 行为迁 DesignPlanPreviewService。
    func rejectPlan() { planPreviewState.rejectPlan() }

    /// 调用 fusion-design parse-html CLI 将 HTML 转为 PenDocument JSON。
    func parseHtmlViaCLI(_ html: String) async -> String? { await chatState.parseHtmlViaCLI(html) }


    /// 净化不可信 HTML: 剥 script/iframe/object/embed/math 块 + on* 事件属性 + javascript:/vbscript: URL + <style> 块内 CSS XSS 向量 (expression/url-js/@import/behavior)。svg/<style> 块本体保留 (设计 legit), 其 XSS 向量由 step1/3/4/5 覆盖。
    /// 纵深防御层 — LLM 产物 (currentArtifactCode) 经此过滤后再送 CLI 解析与 wasm/预览渲染。
    /// 迭代剥嵌套标签 (如 <scr<script>ipt>) 防绕过。nonisolated: 纯函数, 便于测试与后台调用。
    nonisolated static func sanitizeHtml(_ html: String) -> String {
        var out = html
        // 0. 迭代剥嵌套 script 标签防 <scr<script>ipt> 绕过, 直至稳定 (上限 5 轮)
        var prev = ""
        var guardCount = 0
        while out != prev && guardCount < 5 {
            prev = out
            // 1. 剥 <script>...</script> (含 <script src=...> 空体), 跨行大小写不敏感
            if let re = try? NSRegularExpression(pattern: #"<script[\s\S]*?</script>"#, options: [.caseInsensitive]) {
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
            }
            if let re = try? NSRegularExpression(pattern: #"<script\b[^>]*>"#, options: [.caseInsensitive]) {
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
            }
            guardCount += 1
        }
        // 2. 剥 <iframe>/<object>/<embed>/<math>...</tag> 及空体 — 纯注入面, 设计产物不用。
        // svg 不剥 (设计图标/形状 legit 用): 其 XSS 向量 (<svg onload>/<svg><script>/xlink:href="javascript:")
        // 已由 step 1 (script) + step 3 (on* 事件属性) + step 4 (javascript: URL) 覆盖。
        for tag in ["iframe", "object", "embed", "math"] {
            if let re = try? NSRegularExpression(pattern: "<\(tag)[\\s\\S]*?</\(tag)>", options: [.caseInsensitive]) {
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
            }
            if let re = try? NSRegularExpression(pattern: "<\(tag)\\b[^>]*/?>", options: [.caseInsensitive]) {
                out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
            }
        }
        // 3. 剥 on* 事件处理器属性 (on\w+="..." / on\w+='...' / on\w+=\S+), 大小写不敏感
        if let re = try? NSRegularExpression(pattern: #"\son\w+\s*=\s*"[^"]*""#, options: [.caseInsensitive]) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        if let re = try? NSRegularExpression(pattern: #"\son\w+\s*=\s*'[^']*'"#, options: [.caseInsensitive]) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        if let re = try? NSRegularExpression(pattern: #"\son\w+\s*=\s*[^\s>]+"#, options: [.caseInsensitive]) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        // 4. 剥 javascript:/vbscript: URL (href/src 属性值内), 大小写不敏感
        if let re = try? NSRegularExpression(pattern: #"(?i)(href|src)\s*=\s*("javascript:[^"]*"|'javascript:[^']*'|javascript:[^\s>]+)"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "$1=\"#\"")
        }
        if let re = try? NSRegularExpression(pattern: #"(?i)(href|src)\s*=\s*("vbscript:[^"]*"|'vbscript:[^']*'|vbscript:[^\s>]+)"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "$1=\"#\"")
        }
        // 5. <style> 块外科净化 (非整块剥): 保留模型按 systemPrompt 产出的 :root 设计 token + 自定义 class
        // (.surface/.text-secondary/...), 仅剥 CSS 内的 XSS 注入向量 — expression()/url(javascript:)/url(vbscript:)/
        // @import/behavior:/-moz-binding:。整块剥会丢暗色主题+布局, 致预览"什么都没有" (#388)。
        out = sanitizeStyleBlock(out)
        return out

    }

    /// 净化 <style>...</style> 块内 CSS 的 XSS 注入向量, 保留合法 CSS (:root vars/自定义 class/body 样式)。
    /// 剥向量: expression(...) · url(javascript:...) · url(vbscript:...) · @import · behavior: · -moz-binding:。
    /// nonisolated 纯函数 (sanitizeHtml static 调用)。
    nonisolated static func sanitizeStyleBlock(_ html: String) -> String {
        // 只在 <style>...</style> 块内净化, 块外 HTML 不动 (inline style 属性的 JS-URL 由 step4 覆盖)。
        guard let re = try? NSRegularExpression(pattern: #"<style[\s\S]*?</style>"#, options: [.caseInsensitive]) else {
            return html
        }
        // 收集全部 style 块匹配, 倒序原地替换 (替换会改变后续 range, 倒序保前序 range 不移位)。
        let matches = re.matches(in: html, range: NSRange(html.startIndex..., in: html))
        guard !matches.isEmpty else { return html }
        let mutable = NSMutableString(string: html)
        var neutralizedCount = 0
        for match in matches.reversed() {
            let raw = mutable.substring(with: match.range)
            let neutralized = neutralizeCssXssVectors(raw)
            if neutralized != raw {
                mutable.replaceCharacters(in: match.range, with: neutralized)
                neutralizedCount += 1
            }
        }
        if neutralizedCount > 0 {
            designBridgeLog.info("sanitizeHtml: neutralized CSS XSS vectors in \(neutralizedCount) <style> block(s), block preserved")
        }
        return mutable as String
    }

    /// 剥单个 CSS 文本内的 XSS 向量子串。保留选择器/属性/值中合法部分。
    nonisolated static func neutralizeCssXssVectors(_ css: String) -> String {
        var out = css
        // expression(...) — IE 表达式注入, 整个 expression(...) 调用剥
        if let re = try? NSRegularExpression(pattern: #"(?i)expression\s*\([^)]*\)"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        // url(javascript:...) / url(vbscript:...) — 资源 URL 内脚本注入, 替换 url() 为空
        if let re = try? NSRegularExpression(pattern: #"(?i)url\(\s*['\"]?\s*(javascript|vbscript)\s*:[^)]*\)"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "url()")
        }
        // @import url(...) — 拉外部恶意样式表 (含 expression), 整条 @import 行剥
        if let re = try? NSRegularExpression(pattern: #"(?i)@import[^;]*;?"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        // behavior: / -moz-binding: — IE/旧 Firefox 行为绑定脚本注入, 值剥 (保留属性名留空)
        if let re = try? NSRegularExpression(pattern: #"(?i)(behavior|-moz-binding)\s*:[^;]*;?"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "")
        }
        return out
    }

    /// BUG-13: 错误响应体原样插 UI 可能泄密钥 — 服务端错误体可回显请求头 (Authorization/Bearer/api_key),
    /// .prefix(200) 限长拦不住密钥子串。渲染前剥敏感子串。nonisolated 纯函数。
    nonisolated static func sanitizeErrorBody(_ body: String) -> String {
        var out = body
        // 剥 Bearer <token> / Authorization: <scheme> <token> 整段, 大小写不敏感
        if let re = try? NSRegularExpression(pattern: #"(?i)bearer\s+[A-Za-z0-9._~+/=-]+"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "Bearer ***")
        }
        if let re = try? NSRegularExpression(pattern: #"(?i)authorization\s*:\s*[^\r\n,]+"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "Authorization: ***")
        }
        // 剥 api_key / api-key / apikey 字段值 (JSON "api_key":"v" 或 form api_key=v 均覆盖)
        if let re = try? NSRegularExpression(pattern: #"(?i)(api[_-]?key)\"?(\s*[:=]\s*)\"?([A-Za-z0-9._~+/=-]+)"#, options: []) {
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "$1$2***")
        }
        return out
    }

    /// 调用 fusion-design token-css CLI 获取当前设计规范的 CSS Custom Properties。
    private func fetchTokenCSSViaCLI() async -> String? {
        let cliPath = resolveCLIPath()
        let result = await Task.detached(priority: .userInitiated) {
            Self.runCLIProcess(cliPath: cliPath, args: ["token-css", "--design-system", "apple-hig"])
        }.value
        guard result.exitCode == 0, !result.output.isEmpty else { return nil }
        return result.output
    }

    /// 查找 fusion-design CLI 二进制路径。
    private func findFusionDesignCLI() -> String {
        // 优先使用同 bundle 内的 CLI
        if let bundlePath = Bundle.main.path(forResource: "fusion-design", ofType: nil) {
            return bundlePath
        }
        // 开发模式：使用 cargo build 输出 (固定已知安全目录, 非 PATH 查找)
        let devPath = NSHomeDirectory() + "/fusion/fusion-design/target/debug/fusion-design"
        if FileManager.default.fileExists(atPath: devPath) {
            return devPath
        }
        // HIGH-7: 不再走 PATH 回退。PATH 前段若有可写目录, 攻击者放入恶意 fusion-design,
        // app 以自身权限执行并把用户 prompt 经参数传入 -> prompt 外泄 + 任意代码执行。
        // 桌面 app 不应信任 PATH 查找接收敏感输入的可执行文件。找不到则报错不执行。
        designBridgeLog.error("DesignBridge: fusion-design CLI 未在 bundle 或开发目录找到, 拒绝 PATH 回退 (HIGH-7)")
        return ""
    }

    // MARK: - Unified CLI Bridge

    private var cachedCLIPath: String?

    func resolveCLIPath() -> String {
        if let cached = cachedCLIPath, !cached.isEmpty, FileManager.default.fileExists(atPath: cached) {
            return cached
        }
        let path = findFusionDesignCLI()
        cachedCLIPath = path
        return path
    }

    // 审计0830 P1-资源-3: nonisolated static CLI 执行器, 接收预解析 cliPath, 不读实例态。
    //   供 Task.detached 后台调用, 避开 runFusionDesign 的 MainActor 隔离 (依赖 resolveCLIPath 缓存态)。
    //   Process 阻塞调用 (可达 180s) 在后台线程跑, 不冻结 UI。逻辑镜像 runFusionDesign。
    nonisolated static func runCLIProcess(cliPath: String, args: [String], stdin: String? = nil) -> (output: String, error: String, exitCode: Int32) {
        guard !cliPath.isEmpty else {
            designBridgeLog.error("DesignBridge: runCLIProcess cliPath empty")
            return ("", "CLI not found", 1)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        if let stdinStr = stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            do {
                try process.run()
                if let data = stdinStr.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                    try? inPipe.fileHandleForWriting.close()
                }
            } catch {
                designBridgeLog.error("DesignBridge: CLI run failed: \(error)")
                return ("", error.localizedDescription, 1)
            }
        } else {
            do { try process.run() } catch {
                designBridgeLog.error("DesignBridge: CLI run failed: \(error)")
                return ("", error.localizedDescription, 1)
            }
        }
        var outData = Data()
        var errData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000_000)
            if process.isRunning {
                process.terminate()
                designBridgeLog.warning("DesignBridge: CLI timeout 180s, force terminate args=\(args.first ?? "", privacy: .public)")
            }
        }
        process.waitUntilExit()
        timeoutTask.cancel()
        readGroup.wait()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errorStr = String(data: errData, encoding: .utf8) ?? ""
        designBridgeLog.info("DesignBridge: CLI \(args.first ?? "") exit=\(process.terminationStatus) outLen=\(output.count)")
        return (output, errorStr, process.terminationStatus)
    }

    func runFusionDesignAsync(_ args: [String], stdin: String? = nil) async -> (output: String, error: String, exitCode: Int32) {
        let cliPath = resolveCLIPath()
        return await Task.detached(priority: .userInitiated) {
            Self.runCLIProcess(cliPath: cliPath, args: args, stdin: stdin)
        }.value
    }

    func runFusionDesign(_ args: [String], stdin: String? = nil) -> (output: String, error: String, exitCode: Int32) {
        let cliPath = resolveCLIPath()
        guard !cliPath.isEmpty else {
            designBridgeLog.error("DesignBridge: fusion-design CLI not found")
            return ("", "CLI not found", 1)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        if let stdinStr = stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            do {
                try process.run()
                if let data = stdinStr.data(using: .utf8) {
                    inPipe.fileHandleForWriting.write(data)
                    try? inPipe.fileHandleForWriting.close()
                }
            } catch {
                designBridgeLog.error("DesignBridge: CLI run failed: \(error)")
                return ("", error.localizedDescription, 1)
            }
        } else {
            do { try process.run() } catch {
                designBridgeLog.error("DesignBridge: CLI run failed: \(error)")
                return ("", error.localizedDescription, 1)
            }
        }
        var outData = Data()
        var errData = Data()
        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }
        // F-R1: 180s 超时兜底, 防 fusion-design LLM CLI 永挂 (并行 drain 已无死锁, 但 waitUntilExit 无超时可永挂)。
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 180_000_000_000)
            if process.isRunning {
                process.terminate()
                designBridgeLog.warning("DesignBridge: CLI timeout 180s, force terminate args=\(args.first ?? "", privacy: .public)")
            }
        }
        process.waitUntilExit()
        timeoutTask.cancel()
        readGroup.wait()
        let output = String(data: outData, encoding: .utf8) ?? ""
        let errorStr = String(data: errData, encoding: .utf8) ?? ""
        designBridgeLog.info("DesignBridge: CLI \(args.first ?? "") exit=\(process.terminationStatus) outLen=\(output.count)")
        return (output, errorStr, process.terminationStatus)
    }

    func runFusionDesignJSON(_ args: [String], stdin: String? = nil) -> Any? {
        let result = runFusionDesign(args, stdin: stdin)
        guard result.exitCode == 0, !result.output.isEmpty else { return nil }
        guard let data = result.output.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    func runFusionDesignStream(_ args: [String], onToken: @escaping (String) -> Void, onDone: @escaping (String) -> Void) {
        let cliPath = resolveCLIPath()
        guard !cliPath.isEmpty else {
            designBridgeLog.error("DesignBridge: fusion-design CLI not found for stream")
            onDone("")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard self != nil else { return }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = args
            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            // F-I13 pipefail 暴露: var fullOutput 被 readabilityHandler (非隔离逃逸闭包) 捕获并 mutation
            // = strict-concurrency error. 改引用类型 accumulator (常量引用, .value 可变, 非 captured-var mutation)。
            final class OutputAccumulator { var value: String = "" }
            let fullOutput = OutputAccumulator()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let chunk = String(data: data, encoding: .utf8) {
                    fullOutput.value += chunk
                    for line in chunk.components(separatedBy: "\n") {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard trimmed.hasPrefix("data: ") else { continue }
                        let payload = String(trimmed.dropFirst(6))
                        if payload == "[DONE]" { continue }
                        if let payloadData = payload.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let token = delta["content"] as? String {
                            DispatchQueue.main.async { onToken(token) }
                        }
                    }
                }
            }
            // F-R1: drain stderr 防 64KB 满阻塞写死锁 (旧实现 errPipe 从不读)。
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let errChunk = String(data: data, encoding: .utf8) {
                    designBridgeLog.warning("DesignBridge: CLI stream stderr: \(errChunk, privacy: .public)")
                }
            }
            do { try process.run() } catch {
                designBridgeLog.error("DesignBridge: CLI stream run failed: \(error)")
                DispatchQueue.main.async { onDone("") }
                return
            }
            // F-R1: 180s 超时兜底, 防 stream 永挂。
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: 180_000_000_000)
                if process.isRunning {
                    process.terminate()
                    designBridgeLog.warning("DesignBridge: CLI stream timeout 180s, force terminate args=\(args.first ?? "", privacy: .public)")
                }
            }
            process.waitUntilExit()
            timeoutTask.cancel()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = outPipe.fileHandleForReading.readDataToEndOfFile()
            if let tail = String(data: remaining, encoding: .utf8) { fullOutput.value += tail }
            designBridgeLog.info("DesignBridge: CLI stream \(args.first ?? "") exit=\(process.terminationStatus) len=\(fullOutput.value.count)")
            DispatchQueue.main.async { onDone(fullOutput.value) }
        }
    }

    // MARK: - Design Skills (CLI Bridge)


    func skillTextToUI(prompt: String, pageName: String = "Home") { skillState.skillTextToUI(prompt: prompt, pageName: pageName) }

    func skillImageToUI(imagePath: String, hint: String, pageName: String = "Home") { skillState.skillImageToUI(imagePath: imagePath, hint: hint, pageName: pageName) }

    func skillPartialEdit(nodesJSON: String, instruction: String) { skillState.skillPartialEdit(nodesJSON: nodesJSON, instruction: instruction) }

    func skillSimPanel(prompt: String, pageName: String = "Home") { skillState.skillSimPanel(prompt: prompt, pageName: pageName) }

    func skillSpecDoc(prompt: String) { skillState.skillSpecDoc(prompt: prompt) }

    func skillPageFlow(prompt: String, pageNames: [String]? = nil) { skillState.skillPageFlow(prompt: prompt, pageNames: pageNames) }

    func skillMultiVariants(prompt: String, styles: [String]? = nil, pageName: String = "Home") { skillState.skillMultiVariants(prompt: prompt, styles: styles, pageName: pageName) }

    func skillLint(documentJSON: String? = nil, designSystem: String = "apple-hig", fix: Bool = false, dryRun: Bool = false) -> [DesignLintIssue] { skillState.skillLint(documentJSON: documentJSON, designSystem: designSystem, fix: fix, dryRun: dryRun) }

    func skillDiff(oldJSON: String, newJSON: String) -> [DesignDiffEntry] { skillState.skillDiff(oldJSON: oldJSON, newJSON: newJSON) }

    func skillHealthCheck(endpoint: String = FusionConfig.shared.mlxBaseURL) -> [String: Any]? { skillState.skillHealthCheck(endpoint: endpoint) }

    func skillTheme(designSystem: String = "apple-hig", mode: String = "dark") -> String? { skillState.skillTheme(designSystem: designSystem, mode: mode) }

    private func parseHtmlFromPenOutput(_ output: String) -> String? { chatState.parseHtmlFromPenOutput(output) }


    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        self.artifactState.ipcClient = client
        self.versionState.ipcClient = client
        self.fileSyncState.ipcClient = client
        designBridgeLog.info("DesignBridge: IPCClient injected into 3 域 (artifact/version/fileSync, ARCH-1)")
    }

    // MARK: - Panel Convenience Methods

    func applyDesignTokensToCanvas(systemId: String) async {
        let cliPath = resolveCLIPath()
        let result = await Task.detached(priority: .userInitiated) {
            Self.runCLIProcess(cliPath: cliPath, args: ["token-css", "--design-system", systemId])
        }.value
        if result.exitCode == 0, !result.output.isEmpty {
            applyDesignTokensToCanvas(result.output)
            designBridgeLog.info("DesignBridge: applied tokens for system=\(systemId)")
        } else {
            designBridgeLog.error("DesignBridge: token-css CLI failed: \(result.error)")
        }
    }

    func loadDocumentJSON(_ json: String) { pageState.loadDocumentJSON(json) }

    func mutateNode(nodeId: String, fill: String? = nil, stroke: String? = nil) {
        pageState.mutateNode(nodeId: nodeId, fill: fill, stroke: stroke)
    }

    // MARK: - Send Design Chat

    func sendDesignChat(_ userMessage: String) async {
        DesignPreviewTrace.log("sendDesignChat: ENTER msgLen=\(userMessage.count)")
        guard !userMessage.isEmpty else {
            DesignPreviewTrace.log("sendDesignChat: empty message, return")
            return
        }

        let userMsg = DesignMessage(role: "user", content: userMessage, timestamp: Date())
        messages.append(userMsg)
        chatState.capMessages()
        isGenerating = true
        artifactSaved = false
        errorMessage = nil
        chatState.parseState = .idle
        chatState.parseBuffer = ""
        chatState.rawAssistantContent = ""
        inferenceStep = "connecting"
        streamTokenCount = 0
        streamPreviewText = ""

        var systemPrompt = DesignPrompts.dispatcher.systemPrompt
        if !currentArtifactCode.isEmpty {
            systemPrompt += DesignPrompts.dispatcher.sendDesignChatArtifactAppend(currentArtifactCode)
        }

        DesignPreviewTrace.log("sendDesignChat: before fetchRAGContext")
        let ragEnabled = false
        let ragContext: String? = ragEnabled ? await fetchRAGContextBounded(for: userMessage, timeoutSeconds: 5) : nil
        DesignPreviewTrace.log("sendDesignChat: fetchRAGContext done ragEnabled=\(ragEnabled) nil=\(ragContext == nil)")
        if let rag = ragContext, !rag.isEmpty {
            systemPrompt += DesignPrompts.dispatcher.sendDesignChatRagAppend(rag)
            designBridgeLog.info("DesignBridge: injected RAG context (\(rag.count) chars)")
            DesignPreviewTrace.log("sendDesignChat: RAG context injected len=\(rag.count)")
        }

        var chatMessages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for msg in messages where msg.role != "system" {
            chatMessages.append(["role": msg.role, "content": msg.content])
        }

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        var apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL: \(baseURL)"
            isGenerating = false
            return
        }

        var body: [String: Any] = [
            "messages": chatMessages,
            "temperature": 0.7,
            // 完整设计页 (HTML+CSS+JS) 常超 8192 tokens, 8192 时 mlx finish_reason=length 截断
            // 无 </antArtifact> 闭合 → 提取到 partial code (JS 被砍在 submit handler 中段).
            // 提至 16384 给完整页面余地; 仍超时由下方 finish_reason=length 检测显式告警, 不静默.
            "max_tokens": 16384,
            "stream": true,
        ]
        let model = selectedModel.isEmpty ? config.defaultModel(for: .code) : selectedModel
        if model.isEmpty {
            // 无默认对话模型：MLX 会 400 "model: Field required"，提前给出明确错误并复位状态
            errorMessage = I18nManager.shared.t(.design_errNoModel)
            isGenerating = false
            designBridgeLog.error("sendDesignChat: aborted, no model selected (selectedModel & defaultModel both empty)")
            return
        }
        body["model"] = model
        DesignPreviewTrace.log("sendDesignChat: request built, model=\(model) baseURL=\(baseURL) msgCount=\(chatMessages.count)")

        guard let requestData = try? JSONSerialization.data(withJSONObject: body) else {
            errorMessage = "Failed to encode request"
            isGenerating = false
            return
        }

        func buildRequest(key: String) -> URLRequest {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.httpBody = requestData
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            req.setValue("studio", forHTTPHeaderField: "X-Fusion-Route")
            req.timeoutInterval = 300
            if !key.isEmpty {
                req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            }
            return req
        }

        var request = buildRequest(key: apiKey)

        do {
            var (bytes, response) = try await URLSession.shared.bytes(for: request)
            var httpResp = response as? HTTPURLResponse
            if httpResp?.statusCode == 401 || httpResp?.statusCode == 403 {
                if let fallback = await AgentBridge.mlxSettingsJsonApiKey(), !fallback.isEmpty, fallback != apiKey {
                    designBridgeLog.warning("sendDesignChat: auth failed (HTTP \(httpResp?.statusCode ?? 0)), retrying with settings.json key")
                    DesignPreviewTrace.log("sendDesignChat: auth retry with settings.json key")
                    apiKey = fallback
                    request = buildRequest(key: apiKey)
                    ;(bytes, response) = try await URLSession.shared.bytes(for: request)
                    httpResp = response as? HTTPURLResponse
                }
            }
            guard let httpResp, httpResp.statusCode == 200 else {
                throw NSError(domain: "DesignBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "MLX streaming returned non-200 (status=\(httpResp?.statusCode ?? -1))"])
            }

            inferenceStep = "generating"
            var assistantContent = ""
            var streamFinishReason: String?
            DesignPreviewTrace.log("sendDesignChat: stream connected, status=\(httpResp.statusCode) model=\(model)")
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let payload = String(line.dropFirst(6))
                if payload == "[DONE]" { break }

                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let firstChoice = choices.first else {
                    continue
                }
                // finish chunk: delta 无 content, 旧 guard 直接 continue 丢弃 finish_reason,
                // 导致 max_tokens 截断 (finish_reason="length") 被静默. 先捕获再处理 content.
                if let fr = firstChoice["finish_reason"] as? String, !fr.isEmpty {
                    streamFinishReason = fr
                }
                guard let delta = firstChoice["delta"] as? [String: Any],
                      let token = delta["content"] as? String, !token.isEmpty else {
                    continue
                }

                assistantContent += token
                chatState.rawAssistantContent += token
                chatState.processStreamToken(token)

                streamTokenCount += 1
                let previewBase = assistantContent.suffix(120)
                streamPreviewText = String(previewBase)
                if streamTokenCount == 1 {
                    inferenceStep = "streaming"
                }
            }

            let finalArtifact = extractArtifactFromComplete(chatState.rawAssistantContent)
            DesignPreviewTrace.log("sendDesignChat: stream loop done, rawLen=\(chatState.rawAssistantContent.count) tokens=\(streamTokenCount) hasAnt=\(chatState.rawAssistantContent.contains("<antArtifact")) finalArtifact=\(finalArtifact != nil)")
            let assistantMsg = DesignMessage(
                role: "assistant",
                content: assistantContent,
                timestamp: Date(),
                artifactInfo: finalArtifact
            )
            messages.append(assistantMsg)
            chatState.capMessages()

            if finalArtifact != nil {
                designBridgeLog.info("DesignBridge: artifact parsed — type=\(self.currentArtifactType), title=\(self.currentArtifactTitle), \(self.currentArtifactCode.count) chars")
                DesignPreviewTrace.log("sendDesignChat: finalArtifact set, codeLen=\(self.currentArtifactCode.count)")
            } else {
                let extractedCode = extractCodeBlock(from: chatState.rawAssistantContent)
                if !extractedCode.isEmpty {
                    currentArtifactCode = extractedCode
                    if currentArtifactTitle.isEmpty { currentArtifactTitle = "Design" }
                    if currentArtifactType.isEmpty { currentArtifactType = "html" }
                    designBridgeLog.info("DesignBridge: code block extracted, \(extractedCode.count) chars")
                    DesignPreviewTrace.log("sendDesignChat: codeBlock fallback, len=\(extractedCode.count)")
                } else {
                    DesignPreviewTrace.log("sendDesignChat: NO artifact extracted, rawLen=\(chatState.rawAssistantContent.count) hasAnt=\(chatState.rawAssistantContent.contains("<antArtifact")) hasFence=\(chatState.rawAssistantContent.contains("```html"))")
                }
            }

            // AI artifact 完成 → 解析为 PenDocument 并暂存，供切到 canvas 时回放渲染
            if !currentArtifactCode.isEmpty {
                inferenceStep = "rendering"
                await renderArtifactToCanvas()
                DesignPreviewTrace.log("sendDesignChat: renderArtifactToCanvas done, docJSON.len=\(self.lastRenderedDocumentJSON?.count ?? 0) canvasWebViewNotNil=\(self.canvasWebView != nil)")
            }

            // finish_reason=length: mlx 在 max_tokens 处截断, 无 </antArtifact> 闭合 → 代码不完整.
            // 不阻断已渲染的 partial artifact, 仅 orange warning 提示用户简化/分步重试 (Rule 12 fail visibly).
            if streamFinishReason == "length" {
                errorMessage = I18nManager.shared.t(.design_warnTruncated)
                designBridgeLog.warning("DesignBridge: stream truncated by max_tokens (finish_reason=length), partial code \(self.currentArtifactCode.count) chars")
                DesignPreviewTrace.log("sendDesignChat: TRUNCATED by length, rawLen=\(chatState.rawAssistantContent.count) tokens=\(streamTokenCount)")
            }

        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge sendDesignChat: \(error)")
            DesignPreviewTrace.log("sendDesignChat CAUGHT: \(error.localizedDescription) rawLen=\(chatState.rawAssistantContent.count) tokens=\(streamTokenCount)")
        }

        isGenerating = false
        inferenceStep = ""
        streamTokenCount = 0
        streamPreviewText = ""
    }

    // MARK: - Stream Token Parsing (antArtifact XML) — Phase 2 迁 DesignChatService

    private func processStreamToken(_ token: String) { chatState.processStreamToken(token) }


    // MARK: - Post-hoc Artifact Extraction — Phase 2 迁 DesignChatService

    func extractArtifactFromComplete(_ content: String) -> ArtifactParseResult? { chatState.extractArtifactFromComplete(content) }

    func extractCodeBlock(from content: String) -> String { chatState.extractCodeBlock(from: content) }

    // MARK: - Save Artifact

    func saveAsArtifact() async { await artifactState.saveAsArtifact() }

    func kindForType(_ type: String) -> String { artifactState.kindForType(type) }

    // MARK: - Utility

    func memoryCheckMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    func clearConversation() {
        messages = []
        currentArtifactCode = ""
        currentArtifactTitle = ""
        currentArtifactType = "html"
        artifactSaved = false
        artifactId = ""
        versionHistory = []
        pages = []
        currentPageIndex = -1
        errorMessage = nil
        chatState.parseState = .idle
        chatState.parseBuffer = ""
        chatState.rawAssistantContent = ""
        artifactState.sessionId = "design-\(UUID().uuidString.prefix(8))"
        inferenceStep = ""
        streamTokenCount = 0
        streamPreviewText = ""
    }

    // MARK: - Multi-Page Management

    func addPage() { pageState.addPage() }

    func deletePage(at index: Int) { pageState.deletePage(at: index) }

    func switchToPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pageState.saveCurrentPageState()
        currentPageIndex = index
        let page = pages[index]
        currentArtifactCode = page.code
        currentArtifactTitle = page.title
        currentArtifactType = page.type
        artifactId = page.artifactId
        versionHistory = []
        designBridgeLog.info("DesignBridge: switched to page '\(page.title)' at \(index)")
    }

    func renamePage(at index: Int, newTitle: String) { pageState.renamePage(at: index, newTitle: newTitle) }

    func saveCurrentPageState() { pageState.saveCurrentPageState() }

    // MARK: - Version History

    // ARCH-1 Phase 7: 行为迁 DesignVersionService。rollbackToVersion 留本类 (跨域协调器)。
    func loadVersionHistory() async { await versionState.loadVersionHistory() }

    func rollbackToVersion(_ targetVersion: Int) async {
        guard !artifactId.isEmpty, let ipc = ipcClient else { return }
        do {
            _ = try await ipc.artifactVersionRollback(artifactId: artifactId, targetVersion: targetVersion)
            let contentResult = try await ipc.artifactGetContent(artifactId: artifactId)
            if let content = contentResult["content"] as? String {
                currentArtifactCode = content
                artifactSaved = false
            }
            designBridgeLog.info("DesignBridge: rolled back to version \(targetVersion)")
            await loadVersionHistory()
        } catch {
            errorMessage = "Rollback failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge rollbackToVersion: \(error)")
        }
    }


    // ARCH-1 Phase 7: 行为迁 DesignVersionService。
    func diffVersions(oldJSON: String, newJSON: String) { versionState.diffVersions(oldJSON: oldJSON, newJSON: newJSON) }


    // ARCH-1 Phase 7: 行为迁 DesignThemeService。
    func switchTheme(_ mode: String) { themeState.switchTheme(mode) }

    func switchDesignSystem(_ systemId: String) { themeState.switchDesignSystem(systemId) }

    // ARCH-1 Phase 8: 行为迁 DesignExportService。
    func copyCurrentCode() { exportState.copyCurrentCode() }

    // MARK: - Design RAG

    func fetchRAGContextBounded(for query: String, timeoutSeconds: UInt64) async -> String? {
        guard let ipc = ipcClient else { return nil }
        return await Self.ragContextWithTimeout(ipc: ipc, query: query, timeoutSeconds: timeoutSeconds)
    }

    nonisolated static func ragContextWithTimeout(ipc: IPCClient, query: String, timeoutSeconds: UInt64) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await fetchRAGContextStatic(ipc: ipc, query: query) }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first ?? nil
        }
    }

    nonisolated static func fetchRAGContextStatic(ipc: IPCClient, query: String) async -> String? {
        do {
            let result = try await ipc.knowledgeSearch(query: query, limit: 3)
            if let entries = result["results"] as? [[String: Any]] {
                let chunks = entries.compactMap { $0["content"] as? String }
                if chunks.isEmpty { return nil }
                return chunks.joined(separator: "\n---\n")
            }
        } catch {
            DesignPreviewTrace.log("DesignBridge RAG search failed: \(error)")
        }
        return nil
    }

    // ARCH-1 Phase 7: 行为迁 DesignThemeService。
    func ingestDesignTokens() async { await themeState.ingestDesignTokens() }

    // MARK: - SwiftUI Export


    // MARK: - SwiftUI Export

    // ARCH-1 Phase 8: 行为迁 DesignExportService。
    func exportAsSwiftUI() async { await exportState.exportAsSwiftUI() }

    func copyExportedSwiftUI() { exportState.copyExportedSwiftUI() }

    // MARK: - Codegen Export (HTML/React/Tailwind via CLI)

    func exportAsCodegen(target: String, componentName: String) async { await exportState.exportAsCodegen(target: target, componentName: componentName) }

    func copyExportedCodegen() { exportState.copyExportedCodegen() }

    // MARK: - Batch Export (SVG/HTML/JSON via CLI)

    func batchExportPages(format: String, to outputDir: String) async { await exportState.batchExportPages(format: format, to: outputDir) }

    // MARK: - Artifact ↔ File Sync

    // ARCH-1 Phase 8: 行为迁 DesignFileSyncService。
    func enableFileSync(to folderPath: String) { fileSyncState.enableFileSync(to: folderPath) }

    func disableFileSync() { fileSyncState.disableFileSync() }

    func syncArtifactToFile() async { await fileSyncState.syncArtifactToFile() }

    func syncFileToArtifact() async { await fileSyncState.syncFileToArtifact() }

    func sanitizeFileName(_ name: String) -> String { artifactState.sanitizeFileName(name) }
    func importScreenshot(_ image: NSImage) async { await artifactState.importScreenshot(image) }
    // designHealth/isDesignHealthy @Published 同删 (0 读)。

}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
