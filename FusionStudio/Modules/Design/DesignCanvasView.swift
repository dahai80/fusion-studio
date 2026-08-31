// Callers: DesignView (replaces DesignPreviewView with wasm canvas in HSplitView).
// Affected API: DesignCanvasView NSViewRepresentable, BridgeCommand/BridgeEvent JSON protocol,
//   DesignBridge (ai.chat routing, deleteNode/duplicateNode/bringToFront/sendToBack), selectedNodeID Binding.
// Data schemas: BridgeCommand (PageRender/ApplyTokens/SelectNode/ClearCanvas/PlanPreview/PlanApply/PlanReject),
//   BridgeEvent (NodeClick/NodeDrag/NodeSelect/CanvasClick/AiChat),
//   wasm load from Bundle.main "wasm/fd_host_web.wasm".
// User instruction: "继续实施Phase 6"

import SwiftUI
import WebKit
import Combine
import os.log

private let canvasLog = Logger(subsystem: "com.fusion.studio", category: "DesignCanvasView")

// MARK: - Bridge Command (Native → Wasm)

enum BridgeCommand {
    case pageRender(documentJSON: String)
    case applyTokens(css: String)
    case selectNode(nodeID: String)
    case mutateNode(nodeID: String, x: Float?, y: Float?, w: Float?, h: Float?,
                    fill: String?, stroke: String?, strokeWidth: Float?, radius: Float?,
                    fontSize: Float?, fontFamily: String?, opacity: Float?)
    case setNodeVisibility(nodeID: String, visible: Bool)
    case reorderNode(nodeID: String, newIndex: Int)
    case clearCanvas
    case planPreview(documentJSON: String)
    case planApply
    case planReject
    case undoAction
    case redoAction

    func toJSON() -> String {
        switch self {
        case .pageRender(let doc):
            let escaped = doc
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return """
            {"PageRender":{"document_json":"\(escaped)"}}
            """
        case .applyTokens(let css):
            let escaped = css
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return """
            {"ApplyTokens":{"css":"\(escaped)"}}
            """
        case .selectNode(let nodeID):
            return """
            {"SelectNode":{"node_id":"\(nodeID)"}}
            """
        case .mutateNode(let nodeID, let x, let y, let w, let h, let fill, let stroke, let strokeWidth, let radius, let fontSize, let fontFamily, let opacity):
            var parts: [String] = []
            parts.append("\"node_id\":\"\(nodeID)\"")
            if let x = x { parts.append("\"x\":\(x)") }
            if let y = y { parts.append("\"y\":\(y)") }
            if let w = w { parts.append("\"w\":\(w)") }
            if let h = h { parts.append("\"h\":\(h)") }
            if let fill = fill { parts.append("\"fill\":\"\(fill)\"") }
            if let stroke = stroke { parts.append("\"stroke\":\"\(stroke)\"") }
            if let strokeWidth = strokeWidth { parts.append("\"stroke_width\":\(strokeWidth)") }
            if let radius = radius { parts.append("\"radius\":\(radius)") }
            if let fontSize = fontSize { parts.append("\"font_size\":\(fontSize)") }
            if let fontFamily = fontFamily { parts.append("\"font_family\":\"\(fontFamily)\"") }
            if let opacity = opacity { parts.append("\"opacity\":\(opacity)") }
            return """
            {"MutateNode":{\(parts.joined(separator: ","))}}
            """
        case .setNodeVisibility(let nodeID, let visible):
            return """
            {"SetNodeVisibility":{"node_id":"\(nodeID)","visible":\(visible)}}
            """
        case .reorderNode(let nodeID, let newIndex):
            return """
            {"ReorderNode":{"node_id":"\(nodeID)","new_index":\(newIndex)}}
            """
        case .clearCanvas:
            return """
            {"ClearCanvas":null}
            """
        case .planPreview(let doc):
            let escaped = doc
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            return """
            {"PlanPreview":{"document_json":"\(escaped)"}}
            """
        case .planApply:
            return """
            {"PlanApply":null}
            """
        case .planReject:
            return """
            {"PlanReject":null}
            """
        case .undoAction:
            return """
            {"Undo":null}
            """
        case .redoAction:
            return """
            {"Redo":null}
            """
        }
    }
}

