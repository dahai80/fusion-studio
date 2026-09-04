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

private enum ArtifactParseState {
    case idle
    case inOpenTag
    case inCode
    case inCloseTag
}

@MainActor
class DesignBridge: ObservableObject {
    @Published var messages: [DesignMessage] = []
    // PERF-4 (审计product-0905 P2): messages 无界 @Published, 长会话内存涨。LRU cap。
    static let maxMessages = 200
    private func capMessages() {
        guard messages.count > Self.maxMessages else { return }
        let drop = messages.count - Self.maxMessages
        messages.removeFirst(drop)
        designBridgeLog.info("DesignBridge capMessages: drop \(drop) oldest (count > \(Self.maxMessages))")
    }
    @Published var currentArtifactCode: String = ""
    @Published var currentArtifactType: String = "html"
    @Published var currentArtifactTitle: String = ""
    @Published var isGenerating: Bool = false
    @Published var artifactSaved: Bool = false

    // MARK: - Inference Progress
    @Published var inferenceStep: String = ""
    @Published var streamTokenCount: Int = 0
    @Published var streamPreviewText: String = ""
    @Published var errorMessage: String?
    @Published var artifactId: String = ""
    @Published var selectedModel: String = ""
    @Published var versionHistory: [[String: Any]] = []
    @Published var isLoadingHistory: Bool = false
    @Published var pages: [DesignPage] = []
    @Published var currentPageIndex: Int = -1

    // Callers: DesignCanvasView (wasm bridge), DesignView (canvas mode).
    // Affected API: selectedNodeID Published, canvasWebView weak ref, sendCanvasCommand().
    // Data schemas: BridgeCommand JSON via evaluateJavaScript.
    // User instruction: "现在开始实施" — Task #5

    @Published var selectedNodeID: String?
    @Published var lastRenderedDocumentJSON: String?
    @Published var marqueeSelectedNodeIDs: [String] = []

    // MARK: - Plan Preview State
    @Published var pendingPlanCode: String?
    @Published var isPlanPreviewActive: Bool = false
    @Published var pendingPlanTitle: String = ""

    private var parseState: ArtifactParseState = .idle
    private var parseBuffer: String = ""
    private var currentIdentifier: String = ""
    private var rawAssistantContent: String = ""
    private var ipcClient: IPCClient?
    private var sessionId: String = "design-\(UUID().uuidString.prefix(8))"
    weak var canvasWebView: WKWebView?
    private var codeWatchTimer: Timer?

    // MARK: - Canvas Bridge Commands

    func sendCanvasCommand(_ command: BridgeCommand) {
        guard let webView = canvasWebView else {
            designBridgeLog.warning("DesignBridge: canvasWebView nil, command dropped")
            return
        }
        DesignCanvasView.sendCommand(command, to: webView)
    }

    // #372 OPS-13: 触发 fd-host-web 日志环形缓冲 dump。
    // 走 window.postMessage({kind:'log.capture.dump',...}) 通道 (非 BridgeCommand, 上游 bridge.rs:187)。
    // 触发源: DesignLintPanel 手动按钮 / WebView 进程崩溃恢复 / App 进入前台 (节流)。
    func dumpWasmLog(clear: Bool) {
        guard let webView = canvasWebView else {
            designBridgeLog.warning("DesignBridge: dumpWasmLog skipped, canvasWebView nil")
            return
        }
        DesignCanvasView.requestLogDump(to: webView, clear: clear)
    }

    func applyDesignTokensToCanvas(_ css: String) {
        sendCanvasCommand(.applyTokens(css: css))
    }

    func renderDocumentToCanvas(_ documentJSON: String) {
        lastRenderedDocumentJSON = documentJSON
        sendCanvasCommand(.pageRender(documentJSON: documentJSON))
    }

    func clearCanvas() {
        sendCanvasCommand(.clearCanvas)
    }

    func selectCanvasNode(_ nodeID: String) {
        selectedNodeID = nodeID
        sendCanvasCommand(.selectNode(nodeID: nodeID))
    }

    func mutateCanvasNode(_ nodeID: String, x: Float?, y: Float?, w: Float?, h: Float?,
                          fill: String? = nil, stroke: String? = nil, strokeWidth: Float? = nil,
                          radius: Float? = nil, fontSize: Float? = nil, fontFamily: String? = nil,
                          opacity: Float? = nil) {
        sendCanvasCommand(.mutateNode(nodeID: nodeID, x: x, y: y, w: w, h: h,
                                       fill: fill, stroke: stroke, strokeWidth: strokeWidth,
                                       radius: radius, fontSize: fontSize, fontFamily: fontFamily,
                                       opacity: opacity))
        designBridgeLog.info("DesignBridge: mutateCanvasNode id=\(nodeID) w=\(w?.description ?? "nil") h=\(h?.description ?? "nil")")
    }

    func setNodeLocked(_ nodeID: String, locked: Bool) {
        sendCanvasCommand(.mutateNode(nodeID: nodeID, x: nil, y: nil, w: nil, h: nil,
                                       fill: nil, stroke: nil, strokeWidth: nil, radius: nil,
                                       fontSize: nil, fontFamily: nil, opacity: locked ? 0.3 : 1.0))
        designBridgeLog.info("DesignBridge: set node \(nodeID) locked=\(locked)")
    }

    func undo() {
        sendCanvasCommand(.undoAction)
        designBridgeLog.info("DesignBridge: undo")
    }

    func redo() {
        sendCanvasCommand(.redoAction)
        designBridgeLog.info("DesignBridge: redo")
    }

    func setNodeVisibility(_ nodeID: String, visible: Bool) {
        sendCanvasCommand(.setNodeVisibility(nodeID: nodeID, visible: visible))
        designBridgeLog.info("DesignBridge: setNodeVisibility id=\(nodeID) visible=\(visible)")
    }

    func reorderNode(_ nodeID: String, newIndex: Int) {
        sendCanvasCommand(.reorderNode(nodeID: nodeID, newIndex: newIndex))
        designBridgeLog.info("DesignBridge: reorderNode id=\(nodeID) newIndex=\(newIndex)")
    }

    func deleteNode(_ nodeID: String) {
        guard let docJSON = lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        guard let data = docJSON.data(using: .utf8),
              var doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var pages = doc["pages"] as? [[String: Any]] else { return }
        for i in pages.indices {
            guard var nodes = pages[i]["nodes"] as? [[String: Any]] else { continue }
            let before = nodes.count
            nodes.removeAll { ($0["id"] as? String) == nodeID }
            if nodes.count < before {
                pages[i]["nodes"] = nodes
                doc["pages"] = pages
                if let updated = try? JSONSerialization.data(withJSONObject: doc, options: .prettyPrinted),
                   let str = String(data: updated, encoding: .utf8) {
                    renderDocumentToCanvas(str)
                    selectedNodeID = nil
                    designBridgeLog.info("DesignBridge: deleted node \(nodeID)")
                }
                return
            }
        }
        designBridgeLog.warning("DesignBridge: deleteNode — node \(nodeID) not found")
    }

