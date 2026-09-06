import AppKit
import Foundation
import os.log

// ARCH-1 Phase 8 (审计product-0906 P1): DesignExport 行为迁入。DesignBridge 留 1 行 stub 转发 (保外部签名:
//   DesignExportPanel.exportAsSwiftUI/copyExportedSwiftUI/exportAsCodegen/copyExportedCodegen/
//   batchExportPages/copyCurrentCode 0 改)。
//   跨域读 artifact (currentArtifactCode/Title) + canvas (lastRenderedDocumentJSON) + chat (errorMessage 写)
//   经 self.bridge?.X reach-through。ipcClient (SwiftUI export guard) 经 bridge?.ipcClient (Phase 7 internal)。
//   CLI 助手 resolveCLIPath (bridge?.X) + Self.runCLIProcess (DesignBridge.runCLIProcess static)。

private let designExportLog = Logger(subsystem: "com.fusion.studio", category: "DesignExportService")

extension DesignExportState {

    func copyCurrentCode() {
        guard let code = bridge?.artifactState.currentArtifactCode, !code.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        designExportLog.info("DesignExport: code copied to clipboard")
    }

    func exportAsSwiftUI() async {
        guard let code = bridge?.artifactState.currentArtifactCode, !code.isEmpty else { return }
        guard bridge?.ipcClient != nil else {
            bridge?.errorMessage = "IPCClient not initialized"
            return
        }

        isExportingSwiftUI = true
        let request = SwiftUIExporter.buildConversionRequest(
            htmlCode: code,
            title: bridge?.artifactState.currentArtifactTitle ?? ""
        )

        let config = FusionConfig.shared
        let baseURL = config.mlxBaseURL
        let apiKey = config.mlxResolvedApiKey
        guard let url = URL(string: "\(baseURL)/v1/chat/completions") else {
            bridge?.errorMessage = "Invalid MLX URL"
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
                designExportLog.info("DesignExport: SwiftUI export done, \(self.exportedSwiftUICode.count) chars")
            }
        } catch {
            bridge?.errorMessage = "SwiftUI export failed: \(error.localizedDescription)"
            designExportLog.error("DesignExport exportAsSwiftUI: \(error)")
        }
        isExportingSwiftUI = false
    }

    func copyExportedSwiftUI() {
        guard !exportedSwiftUICode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedSwiftUICode, forType: .string)
        designExportLog.info("DesignExport: SwiftUI code copied")
    }

    func exportAsCodegen(target: String, componentName: String) async {
        guard let documentJSON = bridge?.canvasState.lastRenderedDocumentJSON, !documentJSON.isEmpty else {
            bridge?.errorMessage = "No document to export"
            return
        }
        isExportingCodegen = true
        let cliPath = bridge?.resolveCLIPath() ?? ""
        guard !cliPath.isEmpty else {
            bridge?.errorMessage = "CLI not found"
            isExportingCodegen = false
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            DesignBridge.runCLIProcess(
                cliPath: cliPath,
                args: ["codegen", "--target", target, "--component", componentName],
                stdin: documentJSON
            )
        }.value
        if result.exitCode == 0 {
            exportedCodegenCode = result.output
            designExportLog.info("DesignExport: codegen export done, target=\(target), \(result.output.count) chars")
        } else {
            bridge?.errorMessage = "codegen failed: \(result.error)"
            designExportLog.error("DesignExport exportAsCodegen: \(result.error)")
        }
        isExportingCodegen = false
    }

    func copyExportedCodegen() {
        guard !exportedCodegenCode.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedCodegenCode, forType: .string)
        designExportLog.info("DesignExport: codegen code copied")
    }

    func batchExportPages(format: String, to outputDir: String) async {
        guard let documentJSON = bridge?.canvasState.lastRenderedDocumentJSON, !documentJSON.isEmpty else {
            bridge?.errorMessage = "No document to export"
            return
        }
        isBatchExporting = true
        batchExportResult = ""
        guard let tmpPath = FusionTempDir.shared.writeTmpFile(prefix: "fd_export", contents: Data(documentJSON.utf8)) else {
            bridge?.errorMessage = "export tmp write failed"
            isBatchExporting = false
            return
        }
        let cliPath = bridge?.resolveCLIPath() ?? ""
        guard !cliPath.isEmpty else {
            bridge?.errorMessage = "CLI not found"
            try? FileManager.default.removeItem(atPath: tmpPath)
            isBatchExporting = false
            return
        }
        let result = await Task.detached(priority: .userInitiated) {
            DesignBridge.runCLIProcess(
                cliPath: cliPath,
                args: ["export", "--input", tmpPath, "--format", format, "--out", outputDir]
            )
        }.value
        try? FileManager.default.removeItem(atPath: tmpPath)
        if result.exitCode == 0 {
            batchExportResult = result.output
            designExportLog.info("DesignExport: batch export done, format=\(format), result=\(result.output)")
        } else {
            bridge?.errorMessage = "export failed: \(result.error)"
            designExportLog.error("DesignExport batchExportPages: \(result.error)")
        }
        isBatchExporting = false
    }
}