// MARK: - Bridge Event (Wasm → Native)

struct BridgeEvent {
    let kind: String
    let payload: [String: Any]

    var nodeID: String? {
        payload["node_id"] as? String
    }

    var x: Float? {
        payload["x"] as? Float
    }

    var y: Float? {
        payload["y"] as? Float
    }

    var dx: Float? {
        payload["dx"] as? Float
    }

    var dy: Float? {
        payload["dy"] as? Float
    }

    var w: Float? {
        payload["w"] as? Float
    }

    var h: Float? {
        payload["h"] as? Float
    }

    var message: String? {
        payload["message"] as? String
    }

    var nodeIDs: [String]? {
        payload["node_ids"] as? [String]
    }

    // #372 OPS-13: log_capture_dump 响应 entries=LogEntry[{level,ts_ms,msg}]。
    var entries: [[String: Any]]? {
        payload["entries"] as? [[String: Any]]
    }
}

// MARK: - DesignCanvasView

struct DesignCanvasView: NSViewRepresentable {
    @EnvironmentObject var designBridge: DesignBridge
    @Binding var selectedNodeID: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "fusionBridge")
        // #372 OPS-13: 注册 fdHost handler 接收 WASM 出站事件 (node.click/node.drag/.../log_capture_dump)。
        // 上游合约 HOST_HANDLER_NAME="fdHost" (fusion-design bridge.rs:219); send_to_host→dispatch_to_host
        // 主路径 webkit.messageHandlers.fdHost.postMessage(json_string)。旧 wasm 无 fdHost (走 __fd_host_post
        // 队列 studio 不轮询), 故旧 canvas 事件未达 studio; 新 wasm 全量事件经 fdHost, 注册即激活。
        // fusionBridge 保留作入站命令 ack (wasm.ready/error 从内联 HTML 经此回)。
        userContentController.add(context.coordinator, name: "fdHost")

        let bridgeScript = WKUserScript(
            source: """
            window.fusionBridge = {
                postMessage: function(msg) {
                    window.webkit.messageHandlers.fusionBridge.postMessage(
                        typeof msg === 'string' ? msg : JSON.stringify(msg)
                    );
                }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(bridgeScript)
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(true, forKey: "drawsTransparentBackground")
        context.coordinator.webView = webView

        let canvasMenu = NSMenu()
        canvasMenu.delegate = context.coordinator
        webView.menu = canvasMenu

        canvasLog.info("DesignCanvasView: WKWebView created, loading wasm HTML")

        loadWasmHTML(into: webView)

        designBridge.canvasWebView = webView
        designBridge.startObservingInspectorChanges()
        designBridge.startWatchingCodeChanges()

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        while let cmd = context.coordinator.pendingCommands.popLast() {
            DesignCanvasView.sendCommand(cmd, to: webView)
        }
    }

    // MARK: - Wasm HTML Loading

    private func loadWasmHTML(into webView: WKWebView) {
        let wasmURL = wasmBundleURL()
        let jsGlueURL = jsGlueBundleURL()

        let wasmPath = wasmURL?.path ?? "(not found)"
        let jsGluePath = jsGlueURL?.path ?? "(not found)"
        canvasLog.info("DesignCanvasView: wasm at \(wasmPath), js glue at \(jsGluePath)")

        guard let wasmURL = wasmURL else {
            canvasLog.error("DesignCanvasView: fd_host_web.wasm not found in bundle")
            loadFallbackHTML(into: webView)
            return
        }

        let wasmFileName = wasmURL.deletingPathExtension().lastPathComponent
        let jsGlueFileName = jsGlueURL?.deletingPathExtension().lastPathComponent ?? "fd_host_web"

        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; overflow: hidden; background: #ffffff; }
                #fusion-canvas { width: 100%; height: 100%; display: block; }
                #fusion-dom-root { position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; }
            </style>
        </head>
        <body>
            <canvas id="fusion-canvas"></canvas>
            <div id="fusion-dom-root"></div>
            <script type="module">
                import init, { mount, fusion_bridge_send_command } from './\(jsGlueFileName).js';
                async function initWasm() {
                    try {
                        await init('./\(wasmFileName)_bg.wasm');
                        window.__fusionShell = mount('fusion-canvas');
                        window.fusion_bridge_send_command = fusion_bridge_send_command;
                        console.log('fd-host-web wasm initialized');
                        if (window.fusionBridge) {
                            window.fusionBridge.postMessage(JSON.stringify({
                                kind: 'wasm.ready',
                                payload: {}
                            }));
                        }
                    } catch(e) {
                        console.error('fd-host-web wasm init failed:', e);
                        if (window.fusionBridge) {
                            window.fusionBridge.postMessage(JSON.stringify({
                                kind: 'wasm.error',
                                payload: { message: e.toString() }
                            }));
                        }
                    }
                }
                initWasm();
            </script>
        </body>
        </html>
        """

        let baseURL = wasmURL.deletingLastPathComponent()
        webView.loadHTMLString(html, baseURL: baseURL)
        canvasLog.info("DesignCanvasView: HTML loaded with baseURL=\(baseURL.path)")
    }

    private func loadFallbackHTML(into webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <style>
                body { background: #1a1a2e; color: #a0a0a0; display: flex; align-items: center;
                       justify-content: center; height: 100vh; font-family: -apple-system, sans-serif; }
                .placeholder { text-align: center; }
                .placeholder h2 { color: #e0e0e0; margin-bottom: 8px; }
            </style>
        </head>
        <body>
            <div class="placeholder">
                <h2>Fusion Design Canvas</h2>
                <p>wasm 模块未找到，请先构建 fd-host-web</p>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Bundle Resource Helpers

    private func wasmBundleURL() -> URL? {
        Bundle.module.url(forResource: "fd_host_web_bg", withExtension: "wasm")
            ?? Bundle.main.url(forResource: "fd_host_web_bg", withExtension: "wasm", subdirectory: "wasm")
            ?? Bundle.main.url(forResource: "fd_host_web_bg", withExtension: "wasm")
    }

    private func jsGlueBundleURL() -> URL? {
        Bundle.module.url(forResource: "fd_host_web", withExtension: "js")
            ?? Bundle.main.url(forResource: "fd_host_web", withExtension: "js", subdirectory: "wasm")
            ?? Bundle.main.url(forResource: "fd_host_web", withExtension: "js")
    }

    // MARK: - Command Sending

    static func sendCommand(_ command: BridgeCommand, to webView: WKWebView) {
        let json = command.toJSON()
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        let js = "if (typeof fusion_bridge_send_command === 'function') { fusion_bridge_send_command('\(escaped)'); }"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                canvasLog.error("DesignCanvasView: sendCommand failed: \(error)")
            }
        }
    }

    // #372 OPS-13: 向 canvas WASM 发 log.capture.dump 拉取请求。
    // log.capture.dump 仅由 wasm 的 window-message 监听器 (handle_host_message, bridge.rs:187) 处理,
    // 非 BridgeCommand (fusion_bridge_send_command 只匹配 11 个渲染/plan arm), 故走 window.postMessage
    // 触发同窗口 message 事件。响应异步经 fdHost handler 回 (kind=log_capture_dump)。
    static func requestLogDump(to webView: WKWebView, clear: Bool) {
        let clearLit = clear ? "true" : "false"
        let js = "window.postMessage(JSON.stringify({kind:'log.capture.dump',payload:{clear:\(clearLit)}}),'*');"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                canvasLog.error("DesignCanvasView: requestLogDump failed: \(error)")
            } else {
                canvasLog.info("DesignCanvasView: sent log.capture.dump (clear=\(clear))")
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, NSMenuDelegate {
        var parent: DesignCanvasView
        weak var webView: WKWebView?
        var pendingCommands: [BridgeCommand] = []
        private var isWasmReady = false
        var lastDumpPath: String?  // #372: 最近一次 log_capture_dump 落盘路径

        init(parent: DesignCanvasView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "fusionBridge" || message.name == "fdHost" else { return }

            let bodyString: String
            if let str = message.body as? String {
                bodyString = str
            } else if let dict = message.body as? [String: Any],
                      let data = try? JSONSerialization.data(withJSONObject: dict),
                      let str = String(data: data, encoding: .utf8) {
                bodyString = str
            } else {
                canvasLog.warning("DesignCanvasView: unparseable bridge message")
                return
            }

            handleBridgeMessage(bodyString)
        }

        private func handleBridgeMessage(_ json: String) {
            guard let data = json.data(using: .utf8),
                  let msg = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                canvasLog.warning("DesignCanvasView: invalid bridge JSON: \(json.prefix(200))")
                return
            }

            let kind = msg["kind"] as? String ?? "unknown"
            let payload = msg["payload"] as? [String: Any] ?? [:]

            let event = BridgeEvent(kind: kind, payload: payload)
            handleBridgeEvent(event)
        }

        private func handleBridgeEvent(_ event: BridgeEvent) {
            canvasLog.info("DesignCanvasView: bridge event kind=\(event.kind)")

            switch event.kind {
            case "wasm.ready":
                isWasmReady = true
                canvasLog.info("DesignCanvasView: wasm ready")
                sendPendingCommands()

            case "wasm.error":
                canvasLog.error("DesignCanvasView: wasm error: \(event.message ?? "unknown")")

            case "log_capture_dump":
                // #372: WASM 响应 log.capture.dump, entries=LogEntry[{level,ts_ms:f64,msg}] 环形缓冲快照。持久化。
                let rawEntries = event.entries ?? []
                let ts = Int64(Date().timeIntervalSince1970 * 1000)
                if let path = FdHostWebLogCapture.shared.persist(entries: rawEntries, timestamp: ts) {
                    canvasLog.info("DesignCanvasView: log_capture_dump persisted \(rawEntries.count) entries → \(path)")
                    self.lastDumpPath = path
                    NotificationCenter.default.post(name: .fdHostWebLogDumpDidComplete, object: nil,
                                                    userInfo: ["count": rawEntries.count, "path": path])
                } else {
                    canvasLog.warning("DesignCanvasView: log_capture_dump had \(rawEntries.count) entries, persist skipped/failed")
                    NotificationCenter.default.post(name: .fdHostWebLogDumpDidComplete, object: nil,
                                                    userInfo: ["count": 0])
                }

            case "node.click":
                DispatchQueue.main.async {
                    self.parent.selectedNodeID = event.nodeID
                    if let nodeID = event.nodeID {
                        DesignInspectorState.shared.selectedElement = nodeID
                        self.showDesignInspector(nodeID: nodeID)
                    }
                }

            case "node.select":
                DispatchQueue.main.async {
                    self.parent.selectedNodeID = event.nodeID
                    if let nodeID = event.nodeID {
                        DesignInspectorState.shared.selectedElement = nodeID
                        self.showDesignInspector(nodeID: nodeID)
                    }
                }

            case "node.multi-select":
                DispatchQueue.main.async {
                    if let nodeID = event.nodeID {
                        DesignInspectorState.shared.selectedElement = nodeID
                        self.showDesignInspector(nodeID: nodeID)
                        canvasLog.info("DesignCanvasView: multi-select node=\(nodeID)")
                    }
                }

            case "node.drag":
                canvasLog.debug("DesignCanvasView: node.drag id=\(event.nodeID ?? "?") dx=\(event.dx ?? 0) dy=\(event.dy ?? 0)")
                DispatchQueue.main.async {
                    if let nodeID = event.nodeID {
                        self.parent.selectedNodeID = nodeID
                        let state = DesignInspectorState.shared
                        state.selectedElement = nodeID
                        if let dx = event.dx, let dy = event.dy {
                            if let curX = Float(state.properties.width.trimmingCharacters(in: CharacterSet(charactersIn: "px"))) {
                                state._lastDragDX = dx
                                state._lastDragDY = dy
                            }
                        }
                    }
                }

            case "node.resize":
                canvasLog.debug("DesignCanvasView: node.resize id=\(event.nodeID ?? "?") w=\(event.w ?? 0) h=\(event.h ?? 0)")
                DispatchQueue.main.async {
                    if let nodeID = event.nodeID {
                        self.parent.selectedNodeID = nodeID
                        let state = DesignInspectorState.shared
                        state.selectedElement = nodeID
                        if let w = event.w {
                            state.properties.width = "\(Int(w))px"
                        }
                        if let h = event.h {
                            state.properties.height = "\(Int(h))px"
                        }
                    }
                }

            case "canvas.click":
                DispatchQueue.main.async {
                    self.parent.selectedNodeID = nil
                    DesignInspectorState.shared.selectedElement = nil
                    self.hideDesignInspector()
                }

            case "canvas.zoom":
                canvasLog.debug("DesignCanvasView: canvas.zoom delta=\(event.payload["delta"] as? Float ?? 0) x=\(event.x ?? 0) y=\(event.y ?? 0)")

            case "canvas.pan":
                canvasLog.debug("DesignCanvasView: canvas.pan dx=\(event.dx ?? 0) dy=\(event.dy ?? 0)")

            case "marquee.select":
                if let nodeIDs = event.nodeIDs, !nodeIDs.isEmpty {
                    DispatchQueue.main.async {
                        self.parent.designBridge.marqueeSelectedNodeIDs = nodeIDs
                        canvasLog.info("DesignCanvasView: marquee selected \(nodeIDs.count) nodes")
                    }
                }

            case "ai.chat":
                if let message = event.message, !message.isEmpty {
                    DispatchQueue.main.async {
                        Task { @MainActor in
                            await self.parent.designBridge.sendDesignChat(message)
                        }
                    }
                }

            default:
                canvasLog.debug("DesignCanvasView: unhandled event kind=\(event.kind)")
            }
        }

        private func showDesignInspector(nodeID: String) {
            NotificationCenter.default.post(
                name: .designInspectorShowNode,
                object: nil,
                userInfo: ["node_id": nodeID]
            )
        }

        private func hideDesignInspector() {
            NotificationCenter.default.post(name: .designInspectorHide, object: nil)
        }

        private func sendPendingCommands() {
            guard let webView = webView else { return }
            while let cmd = pendingCommands.popLast() {
                DesignCanvasView.sendCommand(cmd, to: webView)
            }
        }

        // MARK: WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            canvasLog.info("DesignCanvasView: navigation finished")

            let bridgeJS = """
            window.fusionStudio = {
                version: '0.1.0',
                platform: 'macOS',
                sendToNative: function(msg) {
                    window.webkit.messageHandlers.fusionBridge.postMessage(
                        typeof msg === 'string' ? msg : JSON.stringify(msg)
                    );
                },
                exportCode: function(format, data) {
                    return new Promise((resolve) => {
                        window.fusionStudio.sendToNative({
                            kind: 'export_code', payload: { format: format, data: data }
                        });
                        resolve({ status: 'ok' });
                    });
                }
            };
            """
            webView.evaluateJavaScript(bridgeJS)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            canvasLog.error("DesignCanvasView: navigation failed: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            canvasLog.error("DesignCanvasView: provisional navigation failed: \(error)")
        }

        // #372: WebView 内容进程终止 (OOM/SIGKILL) 时触发 dump。进程已死, 当前 buffer 随之丢失,
        // 此调用对死 webview no-op; 真正价值在重启后 (designBridge 重赋 canvasWebView) 补 dump + 留现场日志。
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            canvasLog.error("DesignCanvasView: content process terminated, triggering crash-recovery log dump")
            parent.designBridge.dumpWasmLog(clear: false)
        }

        // MARK: NSMenuDelegate (context menu)

        func menuNeedsUpdate(_ menu: NSMenu) {
            menu.removeAllItems()
            let bridge = parent.designBridge
            let nodeID = bridge.selectedNodeID

            if let nid = nodeID, !nid.isEmpty {
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_duplicate), action: #selector(duplicateNodeAction), keyEquivalent: "d")
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_delete), action: #selector(deleteNodeAction), keyEquivalent: "\\")
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_toggleLock), action: #selector(toggleLockAction), keyEquivalent: "l")
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_toggleVisibility), action: #selector(toggleVisibilityAction), keyEquivalent: "h")
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_partialRepaint), action: #selector(partialRepaintAction), keyEquivalent: "")
                menu.addItem(NSMenuItem.separator())
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_bringToFront), action: #selector(bringToFrontAction), keyEquivalent: "")
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_sendToBack), action: #selector(sendToBackAction), keyEquivalent: "")
            } else {
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_selectAll), action: #selector(selectAllAction), keyEquivalent: "a")
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_fitZoom), action: #selector(fitZoomAction), keyEquivalent: "0")
                menu.addItem(withTitle: I18nManager.shared.t(.design_cv_menu_paste), action: #selector(pasteAction), keyEquivalent: "v")
            }
        }

        @objc private func duplicateNodeAction() {
            // F-I13 pipefail 暴露: parent.designBridge (main-actor-isolated) 在 @objc 非 isolated 选择器引用 = error。
            // NSView 菜单动作在主线程 → MainActor.assumeIsolated 安全。
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                parent.designBridge.duplicateNode(nid)
            }
        }

        @objc private func deleteNodeAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                parent.designBridge.deleteNode(nid)
            }
        }

        @objc private func toggleLockAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                let isLocked = isNodeLocked(nid)
                parent.designBridge.setNodeLocked(nid, locked: !isLocked)
            }
        }

        @objc private func toggleVisibilityAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                let isVisible = isNodeVisible(nid)
                parent.designBridge.setNodeVisibility(nid, visible: !isVisible)
            }
        }

        @objc private func partialRepaintAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                parent.designBridge.marqueeSelectedNodeIDs = [nid]
                parent.designBridge.skillPartialEdit(nodesJSON: "[]", instruction: "重新设计选中元素的视觉样式")
            }
        }

        @objc private func bringToFrontAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                parent.designBridge.bringToFront(nid)
            }
        }

        @objc private func sendToBackAction() {
            MainActor.assumeIsolated {
                guard let nid = parent.designBridge.selectedNodeID else { return }
                parent.designBridge.sendToBack(nid)
            }
        }

        @objc private func selectAllAction() {
            canvasLog.info("DesignCanvasView: selectAll context menu")
        }

        @objc private func fitZoomAction() {
            canvasLog.info("DesignCanvasView: fitZoom context menu")
        }

        @objc private func pasteAction() {
            canvasLog.info("DesignCanvasView: paste context menu")
        }

        private func isNodeLocked(_ nodeID: String) -> Bool {
            // F-I13 pipefail 暴露: parent.designBridge.lastRenderedDocumentJSON 是 main-actor-isolated,
            // @objc 动作选择器跑在 NSView 非 isolated 上下文 → strict-concurrency error。
            // NSView 菜单动作实际在主线程执行 → MainActor.assumeIsolated 运行时安全 + 满足编译器隔离检查。
            MainActor.assumeIsolated {
                guard let docJSON = parent.designBridge.lastRenderedDocumentJSON,
                      let data = docJSON.data(using: .utf8),
                      let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let pages = doc["pages"] as? [[String: Any]] else { return false }
                for page in pages {
                    guard let nodes = page["nodes"] as? [[String: Any]] else { continue }
                    if let node = nodes.first(where: { ($0["id"] as? String) == nodeID }),
                       let style = node["style"] as? [String: Any],
                       let opacity = style["opacity"] as? Double, opacity < 0.5 {
                        return true
                    }
                }
                return false
            }
        }

        private func isNodeVisible(_ nodeID: String) -> Bool {
            // F-I13 pipefail 暴露: 同 isNodeLocked — lastRenderedDocumentJSON main-actor-isolated, 菜单动作在主线程。
            MainActor.assumeIsolated {
                guard let docJSON = parent.designBridge.lastRenderedDocumentJSON,
                      let data = docJSON.data(using: .utf8),
                      let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let pages = doc["pages"] as? [[String: Any]] else { return true }
                for page in pages {
                    guard let nodes = page["nodes"] as? [[String: Any]] else { continue }
                    if let node = nodes.first(where: { ($0["id"] as? String) == nodeID }),
                       let vis = node["visible"] as? Bool {
                        return vis
                    }
                }
                return true
            }
        }
    }
}