    func duplicateNode(_ nodeID: String) {
        guard let docJSON = lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        guard let data = docJSON.data(using: .utf8),
              var doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var pages = doc["pages"] as? [[String: Any]] else { return }
        for i in pages.indices {
            guard var nodes = pages[i]["nodes"] as? [[String: Any]] else { continue }
            if let idx = nodes.firstIndex(where: { ($0["id"] as? String) == nodeID }),
               var copy = nodes[idx] as? [String: Any] {
                let newID = nodeID + "_copy_\(Int.random(in: 1000...9999))"
                copy["id"] = newID
                if var style = copy["style"] as? [String: Any] {
                    style["x"] = ((style["x"] as? Double) ?? 0) + 20
                    style["y"] = ((style["y"] as? Double) ?? 0) + 20
                    copy["style"] = style
                }
                nodes.insert(copy, at: idx + 1)
                pages[i]["nodes"] = nodes
                doc["pages"] = pages
                if let updated = try? JSONSerialization.data(withJSONObject: doc, options: .prettyPrinted),
                   let str = String(data: updated, encoding: .utf8) {
                    renderDocumentToCanvas(str)
                    selectedNodeID = newID
                    designBridgeLog.info("DesignBridge: duplicated node \(nodeID) → \(newID)")
                }
                return
            }
        }
    }

    func bringToFront(_ nodeID: String) {
        guard let docJSON = lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        guard let data = docJSON.data(using: .utf8),
              var doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var pages = doc["pages"] as? [[String: Any]] else { return }
        for i in pages.indices {
            guard var nodes = pages[i]["nodes"] as? [[String: Any]] else { continue }
            if let idx = nodes.firstIndex(where: { ($0["id"] as? String) == nodeID }) {
                let node = nodes.remove(at: idx)
                nodes.append(node)
                pages[i]["nodes"] = nodes
                doc["pages"] = pages
                if let updated = try? JSONSerialization.data(withJSONObject: doc, options: .prettyPrinted),
                   let str = String(data: updated, encoding: .utf8) {
                    renderDocumentToCanvas(str)
                    designBridgeLog.info("DesignBridge: bringToFront node \(nodeID)")
                }
                return
            }
        }
    }

