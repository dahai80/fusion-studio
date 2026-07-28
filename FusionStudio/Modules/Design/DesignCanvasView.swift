// Callers: DesignView (replaces DesignPreviewView with wasm canvas in HSplitView).
// Affected API: DesignCanvasView NSViewRepresentable, BridgeCommand/BridgeEvent JSON protocol,
//   DesignBridge (ai.chat routing), selectedNodeID Binding.
// Data schemas: BridgeCommand (PageRender/ApplyTokens/SelectNode/ClearCanvas/PlanPreview/PlanApply/PlanReject),
//   BridgeEvent (NodeClick/NodeDrag/NodeSelect/CanvasClick/AiChat),
//   wasm load from Bundle.main "wasm/fd_host_web.wasm".
// User instruction: "现在开始实施" — Task #15 P3-4 Plan 机制

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
                html, body { width: 100%; height: 100%; overflow: hidden; background: #1a1a2e; }
                #fusion-canvas { width: 100%; height: 100%; display: block; }
            </style>
        </head>
        <body>
            <canvas id="fusion-canvas"></canvas>
            <script src="\(jsGlueFileName).js"></script>
            <script>
                async function initWasm() {
                    try {
                        await wasm_bindgen('./\(wasmFileName)_bg.wasm');
                        const shell = wasm_bindgen.mount('fusion-canvas');
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
        Bundle.main.url(forResource: "fd_host_web_bg", withExtension: "wasm", subdirectory: "wasm")
            ?? Bundle.main.url(forResource: "fd_host_web_bg", withExtension: "wasm")
    }

    private func jsGlueBundleURL() -> URL? {
        Bundle.main.url(forResource: "fd_host_web", withExtension: "js", subdirectory: "wasm")
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

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: DesignCanvasView
        weak var webView: WKWebView?
        var pendingCommands: [BridgeCommand] = []
        private var isWasmReady = false

        init(parent: DesignCanvasView) {
            self.parent = parent
        }

        // MARK: WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController,
                                    didReceive message: WKScriptMessage) {
            guard message.name == "fusionBridge" else { return }

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
    }
}
