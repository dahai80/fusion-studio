import Foundation
import os.log

// ARCH-1 Phase 6 (审计product-0906 P1): DesignSkill 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignChatPanel.handleSkillTemplate/skillPartialEdit/DesignLintPanel.skillLint 0 改)。
//   CLI only (generate/lint/diff/health/theme), 0 IPC → 无 ipcClient ref。
//   跨域写 canvas (renderDocumentToCanvas/applyPartialEditResult/sendCanvasCommand/extractSelectedNodesJSON/
//   lastRenderedDocumentJSON) 经 self.bridge?.X reach-through。chat (parseHtmlFromPenOutput/parseHtmlViaCLI)
//   经 self.bridge?.X reach-through。CLI 助手 (resolveCLIPath/runFusionDesign) 留 DesignBridge → bridge?.X。
//   Self.runCLIProcess (nonisolated static) → DesignBridge.runCLIProcess。

private let designSkillLog = Logger(subsystem: "com.fusion.studio", category: "DesignSkillService")

extension DesignSkillState {

    func skillTextToUI(prompt: String, pageName: String = "Home") {
        isSkillRunning = true
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                DesignBridge.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", prompt, "--page", pageName, "--model", model, "--endpoint", endpoint]
                )
            }.value
            if result.exitCode == 0 {
                lastSkillOutput = result.output
                if let penDocJSON = result.output.data(using: String.Encoding.utf8),
                   let penDoc = try? JSONSerialization.jsonObject(with: penDocJSON) as? [String: Any],
                   let pages = penDoc["pages"] as? [[String: Any]] {
                    bridge?.renderDocumentToCanvas(result.output)
                    designSkillLog.info("DesignSkill: text_to_ui rendered, \(result.output.count) chars")
                } else {
                    designSkillLog.warning("DesignSkill: text_to_ui output not valid PenDocument, falling back to parse-html")
                    if let html = bridge?.chatState.parseHtmlFromPenOutput(result.output) {
                        if let docJSON = await bridge?.parseHtmlViaCLI(html) {
                            bridge?.renderDocumentToCanvas(docJSON)
                        }
                    }
                }
            } else {
                designSkillLog.error("DesignSkill: text_to_ui failed: \(result.error)")
            }
            isSkillRunning = false
        }
    }

    func skillImageToUI(imagePath: String, hint: String, pageName: String = "Home") {
        isSkillRunning = true
        let prompt = DesignPrompts.dispatcher.skillImageToUIPrompt(imagePath, hint, pageName)
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                DesignBridge.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", prompt, "--page", pageName, "--model", model, "--endpoint", endpoint]
                )
            }.value
            if result.exitCode == 0 {
                lastSkillOutput = result.output
                bridge?.renderDocumentToCanvas(result.output)
                designSkillLog.info("DesignSkill: image_to_ui rendered")
            } else {
                designSkillLog.error("DesignSkill: image_to_ui failed: \(result.error)")
            }
            isSkillRunning = false
        }
    }

    func skillPartialEdit(nodesJSON: String, instruction: String) {
        isSkillRunning = true
        let effectiveNodes: String
        if nodesJSON.isEmpty || nodesJSON == "[]" {
            effectiveNodes = bridge?.canvasState.extractSelectedNodesJSON() ?? "[]"
        } else {
            effectiveNodes = nodesJSON
        }
        let prompt = DesignPrompts.dispatcher.skillPartialEditPrompt(effectiveNodes, instruction)
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                DesignBridge.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", prompt, "--page", "PartialEdit", "--model", model, "--endpoint", endpoint],
                    stdin: effectiveNodes
                )
            }.value
            if result.exitCode == 0, !result.output.isEmpty {
                lastSkillOutput = result.output
                if let data = result.output.data(using: .utf8),
                   let _ = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    bridge?.canvasState.applyPartialEditResult(result.output)
                    designSkillLog.info("DesignSkill: partial_edit applied, \(result.output.count) chars")
                } else {
                    bridge?.renderDocumentToCanvas(result.output)
                    designSkillLog.info("DesignSkill: partial_edit rendered as document")
                }
            } else {
                designSkillLog.error("DesignSkill: partial_edit failed: \(result.error)")
            }
            isSkillRunning = false
        }
    }

    func skillSimPanel(prompt: String, pageName: String = "Home") {
        isSkillRunning = true
        let simPrompt = DesignPrompts.dispatcher.skillSimPanelPrompt(prompt)
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                DesignBridge.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", simPrompt, "--page", pageName, "--model", model, "--endpoint", endpoint]
                )
            }.value
            if result.exitCode == 0 {
                lastSkillOutput = result.output
                bridge?.renderDocumentToCanvas(result.output)
                designSkillLog.info("DesignSkill: sim_panel rendered")
            } else {
                designSkillLog.error("DesignSkill: sim_panel failed: \(result.error)")
            }
            isSkillRunning = false
        }
    }

    func skillSpecDoc(prompt: String) {
        isSkillRunning = true
        let specPrompt = DesignPrompts.dispatcher.skillSpecDocPrompt(prompt)
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                DesignBridge.runCLIProcess(
                    cliPath: cliPath,
                    args: ["generate", "--prompt", specPrompt, "--page", "SpecDoc", "--model", model, "--endpoint", endpoint]
                )
            }.value
            if result.exitCode == 0 {
                lastSkillOutput = result.output
                if let html = bridge?.chatState.parseHtmlFromPenOutput(result.output) {
                    bridge?.renderDocumentToCanvas(html)
                } else {
                    bridge?.renderDocumentToCanvas(result.output)
                }
                designSkillLog.info("DesignSkill: spec_doc generated")
            } else {
                designSkillLog.error("DesignSkill: spec_doc failed: \(result.error)")
            }
            isSkillRunning = false
        }
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
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        let specs: [(idx: Int, pageName: String, pagePrompt: String)] = names.enumerated().map { idx, pageName in
            (idx, pageName, DesignPrompts.dispatcher.pageFlowPagePrompt(flowPrompt, idx, pageName))
        }
        Task { @MainActor in
            for (idx, pageName, pagePrompt) in specs {
                let result = await Task.detached(priority: .userInitiated) {
                    DesignBridge.runCLIProcess(
                        cliPath: cliPath,
                        args: ["generate", "--prompt", pagePrompt, "--page", pageName, "--model", model, "--endpoint", endpoint]
                    )
                }.value
                if result.exitCode == 0 {
                    variantPages.append(VariantPage(
                        id: "pageflow-\(idx)",
                        title: pageName,
                        documentJSON: result.output
                    ))
                    designSkillLog.info("DesignSkill: page_flow[\(idx)] page=\(pageName) done")
                }
            }
            if let first = variantPages.first {
                bridge?.renderDocumentToCanvas(first.documentJSON)
            }
            isSkillRunning = false
        }
    }

    func skillMultiVariants(prompt: String, styles: [String]? = nil, pageName: String = "Home") {
        isSkillRunning = true
        variantPages.removeAll()
        let resolvedStyles = styles ?? DesignPrompts.dispatcher.multiVariantsDefaultStyles
        let config = FusionConfig.shared
        let model = config.defaultModel(for: .artifacts)
        let endpoint = config.mlxBaseURL
        let cliPath = bridge?.resolveCLIPath() ?? ""
        let specs: [(idx: Int, style: String, styledPrompt: String)] = resolvedStyles.enumerated().map { idx, style in
            (idx, style, DesignPrompts.dispatcher.multiVariantsStyledPrompt(prompt, style))
        }
        Task { @MainActor in
            for (idx, style, styledPrompt) in specs {
                let result = await Task.detached(priority: .userInitiated) {
                    DesignBridge.runCLIProcess(
                        cliPath: cliPath,
                        args: ["generate", "--prompt", styledPrompt, "--page", "\(pageName)-\(style)", "--model", model, "--endpoint", endpoint]
                    )
                }.value
                if result.exitCode == 0 {
                    variantPages.append(VariantPage(
                        id: "variant-\(idx)",
                        title: style,
                        documentJSON: result.output
                    ))
                    designSkillLog.info("DesignSkill: multi_variants[\(idx)] style=\(style) done")
                }
            }
            isSkillRunning = false
        }
    }

    // 审计0907 P0-3: 改 async — runFusionDesignAsync 180s CLI 跑后台 Task.detached, 不冻结 MainActor。
    func skillLint(documentJSON: String? = nil, designSystem: String = "apple-hig", fix: Bool = false, dryRun: Bool = false) async -> [DesignLintIssue] {
        let docJSON = documentJSON ?? bridge?.lastRenderedDocumentJSON ?? ""
        guard !docJSON.isEmpty else { return [] }
        guard let tmpPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_lint", contents: Data(docJSON.utf8)) else {
            designSkillLog.error("DesignSkill: lint tmp write failed")
            return []
        }
        var args = ["lint", "--input", tmpPath, "--design-system", designSystem]
        if fix { args.append("--fix") }
        if dryRun { args.append("--dry-run") }
        // 审计0907 P0-3: 旧 sync runFusionDesign 在 MainActor 阻塞 180s。改 async。
        let result = await (bridge?.runFusionDesignAsync(args) ?? (output: "", error: "bridge nil", exitCode: -1))
        try? FileManager.default.removeItem(atPath: tmpPath)
        guard result.exitCode == 0, !result.output.isEmpty else {
            designSkillLog.error("DesignSkill: lint failed: \(result.error)")
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
            designSkillLog.info("DesignSkill: lint found \(parsed.count) issues")
            return parsed
        }
        return []
    }

    // 审计0907 P0-3: 改 async。
    func skillDiff(oldJSON: String, newJSON: String) async -> [DesignDiffEntry] {
        guard let oldPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_diff_old", contents: Data(oldJSON.utf8)),
              let newPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_diff_new", contents: Data(newJSON.utf8)) else {
            designSkillLog.error("DesignSkill: diff tmp write failed")
            return []
        }
        let result = await (bridge?.runFusionDesignAsync(["diff", "--old", oldPath, "--new", newPath]) ?? (output: "", error: "bridge nil", exitCode: -1))
        try? FileManager.default.removeItem(atPath: oldPath)
        try? FileManager.default.removeItem(atPath: newPath)
        guard result.exitCode == 0 else {
            designSkillLog.error("DesignSkill: diff failed: \(result.error)")
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
            designSkillLog.info("DesignSkill: diff found \(entries.count) changes")
            return entries
        }
        return []
    }

    // 审计0907 P0-3: 改 async。
    func skillHealthCheck(endpoint: String = FusionConfig.shared.mlxBaseURL) async -> [String: Any]? {
        let result = await (bridge?.runFusionDesignAsync(["health", "--endpoint", endpoint]) ?? (output: "", error: "bridge nil", exitCode: -1))
        guard result.exitCode == 0 else { return nil }
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return json
        }
        return nil
    }

    // 审计0907 P0-3: 改 async。
    func skillTheme(designSystem: String = "apple-hig", mode: String = "dark") async -> String? {
        let result = await (bridge?.runFusionDesignAsync(["theme", "--design-system", designSystem, "--mode", mode]) ?? (output: "", error: "bridge nil", exitCode: -1))
        guard result.exitCode == 0, !result.output.isEmpty else { return nil }
        return result.output
    }
}