    func sendToBack(_ nodeID: String) {
        guard let docJSON = lastRenderedDocumentJSON, !docJSON.isEmpty else { return }
        guard let data = docJSON.data(using: .utf8),
              var doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var pages = doc["pages"] as? [[String: Any]] else { return }
        for i in pages.indices {
            guard var nodes = pages[i]["nodes"] as? [[String: Any]] else { continue }
            if let idx = nodes.firstIndex(where: { ($0["id"] as? String) == nodeID }) {
                let node = nodes.remove(at: idx)
                nodes.insert(node, at: 0)
                pages[i]["nodes"] = nodes
                doc["pages"] = pages
                if let updated = try? JSONSerialization.data(withJSONObject: doc, options: .prettyPrinted),
                   let str = String(data: updated, encoding: .utf8) {
                    renderDocumentToCanvas(str)
                    designBridgeLog.info("DesignBridge: sendToBack node \(nodeID)")
                }
                return
            }
        }
    }

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
                effectiveNodesJSON = extractSelectedNodesJSON()
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
                    applyPartialEditResult(result.output)
                } else {
                    await sendDesignChat(instruction)
                }
            } else {
                designBridgeLog.info("DesignBridge: local-edit CLI unavailable, falling back to MLX chat")
                await sendDesignChat(instruction)
            }
        }
    }

    private func extractSelectedNodesJSON() -> String {
        guard let docJSON = lastRenderedDocumentJSON,
              !docJSON.isEmpty,
              !marqueeSelectedNodeIDs.isEmpty else { return "[]" }
        guard let data = docJSON.data(using: .utf8),
              let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pages = doc["pages"] as? [[String: Any]] else { return "[]" }
        var selected: [[String: Any]] = []
        let ids = Set(marqueeSelectedNodeIDs)
        for page in pages {
            guard let nodes = page["nodes"] as? [[String: Any]] else { continue }
            for node in nodes {
                if let id = node["id"] as? String, ids.contains(id) {
                    selected.append(node)
                }
            }
        }
        if let data = try? JSONSerialization.data(withJSONObject: selected, options: .prettyPrinted) {
            return String(data: data, encoding: .utf8) ?? "[]"
        }
        return "[]"
    }

    private func applyPartialEditResult(_ resultJSON: String) {
        guard let data = resultJSON.data(using: .utf8),
              let nodes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            designBridgeLog.error("DesignBridge: applyPartialEditResult invalid JSON")
            return
        }
        for node in nodes {
            guard let nodeID = node["id"] as? String else { continue }
            let x = node["x"] as? Float
            let y = node["y"] as? Float
            let w = node["w"] as? Float
            let h = node["h"] as? Float
            let fill = node["fill"] as? String
            let stroke = node["stroke"] as? String
            let radius = node["radius"] as? Float
            let opacity = node["opacity"] as? Float
            mutateCanvasNode(nodeID, x: x, y: y, w: w, h: h,
                             fill: fill, stroke: stroke, radius: radius, opacity: opacity)
        }
        designBridgeLog.info("DesignBridge: applied partial edit to \(nodes.count) nodes")
    }

    private var mutateObserver: NSObjectProtocol?

    func startObservingInspectorChanges() {
        guard mutateObserver == nil else { return }
        mutateObserver = NotificationCenter.default.addObserver(
            forName: .designInspectorMutateNode,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            let userInfo = notification.userInfo ?? [:]
            guard let nodeID = userInfo["node_id"] as? String else { return }
            let w = userInfo["w"] as? Float
            let h = userInfo["h"] as? Float
            let fill = userInfo["fill"] as? String
            let stroke = userInfo["stroke"] as? String
            let strokeWidth = userInfo["stroke_width"] as? Float
            let radius = userInfo["radius"] as? Float
            let fontSize = userInfo["font_size"] as? Float
            let fontFamily = userInfo["font_family"] as? String
            let opacity = userInfo["opacity"] as? Float
            self.mutateCanvasNode(nodeID, x: nil, y: nil, w: w, h: h,
                                   fill: fill, stroke: stroke, strokeWidth: strokeWidth,
                                   radius: radius, fontSize: fontSize, fontFamily: fontFamily,
                                   opacity: opacity)
        }
        designBridgeLog.info("DesignBridge: started observing inspector changes")
    }

    deinit {
        if let obs = mutateObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        codeWatchTimer?.invalidate()
    }

    // MARK: - Reverse Code Watch (Fusion Code → Canvas)

    /// 启动反向监听：每 3 秒扫描 fusion-code IPC 目录的 style-change 消息。
    func startWatchingCodeChanges() {
        guard codeWatchTimer == nil else { return }
        codeWatchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollCodeChanges()
        }
        designBridgeLog.info("DesignBridge: code watch started (3s interval)")
    }

    func stopWatchingCodeChanges() {
        codeWatchTimer?.invalidate()
        codeWatchTimer = nil
        designBridgeLog.info("DesignBridge: code watch stopped")
    }

    private func pollCodeChanges() {
        let ipcBase = NSHomeDirectory() + "/.fusion-ipc"
        let dir = ipcBase + "/fusion-code"
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir).sorted() else { return }

        for name in files {
            let path = dir + "/" + name
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let action = json["action"] as? String,
                  action == "style-change" else {
                continue
            }
            // 消费：读后删除
            try? fm.removeItem(atPath: path)

            guard let payload = json["payload"] as? [String: Any],
                  let mutations = payload["mutations"] as? [[String: Any]] else {
                designBridgeLog.warning("DesignBridge: style-change payload missing mutations")
                continue
            }
            designBridgeLog.info("DesignBridge: applying \(mutations.count) reverse mutations")
            for m in mutations {
                guard let nodeID = m["node_id"] as? String else { continue }
                mutateCanvasNode(
                    nodeID,
                    x: m["x"] as? Float,
                    y: m["y"] as? Float,
                    w: m["w"] as? Float,
                    h: m["h"] as? Float,
                    fill: m["fill"] as? String,
                    stroke: m["stroke"] as? String,
                    strokeWidth: nil,
                    radius: m["radius"] as? Float,
                    fontSize: nil,
                    fontFamily: nil,
                    opacity: m["opacity"] as? Float
                )
            }
        }
    }

    // MARK: - AI Artifact → Canvas Rendering

    /// AI artifact 完成后：HTML→PenDocument→Plan Preview + Token CSS 注入。
    /// 预览模式下先暂存，用户确认后才写入画布。
    private func renderArtifactToCanvas() async {
        // 1. HTML → PenDocument JSON via CLI
        guard let penDocJSON = parseHtmlViaCLI(currentArtifactCode) else {
            designBridgeLog.warning("DesignBridge: parseHtmlViaCLI failed, skipping canvas render")
            return
        }
        // 2. 注入设计 Token CSS
        if let tokenCSS = fetchTokenCSSViaCLI() {
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

    /// 确认 Plan：将暂存的 PenDocument 写入画布。
    func acceptPlan() {
        guard let code = pendingPlanCode else { return }
        renderDocumentToCanvas(code)
        pendingPlanCode = nil
        isPlanPreviewActive = false
        sendCanvasCommand(.planApply)
        designBridgeLog.info("DesignBridge: Plan accepted and rendered to canvas")
    }

    /// 拒绝 Plan：清除预览，恢复画布状态。
    func rejectPlan() {
        pendingPlanCode = nil
        isPlanPreviewActive = false
        sendCanvasCommand(.planReject)
        designBridgeLog.info("DesignBridge: Plan rejected, preview cleared")
    }

    /// 调用 fusion-design parse-html CLI 将 HTML 转为 PenDocument JSON。
    func parseHtmlViaCLI(_ html: String) -> String? {
        // HIGH-6: currentArtifactCode 来自 LLM 不可信输出, 可被 prompt 注入操纵 emit 含
        // <script> 的 HTML。送 CLI 解析 + 后续 wasm 渲染 = XSS 等价, 可调原生 bridge 读本地资源。
        // 渲染前净化 (纵深防御, 与 CLI 解析侧校验正交): 剥 <script>/<iframe>/<object>/<embed>,
        // 剥 on* 事件处理器属性, 剥 javascript:/vbscript: URL, 净化 <style> 内 CSS XSS 向量。
        // <style> 块本体保留 (合法 :root 设计 token + 自定义 class), 仅剥 expression/url-js/@import。
        let safe = Self.sanitizeHtml(html)
        let result = runFusionDesign(
            ["parse-html", "--page", currentArtifactTitle.isEmpty ? "Page" : currentArtifactTitle],
            stdin: safe
        )
        guard result.exitCode == 0 else {
            designBridgeLog.warning("DesignBridge: parse-html failed: \(result.error)")
            return nil
        }
        return result.output.isEmpty ? nil : result.output
    }

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
    private func fetchTokenCSSViaCLI() -> String? {
        let result = runFusionDesign(["token-css", "--design-system", "apple-hig"])
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

    private func resolveCLIPath() -> String {
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

    @Published var lastSkillOutput: String = ""
    @Published var isSkillRunning: Bool = false

    func skillTextToUI(prompt: String, pageName: String = "Home") {
        isSkillRunning = true
        let config = FusionConfig.shared
        let args = [
            "generate",
            "--prompt", prompt,
            "--page", pageName,
            "--model", config.defaultModel(for: .artifacts),
            "--endpoint", config.mlxBaseURL
        ]
        let result = runFusionDesign(args)
        if result.exitCode == 0 {
            lastSkillOutput = result.output
            if let penDocJSON = result.output.data(using: String.Encoding.utf8),
               let penDoc = try? JSONSerialization.jsonObject(with: penDocJSON) as? [String: Any],
               let pages = penDoc["pages"] as? [[String: Any]] {
                renderDocumentToCanvas(result.output)
                designBridgeLog.info("DesignBridge: text_to_ui rendered, \(result.output.count) chars")
            } else {
                designBridgeLog.warning("DesignBridge: text_to_ui output not valid PenDocument, falling back to parse-html")
                if let html = try? parseHtmlFromPenOutput(result.output) {
                    if let docJSON = parseHtmlViaCLI(html) {
                        renderDocumentToCanvas(docJSON)
                    }
                }
            }
        } else {
            designBridgeLog.error("DesignBridge: text_to_ui failed: \(result.error)")
        }
        isSkillRunning = false
    }

    func skillImageToUI(imagePath: String, hint: String, pageName: String = "Home") {
        isSkillRunning = true
        let prompt = DesignPrompts.dispatcher.skillImageToUIPrompt(imagePath, hint, pageName)
        let config = FusionConfig.shared
        let args = [
            "generate",
            "--prompt", prompt,
            "--page", pageName,
            "--model", config.defaultModel(for: .artifacts),
            "--endpoint", config.mlxBaseURL
        ]
        let result = runFusionDesign(args)
        if result.exitCode == 0 {
            lastSkillOutput = result.output
            renderDocumentToCanvas(result.output)
            designBridgeLog.info("DesignBridge: image_to_ui rendered")
        } else {
            designBridgeLog.error("DesignBridge: image_to_ui failed: \(result.error)")
        }
        isSkillRunning = false
    }

    // Callers: DesignChatPanel.handleSkillTemplate (partial_edit/sim_panel/spec_doc/page_flow).
    // Affected API: 4 new skill methods bridging to generate CLI with structured prompts.
    // Data schemas: generate --prompt/--page/--model/--endpoint, PenDocument output → renderDocumentToCanvas.
    // User instruction: "Phase 6 功能增强,立即实施"

    func skillPartialEdit(nodesJSON: String, instruction: String) {
        isSkillRunning = true
        let effectiveNodes: String
        if nodesJSON.isEmpty || nodesJSON == "[]" {
            effectiveNodes = extractSelectedNodesJSON()
        } else {
            effectiveNodes = nodesJSON
        }
        let prompt = DesignPrompts.dispatcher.skillPartialEditPrompt(effectiveNodes, instruction)
        let config = FusionConfig.shared
        let args = [
            "generate",
            "--prompt", prompt,
            "--page", "PartialEdit",
            "--model", config.defaultModel(for: .artifacts),
            "--endpoint", config.mlxBaseURL
        ]
        let result = runFusionDesign(args, stdin: effectiveNodes)
        if result.exitCode == 0, !result.output.isEmpty {
            lastSkillOutput = result.output
            if let data = result.output.data(using: .utf8),
               let _ = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                applyPartialEditResult(result.output)
                designBridgeLog.info("DesignBridge: partial_edit applied, \(result.output.count) chars")
            } else {
                renderDocumentToCanvas(result.output)
                designBridgeLog.info("DesignBridge: partial_edit rendered as document")
            }
        } else {
            designBridgeLog.error("DesignBridge: partial_edit failed: \(result.error)")
        }
        isSkillRunning = false
    }

    func skillSimPanel(prompt: String, pageName: String = "Home") {
        isSkillRunning = true
        let simPrompt = DesignPrompts.dispatcher.skillSimPanelPrompt(prompt)
        let config = FusionConfig.shared
        let args = [
            "generate",
            "--prompt", simPrompt,
            "--page", pageName,
            "--model", config.defaultModel(for: .artifacts),
            "--endpoint", config.mlxBaseURL
        ]
        let result = runFusionDesign(args)
        if result.exitCode == 0 {
            lastSkillOutput = result.output
            renderDocumentToCanvas(result.output)
            designBridgeLog.info("DesignBridge: sim_panel rendered")
        } else {
            designBridgeLog.error("DesignBridge: sim_panel failed: \(result.error)")
        }
        isSkillRunning = false
    }

    func skillSpecDoc(prompt: String) {
        isSkillRunning = true
        let specPrompt = DesignPrompts.dispatcher.skillSpecDocPrompt(prompt)
        let config = FusionConfig.shared
        let args = [
            "generate",
            "--prompt", specPrompt,
            "--page", "SpecDoc",
            "--model", config.defaultModel(for: .artifacts),
            "--endpoint", config.mlxBaseURL
        ]
        let result = runFusionDesign(args)
        if result.exitCode == 0 {
            lastSkillOutput = result.output
            if let html = try? parseHtmlFromPenOutput(result.output) {
                renderDocumentToCanvas(html)
            } else {
                renderDocumentToCanvas(result.output)
            }
            designBridgeLog.info("DesignBridge: spec_doc generated")
        } else {
            designBridgeLog.error("DesignBridge: spec_doc failed: \(result.error)")
        }
        isSkillRunning = false
    }

    func skillPageFlow(prompt: String, pageNames: [String]? = nil) {
        isSkillRunning = true
        variantPages.removeAll()
        let names = pageNames ?? DesignPrompts.dispatcher.pageFlowDefaultNames
        let flowDesc = names.enumerated().map { idx, name in
            DesignPrompts.dispatcher.pageFlowPerPage(idx, name, prompt)
        }.joined(separator: "\n")
        let flowPrompt = DesignPrompts.dispatcher.pageFlowFlowPrompt(flowDesc)
        let config = FusionConfig.shared
        for (idx, pageName) in names.enumerated() {
            let pagePrompt = DesignPrompts.dispatcher.pageFlowPagePrompt(flowPrompt, idx, pageName)
            let args = [
                "generate",
                "--prompt", pagePrompt,
                "--page", pageName,
                "--model", config.defaultModel(for: .artifacts),
                "--endpoint", config.mlxBaseURL
            ]
            let result = runFusionDesign(args)
            if result.exitCode == 0 {
                variantPages.append(VariantPage(
                    id: "pageflow-\(idx)",
                    title: pageName,
                    documentJSON: result.output
                ))
                designBridgeLog.info("DesignBridge: page_flow[\(idx)] page=\(pageName) done")
            }
        }
        if let first = variantPages.first {
            renderDocumentToCanvas(first.documentJSON)
        }
        isSkillRunning = false
    }

    func skillMultiVariants(prompt: String, styles: [String]? = nil, pageName: String = "Home") {
        isSkillRunning = true
        variantPages.removeAll()
        let resolvedStyles = styles ?? DesignPrompts.dispatcher.multiVariantsDefaultStyles
        for (idx, style) in resolvedStyles.enumerated() {
            let styledPrompt = DesignPrompts.dispatcher.multiVariantsStyledPrompt(prompt, style)
            let config = FusionConfig.shared
            let args = [
                "generate",
                "--prompt", styledPrompt,
                "--page", "\(pageName)-\(style)",
                "--model", config.defaultModel(for: .artifacts),
                "--endpoint", config.mlxBaseURL
            ]
            let result = runFusionDesign(args)
            if result.exitCode == 0 {
                variantPages.append(VariantPage(
                    id: "variant-\(idx)",
                    title: style,
                    documentJSON: result.output
                ))
                designBridgeLog.info("DesignBridge: multi_variants[\(idx)] style=\(style) done")
            }
        }
        isSkillRunning = false
    }

    func skillLint(documentJSON: String? = nil, designSystem: String = "apple-hig", fix: Bool = false, dryRun: Bool = false) -> [DesignLintIssue] {
        let docJSON = documentJSON ?? lastRenderedDocumentJSON ?? ""
        guard !docJSON.isEmpty else { return [] }
        // F-I6: 临时文件统一收口 ~/.fusion-studio/tmp/ (0700 目录 + 0600 文件 + UUID + 启动清理 LRU)。
        // 原 BUG-11 仅修 TOCTOU (UUID+0600) 但散落系统 NSTemporaryDirectory (/tmp), 无清理无上限。
        guard let tmpPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_lint", contents: Data(docJSON.utf8)) else {
            designBridgeLog.error("DesignBridge: lint tmp write failed")
            return []
        }
        var args = ["lint", "--input", tmpPath, "--design-system", designSystem]
        if fix { args.append("--fix") }
        if dryRun { args.append("--dry-run") }
        let result = runFusionDesign(args)
        try? FileManager.default.removeItem(atPath: tmpPath)
        guard result.exitCode == 0, !result.output.isEmpty else {
            designBridgeLog.error("DesignBridge: lint failed: \(result.error)")
            return []
        }
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let violations = json["violations"] as? [[String: Any]] {
            let parsed = violations.compactMap { issue -> DesignLintIssue? in
                guard let rule = issue["rule"] as? String,
                      let severity = issue["severity"] as? String,
                      let message = issue["message"] as? String else { return nil }
                return DesignLintIssue(
                    rule: rule,
                    severity: severity,
                    message: message,
                    nodeID: issue["node_id"] as? String,
                    suggestion: issue["suggestion"] as? String
                )
            }
            designBridgeLog.info("DesignBridge: lint found \(parsed.count) issues")
            return parsed
        }
        return []
    }

    func skillDiff(oldJSON: String, newJSON: String) -> [DesignDiffEntry] {
        // F-I6: 临时文件统一收口 (统一目录 + 0600 + UUID + 启动清理 LRU)。原散落系统 /tmp。
        guard let oldPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_diff_old", contents: Data(oldJSON.utf8)),
              let newPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_diff_new", contents: Data(newJSON.utf8)) else {
            designBridgeLog.error("DesignBridge: diff tmp write failed")
            return []
        }
        let result = runFusionDesign(["diff", "--old", oldPath, "--new", newPath])
        try? FileManager.default.removeItem(atPath: oldPath)
        try? FileManager.default.removeItem(atPath: newPath)
        guard result.exitCode == 0 else {
            designBridgeLog.error("DesignBridge: diff failed: \(result.error)")
            return []
        }
        if let data = result.output.data(using: .utf8) {
            let diffArr: [[String: Any]]
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let entries = obj["entries"] as? [[String: Any]] {
                diffArr = entries
            } else if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                diffArr = arr
            } else {
                return []
            }
            let entries = diffArr.compactMap { entry -> DesignDiffEntry? in
                let kind = entry["change_type"] as? String ?? entry["kind"] as? String ?? ""
                let path = entry["node_id"] as? String ?? entry["path"] as? String ?? ""
                guard !kind.isEmpty, !path.isEmpty else { return nil }
                let oldVal: String
                if let o = entry["old_value"] { oldVal = String(describing: o) }
                else if let o = entry["old"] as? String { oldVal = o }
                else { oldVal = "" }
                let newVal: String
                if let n = entry["new_value"] { newVal = String(describing: n) }
                else if let n = entry["new"] as? String { newVal = n }
                else { newVal = "" }
                return DesignDiffEntry(kind: kind, path: path, oldValue: oldVal, newValue: newVal)
            }
            designBridgeLog.info("DesignBridge: diff found \(entries.count) changes")
            return entries
        }
        return []
    }

    func skillHealthCheck(endpoint: String = FusionConfig.shared.mlxBaseURL) -> [String: Any]? {
        let result = runFusionDesign(["health", "--endpoint", endpoint])
        guard result.exitCode == 0 else { return nil }
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return nil
    }

    func skillTheme(designSystem: String = "apple-hig", mode: String = "dark") -> String? {
        let result = runFusionDesign(["theme", "--design-system", designSystem, "--mode", mode])
        guard result.exitCode == 0, !result.output.isEmpty else { return nil }
        return result.output
    }

    private func parseHtmlFromPenOutput(_ output: String) -> String? {
        if output.contains("<html") || output.contains("<!DOCTYPE") {
            return output
        }
        if output.contains("<antArtifact") {
            let pattern = try? NSRegularExpression(pattern: "<antArtifact[^>]*>([\\s\\S]*?)</antArtifact>")
            if let match = pattern?.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                return String(output[range])
            }
        }
        return nil
    }

    @Published var variantPages: [VariantPage] = []

    func setIPCClient(_ client: IPCClient) {
        self.ipcClient = client
        designBridgeLog.info("DesignBridge: IPCClient injected")
    }

    // MARK: - Panel Convenience Methods

    func applyDesignTokensToCanvas(systemId: String) {
        let result = runFusionDesign(["token-css", "--design-system", systemId])
        if result.exitCode == 0, !result.output.isEmpty {
            applyDesignTokensToCanvas(result.output)
            designBridgeLog.info("DesignBridge: applied tokens for system=\(systemId)")
        } else {
            designBridgeLog.error("DesignBridge: token-css CLI failed: \(result.error)")
        }
    }

    func loadDocumentJSON(_ json: String) {
        renderDocumentToCanvas(json)
        designBridgeLog.info("DesignBridge: loaded document JSON (\(json.count) chars)")
    }

    func mutateNode(nodeId: String, fill: String? = nil, stroke: String? = nil) {
        mutateCanvasNode(nodeId, x: nil, y: nil, w: nil, h: nil, fill: fill, stroke: stroke)
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
        capMessages()
        isGenerating = true
        artifactSaved = false
        errorMessage = nil
        parseState = .idle
        parseBuffer = ""
        rawAssistantContent = ""
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
                rawAssistantContent += token
                processStreamToken(token)

                streamTokenCount += 1
                let previewBase = assistantContent.suffix(120)
                streamPreviewText = String(previewBase)
                if streamTokenCount == 1 {
                    inferenceStep = "streaming"
                }
            }

            let finalArtifact = extractArtifactFromComplete(rawAssistantContent)
            DesignPreviewTrace.log("sendDesignChat: stream loop done, rawLen=\(rawAssistantContent.count) tokens=\(streamTokenCount) hasAnt=\(rawAssistantContent.contains("<antArtifact")) finalArtifact=\(finalArtifact != nil)")
            let assistantMsg = DesignMessage(
                role: "assistant",
                content: assistantContent,
                timestamp: Date(),
                artifactInfo: finalArtifact
            )
            messages.append(assistantMsg)
            capMessages()

            if finalArtifact != nil {
                designBridgeLog.info("DesignBridge: artifact parsed — type=\(self.currentArtifactType), title=\(self.currentArtifactTitle), \(self.currentArtifactCode.count) chars")
                DesignPreviewTrace.log("sendDesignChat: finalArtifact set, codeLen=\(self.currentArtifactCode.count)")
            } else {
                let extractedCode = extractCodeBlock(from: rawAssistantContent)
                if !extractedCode.isEmpty {
                    currentArtifactCode = extractedCode
                    if currentArtifactTitle.isEmpty { currentArtifactTitle = "Design" }
                    if currentArtifactType.isEmpty { currentArtifactType = "html" }
                    designBridgeLog.info("DesignBridge: code block extracted, \(extractedCode.count) chars")
                    DesignPreviewTrace.log("sendDesignChat: codeBlock fallback, len=\(extractedCode.count)")
                } else {
                    DesignPreviewTrace.log("sendDesignChat: NO artifact extracted, rawLen=\(rawAssistantContent.count) hasAnt=\(rawAssistantContent.contains("<antArtifact")) hasFence=\(rawAssistantContent.contains("```html"))")
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
                DesignPreviewTrace.log("sendDesignChat: TRUNCATED by length, rawLen=\(rawAssistantContent.count) tokens=\(streamTokenCount)")
            }

        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge sendDesignChat: \(error)")
            DesignPreviewTrace.log("sendDesignChat CAUGHT: \(error.localizedDescription) rawLen=\(rawAssistantContent.count) tokens=\(streamTokenCount)")
        }

        isGenerating = false
        inferenceStep = ""
        streamTokenCount = 0
        streamPreviewText = ""
    }

    // MARK: - Stream Token Parsing (antArtifact XML)

    private func processStreamToken(_ token: String) {
        parseBuffer += token

        switch parseState {
        case .idle:
            if let range = parseBuffer.range(of: "<antArtifact") {
                parseState = .inOpenTag
                let afterTag = String(parseBuffer[range.upperBound...])
                parseBuffer = afterTag
                parseOpenTagAttributes(afterTag)
            } else if parseBuffer.count > 500 {
                let keep = parseBuffer.suffix(200)
                parseBuffer = String(keep)
            }

        case .inOpenTag:
            if let range = parseBuffer.range(of: ">") {
                parseState = .inCode
                currentArtifactCode = ""
                let afterClose = String(parseBuffer[range.upperBound...])
                parseBuffer = afterClose
                parseOpenTagAttributes(parseBuffer)
                currentArtifactCode += afterClose
            }

        case .inCode:
            if let range = parseBuffer.range(of: "</antArtifact>") {
                let beforeClose = String(parseBuffer[..<range.lowerBound])
                currentArtifactCode += beforeClose
                parseState = .idle
                parseBuffer = ""
            } else {
                if parseBuffer.count > 200 {
                    let flushCount = parseBuffer.count - 100
                    let flushIdx = parseBuffer.index(parseBuffer.startIndex, offsetBy: flushCount)
                    currentArtifactCode += String(parseBuffer[..<flushIdx])
                    parseBuffer = String(parseBuffer[flushIdx...])
                } else {
                    currentArtifactCode += token
                }
            }

        case .inCloseTag:
            break
        }
    }

    private func parseOpenTagAttributes(_ text: String) {
        if let typeRange = text.range(of: "type=\"") {
            let start = typeRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentArtifactType = String(text[start..<end])
            }
        }
        if let titleRange = text.range(of: "title=\"") {
            let start = titleRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentArtifactTitle = String(text[start..<end])
            }
        }
        if let idRange = text.range(of: "identifier=\"") {
            let start = idRange.upperBound
            if let end = text[start...].firstIndex(of: "\"") {
                currentIdentifier = String(text[start..<end])
            }
        }
    }

    // MARK: - Post-hoc Artifact Extraction

    func extractArtifactFromComplete(_ content: String) -> ArtifactParseResult? {
        guard let openRange = content.range(of: "<antArtifact") else { return nil }
        guard let openTagEnd = content.range(of: ">", range: openRange.upperBound..<content.endIndex) else { return nil }

        let openTag = String(content[openRange.lowerBound..<openTagEnd.upperBound])
        var code: String
        if let closeRange = content.range(of: "</antArtifact>", range: openTagEnd.upperBound..<content.endIndex) {
            code = String(content[openTagEnd.upperBound..<closeRange.lowerBound])
        } else {
            code = String(content[openTagEnd.upperBound..<content.endIndex])
            designBridgeLog.warning("DesignBridge: antArtifact open tag found but close tag missing (likely truncated by max_tokens), extracting partial code")
        }
        code = code.trimmingCharacters(in: .whitespacesAndNewlines)

        var artType = "html"
        var artTitle = "Design"
        var artId = ""

        if let typeRange = openTag.range(of: "type=\"") {
            let start = typeRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artType = String(openTag[start..<end])
            }
        }
        if let titleRange = openTag.range(of: "title=\"") {
            let start = titleRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artTitle = String(openTag[start..<end])
            }
        }
        if let idRange = openTag.range(of: "identifier=\"") {
            let start = idRange.upperBound
            if let end = openTag[start...].firstIndex(of: "\"") {
                artId = String(openTag[start..<end])
            }
        }

        currentArtifactType = artType
        currentArtifactTitle = artTitle
        currentArtifactCode = code
        currentIdentifier = artId

        return ArtifactParseResult(type: artType, title: artTitle, identifier: artId, code: code)
    }

    func extractCodeBlock(from content: String) -> String {
        let fenceOpeners = ["```html", "```react", "```jsx", "```"]
        for opener in fenceOpeners {
            guard let startRange = content.range(of: opener) else { continue }
            let codeStart = content.index(after: startRange.upperBound)
            let codeStartAdjusted = codeStart < content.endIndex && content[codeStart] == "\n"
                ? content.index(after: codeStart)
                : codeStart
            if let endRange = content.range(of: "```", range: codeStartAdjusted..<content.endIndex) {
                return String(content[codeStartAdjusted..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(content[codeStartAdjusted..<content.endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    // MARK: - Save Artifact

    func saveAsArtifact() async {
        guard !currentArtifactCode.isEmpty else { return }
        guard let ipc = ipcClient else {
            errorMessage = "IPCClient not initialized"
            return
        }

        do {
            let projectId = FusionProjectManager.shared.activeProject?.id
            let designMetadata: [String: Any] = [
                "component_name": currentArtifactTitle,
                "framework": currentArtifactType,
                "layout_type": "responsive",
                "source": "fusion-design"
            ]
            if artifactId.isEmpty {
                let result = try await ipc.artifactCreate(
                    sessionId: sessionId,
                    name: currentArtifactTitle.isEmpty ? "Design \(DateFormatter.shortDate.string(from: Date()))" : currentArtifactTitle,
                    type: currentArtifactType,
                    kind: kindForType(currentArtifactType),
                    content: currentArtifactCode,
                    projectId: projectId,
                    metadata: designMetadata
                )
                if let id = result["id"] as? String { artifactId = id }
            } else {
                _ = try await ipc.artifactUpdate(
                    artifactId: artifactId,
                    content: currentArtifactCode,
                    changeLog: "Updated via Design",
                    projectId: projectId,
                    metadata: designMetadata
                )
            }
            artifactSaved = true
            if pages.indices.contains(currentPageIndex) {
                pages[currentPageIndex].artifactId = artifactId
                pages[currentPageIndex].code = currentArtifactCode
                pages[currentPageIndex].title = currentArtifactTitle
                pages[currentPageIndex].type = currentArtifactType
            } else if !artifactId.isEmpty {
                let page = DesignPage(artifactId: artifactId, title: currentArtifactTitle, type: currentArtifactType, code: currentArtifactCode)
                pages.append(page)
                currentPageIndex = pages.count - 1
            }
            designBridgeLog.info("DesignBridge: artifact saved — \(self.currentArtifactTitle), id=\(self.artifactId)")
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge saveAsArtifact: \(error)")
        }
    }

    func kindForType(_ type: String) -> String {
        switch type.lowercased() {
        case "html", "react": return "app"
        case "markdown": return "document"
        default: return "code"
        }
    }

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
        parseState = .idle
        parseBuffer = ""
        rawAssistantContent = ""
        sessionId = "design-\(UUID().uuidString.prefix(8))"
        inferenceStep = ""
        streamTokenCount = 0
        streamPreviewText = ""
    }

    // MARK: - Multi-Page Management

    func addPage() {
        let page = DesignPage(title: "Page \(pages.count + 1)")
        pages.append(page)
        switchToPage(at: pages.count - 1)
        designBridgeLog.info("DesignBridge: added page '\(page.title)', total=\(self.pages.count)")
    }

    func deletePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let wasCurrent = index == currentPageIndex
        pages.remove(at: index)
        if pages.isEmpty {
            currentPageIndex = -1
            currentArtifactCode = ""
            currentArtifactTitle = ""
            currentArtifactType = "html"
            artifactId = ""
        } else if wasCurrent {
            let newIndex = min(index, pages.count - 1)
            switchToPage(at: newIndex)
        } else if currentPageIndex > index {
            currentPageIndex -= 1
        }
        designBridgeLog.info("DesignBridge: deleted page at \(index), remaining=\(self.pages.count)")
    }

    func switchToPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        saveCurrentPageState()
        currentPageIndex = index
        let page = pages[index]
        currentArtifactCode = page.code
        currentArtifactTitle = page.title
        currentArtifactType = page.type
        artifactId = page.artifactId
        versionHistory = []
        designBridgeLog.info("DesignBridge: switched to page '\(page.title)' at \(index)")
    }

    func renamePage(at index: Int, newTitle: String) {
        guard pages.indices.contains(index) else { return }
        pages[index].title = newTitle
        if index == currentPageIndex {
            currentArtifactTitle = newTitle
        }
        designBridgeLog.info("DesignBridge: renamed page at \(index) to '\(newTitle)'")
    }

    func saveCurrentPageState() {
        guard pages.indices.contains(currentPageIndex) else { return }
        pages[currentPageIndex].code = currentArtifactCode
        pages[currentPageIndex].title = currentArtifactTitle
        pages[currentPageIndex].type = currentArtifactType
        pages[currentPageIndex].artifactId = artifactId
    }

    // MARK: - Version History

    func loadVersionHistory() async {
        guard !artifactId.isEmpty, let ipc = ipcClient else { return }
        isLoadingHistory = true
        do {
            let result = try await ipc.artifactVersionList(artifactId: artifactId)
            if let versions = result["versions"] as? [[String: Any]] {
                versionHistory = versions
            } else if let versions = result["data"] as? [[String: Any]] {
                versionHistory = versions
            }
            designBridgeLog.info("DesignBridge: loaded \(self.versionHistory.count) versions for \(self.artifactId)")
        } catch {
            designBridgeLog.error("DesignBridge loadVersionHistory: \(error)")
        }
        isLoadingHistory = false
    }

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

    @Published var versionDiffEntries: [DesignDiffEntry] = []
    @Published var isDiffing: Bool = false

    func diffVersions(oldJSON: String, newJSON: String) {
        isDiffing = true
        versionDiffEntries = skillDiff(oldJSON: oldJSON, newJSON: newJSON)
        isDiffing = false
        designBridgeLog.info("DesignBridge: version diff completed, \(self.versionDiffEntries.count) changes")
    }

    @Published var activeTheme: String = "dark"
    @Published var activeDesignSystem: String = "apple-hig"

    func switchTheme(_ mode: String) {
        activeTheme = mode
        if let css = skillTheme(designSystem: activeDesignSystem, mode: mode) {
            applyDesignTokensToCanvas(css)
            designBridgeLog.info("DesignBridge: switched theme to \(mode)")
        }
    }

    func switchDesignSystem(_ systemId: String) {
        activeDesignSystem = systemId
        applyDesignTokensToCanvas(systemId: systemId)
        designBridgeLog.info("DesignBridge: switched design system to \(systemId)")
    }

    func listDesignSystems() -> [String] {
        let result = runFusionDesign(["list-design-systems"])
        if result.exitCode == 0, !result.output.isEmpty {
            return result.output.components(separatedBy: "\n").filter { !$0.isEmpty }
        }
        return ["apple-hig"]
    }

    func copyCurrentCode() {
        guard !currentArtifactCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentArtifactCode, forType: .string)
        designBridgeLog.info("DesignBridge: code copied to clipboard")
    }

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

    func ingestDesignTokens() async {
        guard let ipc = ipcClient else { return }
        let _ = StudioTheme.dark
        let tokenDoc = """
        # Fusion Studio Design Tokens
        ## Colors
        - accent: #007AFF
        - accentDestructive: red
        - greenDot: success green
        - amberDot: warning amber
        - redDot: error red
        ## Spacing (4pt grid)
        - XS: 4pt, S: 8pt, M: 12pt, L: 16pt, XL: 24pt, 2XL: 32pt
        ## Typography
        - caption: 12pt, footnote: 13pt, small: 14pt, text: 15pt, body: 16pt, title: 19pt, headline: 22pt, largeTitle: 30pt
        ## Radius
        - small: 8pt, default: 12pt, large: 16pt
        ## Animation
        - fast: 0.15s, normal: 0.25s, slow: 0.35s
        """
        let scope = "design:tokens"
        do {
            _ = try await ipc.knowledgeIngest(content: tokenDoc, scope: scope, metadata: ["type": "design_tokens"])
            designBridgeLog.info("DesignBridge: design tokens ingested to RAG")
        } catch {
            designBridgeLog.warning("DesignBridge token ingest failed: \(error.localizedDescription)")
        }
    }

    // MARK: - SwiftUI Export

    @Published var exportedSwiftUICode: String = ""
    @Published var isExportingSwiftUI: Bool = false

    func exportAsSwiftUI() async {
        guard !currentArtifactCode.isEmpty else { return }
        guard ipcClient != nil else {
            errorMessage = "IPCClient not initialized"
            return
        }

        isExportingSwiftUI = true
        let request = SwiftUIExporter.buildConversionRequest(
            htmlCode: currentArtifactCode,
            title: currentArtifactTitle
        )

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL"
            isExportingSwiftUI = false
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.defaultModel(for: .code),
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "temperature": 0.3,
            "max_tokens": 4096,
            "stream": false
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                exportedSwiftUICode = SwiftUIExporter.extractSwiftUICode(from: content)
                designBridgeLog.info("DesignBridge: SwiftUI export done, \(self.exportedSwiftUICode.count) chars")
            }
        } catch {
            errorMessage = "SwiftUI export failed: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge exportAsSwiftUI: \(error)")
        }
        isExportingSwiftUI = false
    }

    func copyExportedSwiftUI() {
        guard !exportedSwiftUICode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedSwiftUICode, forType: .string)
        designBridgeLog.info("DesignBridge: SwiftUI code copied")
    }

    // MARK: - Codegen Export (HTML/React/Tailwind via CLI)

    @Published var exportedCodegenCode: String = ""
    @Published var isExportingCodegen: Bool = false

    func exportAsCodegen(target: String, componentName: String) async {
        guard let documentJSON = lastRenderedDocumentJSON, !documentJSON.isEmpty else {
            errorMessage = "No document to export"
            return
        }
        isExportingCodegen = true
        // ERR-6 (审计product-0905 P1): runFusionDesign 同步 Process 阻塞, 在 @MainActor class 直接调 = 卡 UI。
        // 移 Task.detached 后台跑: MainActor 预解析 cliPath, nonisolated static runCLIProcess 跑 Process, 回填 @Published 在 MainActor。
        let cliPath = resolveCLIPath()
        guard !cliPath.isEmpty else {
            errorMessage = "CLI not found"
            isExportingCodegen = false
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            Self.runCLIProcess(
                cliPath: cliPath,
                args: ["codegen", "--target", target, "--component", componentName],
                stdin: documentJSON
            )
        }.value
        if result.exitCode == 0 {
            exportedCodegenCode = result.output
            designBridgeLog.info("DesignBridge: codegen export done, target=\(target), \(result.output.count) chars")
        } else {
            errorMessage = "codegen failed: \(result.error)"
            designBridgeLog.error("DesignBridge exportAsCodegen: \(result.error)")
        }
        isExportingCodegen = false
    }

    func copyExportedCodegen() {
        guard !exportedCodegenCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedCodegenCode, forType: .string)
        designBridgeLog.info("DesignBridge: codegen code copied")
    }

    // MARK: - Batch Export (SVG/HTML/JSON via CLI)

    @Published var isBatchExporting: Bool = false
    @Published var batchExportResult: String = ""

    func batchExportPages(format: String, to outputDir: String) async {
        guard let documentJSON = lastRenderedDocumentJSON, !documentJSON.isEmpty else {
            errorMessage = "No document to export"
            return
        }
        isBatchExporting = true
        batchExportResult = ""
        // F-I6: 临时文件统一收口 (统一目录 + 0600 + UUID + 启动清理 LRU)。原散落系统 /tmp。
        guard let tmpPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_export", contents: Data(documentJSON.utf8)) else {
            errorMessage = "export tmp write failed"
            isBatchExporting = false
            return
        }
        // ERR-6 (审计product-0905 P1): 同步 Process 阻塞 MainActor, 移 Task.detached 后台跑。
        let cliPath = resolveCLIPath()
        guard !cliPath.isEmpty else {
            errorMessage = "CLI not found"
            try? FileManager.default.removeItem(atPath: tmpPath)
            isBatchExporting = false
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            Self.runCLIProcess(
                cliPath: cliPath,
                args: ["export", "--input", tmpPath, "--format", format, "--out", outputDir]
            )
        }.value
        try? FileManager.default.removeItem(atPath: tmpPath)
        if result.exitCode == 0 {
            batchExportResult = result.output
            designBridgeLog.info("DesignBridge: batch export done, format=\(format), result=\(result.output)")
        } else {
            errorMessage = "export failed: \(result.error)"
            designBridgeLog.error("DesignBridge batchExportPages: \(result.error)")
        }
        isBatchExporting = false
    }

    // MARK: - Artifact ↔ File Sync

    @Published var syncFolderPath: String = ""
    @Published var isFileSyncEnabled: Bool = false

    func enableFileSync(to folderPath: String) {
        syncFolderPath = folderPath
        isFileSyncEnabled = true
        designBridgeLog.info("DesignBridge: file sync enabled to \(folderPath)")
    }

    func disableFileSync() {
        isFileSyncEnabled = false
        syncFolderPath = ""
        designBridgeLog.info("DesignBridge: file sync disabled")
    }

    func syncArtifactToFile() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty, !currentArtifactCode.isEmpty else {
            designBridgeLog.warning("DesignBridge: syncArtifactToFile — preconditions not met")
            return
        }

        let ext = currentArtifactType == "react" ? "jsx" : currentArtifactType
        let fileName = currentArtifactTitle.isEmpty ? "design.\(ext)" : "\(sanitizeFileName(currentArtifactTitle)).\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)
        // 审计0827 #2: LLM 产物 fileName 经 syncFolderPath 拼 — 防 LLM 注入 ../ 或 symlink 越界写白名单外, validateFilePath 拒则跳过同步。
        guard SecurityManager.shared.validateFilePath(filePath) else {
            designBridgeLog.warning("DesignBridge: syncArtifactToFile reject path outside whitelist — \(filePath, privacy: .public)")
            return
        }

        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "artifact_to_file")
                designBridgeLog.info("DesignBridge: artifact synced via API — \(result)")
            } catch {
                designBridgeLog.warning("DesignBridge: API sync failed, falling back to file write — \(error.localizedDescription)")
                do {
                    try currentArtifactCode.write(toFile: filePath, atomically: true, encoding: .utf8)
                    designBridgeLog.info("DesignBridge: artifact synced to file \(filePath) (fallback)")
                } catch {
                    designBridgeLog.error("DesignBridge: file sync failed — \(error.localizedDescription)")
                }
            }
        } else {
            do {
                try currentArtifactCode.write(toFile: filePath, atomically: true, encoding: .utf8)
                designBridgeLog.info("DesignBridge: artifact synced to file \(filePath)")
            } catch {
                designBridgeLog.error("DesignBridge: file sync failed — \(error.localizedDescription)")
            }
        }
    }

    func syncFileToArtifact() async {
        guard isFileSyncEnabled, !syncFolderPath.isEmpty else {
            designBridgeLog.warning("DesignBridge: syncFileToArtifact — preconditions not met")
            return
        }

        let ext = currentArtifactType == "react" ? "jsx" : currentArtifactType
        let fileName = currentArtifactTitle.isEmpty ? "design.\(ext)" : "\(sanitizeFileName(currentArtifactTitle)).\(ext)"
        let filePath = (syncFolderPath as NSString).appendingPathComponent(fileName)
        // 审计0827 #2: 防 LLM 注入 ../ 或 symlink 越界读白名单外文件, validateFilePath 拒则跳过同步。
        guard SecurityManager.shared.validateFilePath(filePath) else {
            designBridgeLog.warning("DesignBridge: syncFileToArtifact reject path outside whitelist — \(filePath, privacy: .public)")
            return
        }

        if let ipc = ipcClient, !artifactId.isEmpty {
            do {
                let result = try await ipc.artifactSync(artifactId: artifactId, filePath: filePath, direction: "file_to_artifact")
                if let content = result["content"] as? String, content != currentArtifactCode {
                    currentArtifactCode = content
                    artifactSaved = false
                    designBridgeLog.info("DesignBridge: file synced to artifact via API (\(content.count) chars)")
                }
                return
            } catch {
                designBridgeLog.warning("DesignBridge: API sync failed, falling back to file read — \(error.localizedDescription)")
            }
        }

        guard FileManager.default.fileExists(atPath: filePath) else {
            designBridgeLog.info("DesignBridge: no file to sync at \(filePath)")
            return
        }

        do {
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            if content != currentArtifactCode {
                currentArtifactCode = content
                artifactSaved = false
                designBridgeLog.info("DesignBridge: file synced to artifact (\(content.count) chars)")
            }
        } catch {
            designBridgeLog.error("DesignBridge: file→artifact sync failed — \(error.localizedDescription)")
        }
    }

    func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - Screenshot Import (requires fusion-mlx VLM model, e.g. Qwen2.5-VL)

    @Published var isImportingScreenshot: Bool = false

    func importScreenshot(_ image: NSImage) async {
        guard let message = ScreenshotImporter.buildImportRequest(image: image) else {
            errorMessage = "Failed to process screenshot image"
            return
        }

        isImportingScreenshot = true
        designBridgeLog.info("DesignBridge: starting screenshot import")

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            errorMessage = "Invalid MLX URL"
            isImportingScreenshot = false
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "model": config.defaultModel(for: .code),
            "messages": [message],
            "temperature": 0.3,
            "max_tokens": 4096,
            "stream": false
        ]

        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResp = response as? HTTPURLResponse else {
                throw NSError(domain: "DesignBridge", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if httpResp.statusCode == 422 {
                errorMessage = "Screenshot import requires a VLM model (e.g. Qwen2.5-VL). Current model does not support image input."
                designBridgeLog.warning("DesignBridge: screenshot import — model does not support image input (422)")
            } else if httpResp.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let content = choices.first?["message"] as? [String: Any],
                   let text = content["content"] as? String {
                    let result = ScreenshotImporter.parseImportResult(text)
                    currentArtifactCode = result.extractedHTML
                    currentArtifactType = "html"
                    currentArtifactTitle = "Imported Screenshot"
                    artifactSaved = false
                    designBridgeLog.info("DesignBridge: screenshot imported — \(result.extractedHTML.count) chars, confidence=\(result.confidence)")
                }
            } else {
                // BUG-13: 原始 body 原样插 UI 可泄密钥 — 服务端错误体可回显请求头 (Authorization/Bearer/api_key),
                // .prefix(200) 限长拦不住密钥子串。渲染前过 sanitizeErrorBody 剥敏感子串。
                let rawBody = String(data: data, encoding: .utf8) ?? "unknown"
                let safeBody = Self.sanitizeErrorBody(rawBody)
                errorMessage = "Screenshot import failed: HTTP \(httpResp.statusCode) — \(safeBody.prefix(200))"
                designBridgeLog.error("DesignBridge: screenshot import failed — HTTP \(httpResp.statusCode)")
            }
        } catch {
            errorMessage = "Screenshot import error: \(error.localizedDescription)"
            designBridgeLog.error("DesignBridge importScreenshot: \(error)")
        }

        isImportingScreenshot = false
    }

    // FUNC-10/11 (审计product-0905 P3): designHealthCheck + sendMultimodalMessage 已删 — 0 调用方死代码。
    // designHealth/isDesignHealthy @Published 同删 (0 读)。

}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()
}
