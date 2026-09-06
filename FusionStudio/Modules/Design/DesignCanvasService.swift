import Foundation
import WebKit
import os.log

// ARCH-1 Phase 5 (审计product-0906 P1): DesignCanvas 行为迁入 (本域最大)。DesignBridge 留 1 行 stub 转发
//   (保外部签名: DesignCanvasView.sendCanvasCommand/applyLocalEdit 协调器/DesignLintPanel.dumpWasmLog 0 改)。
//   纯 WKWebView, 0 IPC → 无 ipcClient ref。canvasWebView(weak)/codeWatchTimer/mutateObserver 迁本域。
//   applyLocalEdit 留 DesignBridge (跨域协调器: canvas + chat fallback + CLI), 经 canvasState.X reach-through。
//   deinit 留 DesignBridge (跨域协调器), 调 canvasState.cleanup()。

private let designCanvasLog = Logger(subsystem: "com.fusion.studio", category: "DesignCanvasService")

extension DesignCanvasState {

    func sendCanvasCommand(_ command: BridgeCommand) {
        guard let webView = canvasWebView else {
            designCanvasLog.warning("DesignCanvas: canvasWebView nil, command dropped")
            return
        }
        DesignCanvasView.sendCommand(command, to: webView)
    }

    // #372 OPS-13: 触发 fd-host-web 日志环形缓冲 dump。
    func dumpWasmLog(clear: Bool) {
        guard let webView = canvasWebView else {
            designCanvasLog.warning("DesignCanvas: dumpWasmLog skipped, canvasWebView nil")
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
        designCanvasLog.info("DesignCanvas: mutateCanvasNode id=\(nodeID) w=\(w?.description ?? "nil") h=\(h?.description ?? "nil")")
    }

    func setNodeLocked(_ nodeID: String, locked: Bool) {
        sendCanvasCommand(.mutateNode(nodeID: nodeID, x: nil, y: nil, w: nil, h: nil,
                                       fill: nil, stroke: nil, strokeWidth: nil, radius: nil,
                                       fontSize: nil, fontFamily: nil, opacity: locked ? 0.3 : 1.0))
        designCanvasLog.info("DesignCanvas: set node \(nodeID) locked=\(locked)")
    }

    func undo() {
        sendCanvasCommand(.undoAction)
        designCanvasLog.info("DesignCanvas: undo")
    }

    func redo() {
        sendCanvasCommand(.redoAction)
        designCanvasLog.info("DesignCanvas: redo")
    }

    func setNodeVisibility(_ nodeID: String, visible: Bool) {
        sendCanvasCommand(.setNodeVisibility(nodeID: nodeID, visible: visible))
        designCanvasLog.info("DesignCanvas: setNodeVisibility id=\(nodeID) visible=\(visible)")
    }

    func reorderNode(_ nodeID: String, newIndex: Int) {
        sendCanvasCommand(.reorderNode(nodeID: nodeID, newIndex: newIndex))
        designCanvasLog.info("DesignCanvas: reorderNode id=\(nodeID) newIndex=\(newIndex)")
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
                    designCanvasLog.info("DesignCanvas: deleted node \(nodeID)")
                }
                return
            }
        }
        designCanvasLog.warning("DesignCanvas: deleteNode — node \(nodeID) not found")
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
                    designCanvasLog.info("DesignCanvas: duplicated node \(nodeID) → \(newID)")
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
                    designCanvasLog.info("DesignCanvas: bringToFront node \(nodeID)")
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
                    designCanvasLog.info("DesignCanvas: sendToBack node \(nodeID)")
                }
                return
            }
        }
    }

    // MARK: - Partial Edit Helpers (applyLocalEdit 协调器调用, own-domain)

    func extractSelectedNodesJSON() -> String {
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

    func applyPartialEditResult(_ resultJSON: String) {
        guard let data = resultJSON.data(using: .utf8),
              let nodes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            designCanvasLog.error("DesignCanvas: applyPartialEditResult invalid JSON")
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
        designCanvasLog.info("DesignCanvas: applied partial edit to \(nodes.count) nodes")
    }

    // MARK: - Inspector Change Observer

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
        designCanvasLog.info("DesignCanvas: started observing inspector changes")
    }

    // MARK: - Reverse Code Watch (Fusion Code → Canvas)

    /// 启动反向监听：每 3 秒扫描 fusion-code IPC 目录的 style-change 消息。
    func startWatchingCodeChanges() {
        guard codeWatchTimer == nil else { return }
        codeWatchTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.pollCodeChanges()
        }
        designCanvasLog.info("DesignCanvas: code watch started (3s interval)")
    }

    func stopWatchingCodeChanges() {
        codeWatchTimer?.invalidate()
        codeWatchTimer = nil
        designCanvasLog.info("DesignCanvas: code watch stopped")
    }

    private func pollCodeChanges() {
        let ipcBase = NSHomeDirectory() + "/.fusion-ipc"
        let dir = ipcBase + "/fusion-code"
        Task { @MainActor in
            let parsed = await Task.detached(priority: .userInitiated) { () -> [[String: Any]] in
                let fm = FileManager.default
                guard let files = try? fm.contentsOfDirectory(atPath: dir).sorted() else { return [] }
                var collected = [[String: Any]]()
                for name in files {
                    let path = dir + "/" + name
                    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let action = json["action"] as? String,
                          action == "style-change" else {
                        continue
                    }
                    try? fm.removeItem(atPath: path)
                    guard let payload = json["payload"] as? [String: Any],
                          let mutations = payload["mutations"] as? [[String: Any]] else {
                        designCanvasLog.warning("DesignCanvas: style-change payload missing mutations")
                        continue
                    }
                    collected.append(contentsOf: mutations)
                }
                return collected
            }.value
            guard !parsed.isEmpty else { return }
            designCanvasLog.info("DesignCanvas: applying \(parsed.count) reverse mutations")
            for m in parsed {
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

    // MARK: - Cleanup (DesignBridge.deinit 调用)

    nonisolated func cleanup() {
        if let obs = mutateObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        codeWatchTimer?.invalidate()
        designCanvasLog.info("DesignCanvas: cleanup — observer removed, codeWatchTimer invalidated")
    }
}
