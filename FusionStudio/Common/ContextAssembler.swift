// Callers: AgentBridge.infer() and AgentBridge.inferStream() — assemble system prompt before sending to LLM.
// Affected API: ContextAssembler.shared.assemble() returns String.
// Data schemas: FusionProject, KnowledgeFile, ProjectSettings.
// User instruction: "立即落地fusion projects"

import Foundation
import os.log

private let ctxLog = Logger(subsystem: "com.fusion.studio", category: "ContextAssembler")

class ContextAssembler {
    static let shared = ContextAssembler()

    private(set) var ipcClient: IPCClient?

    func setIPCClient(_ client: IPCClient) {
        ipcClient = client
    }

    private let maxKnowledgeDirectChars = 8000
    private let maxClaudeMdChars = 6000
    private let maxStructureLines = 80

    // ARCH-5 (审计product-0905 P1): 文件 I/O (CLAUDE.md/knowledge/目录扫描) 移出 MainActor。
    // nonisolated: 本类无 actor 隔离, ipcClient 仅 init 期 set, 读线程安全。标记 nonisolated 显式脱离 MainActor。
    nonisolated func assemble(project: FusionProject?, query: String? = nil) -> String {
        var parts: [String] = []
        parts.append("You are Fusion Studio AI assistant, running locally on Apple Silicon. All inference is offline.")

        guard let project = project else {
            return parts.joined(separator: "\n\n")
        }

        if project.hasInstructions {
            parts.append("## Project Instructions\n\(project.customInstructions)")
            ctxLog.info("Assembled custom instructions: \(project.customInstructions.count) chars")
        }

        if project.settings.autoLoadClaudeMd {
            let claudeMd = loadClaudeMd(from: project.rootPath)
            if !claudeMd.isEmpty {
                let truncated = truncate(claudeMd, maxChars: maxClaudeMdChars)
                parts.append("## Project CLAUDE.md\n\(truncated)")
                ctxLog.info("Assembled CLAUDE.md: \(claudeMd.count) chars")
            }
        }

        let knowledgeContext = assembleKnowledge(project.knowledgeFiles, query: query)
        if !knowledgeContext.isEmpty {
            parts.append("## Project Knowledge\n\(knowledgeContext)")
            ctxLog.info("Assembled knowledge: \(knowledgeContext.count) chars from \(project.knowledgeFiles.count) files")
        }

        if project.settings.autoScanKnowledge {
            let structure = summarizeProjectStructure(project.rootPath)
            if !structure.isEmpty {
                parts.append("## Project Structure\n\(structure)")
            }
        }

        let result = parts.joined(separator: "\n\n")
        ctxLog.info("Context assembled: \(result.count) chars total")
        return result
    }

    // ARCH-5: assembleWithRAG async — assemble (含全部磁盘 I/O) 在 Task.detached 跑, 不卡 MainActor。
    func assembleWithRAG(project: FusionProject?, query: String) async -> String {
        let proj = project
        let q = query
        var base = await Task.detached(priority: .userInitiated) {
            return Self.shared.assemble(project: proj, query: q)
        }.value

        let ragResults = await searchKnowledge(query: query, limit: 5)
        if !ragResults.isEmpty {
            var ragSection = "## Relevant Knowledge (RAG)\n"
            for (idx, result) in ragResults.enumerated() {
                ragSection += "### Result \(idx + 1)\n"
                if let content = result["content"] as? String {
                    ragSection += truncate(content, maxChars: 2000) + "\n"
                }
                if let scope = result["scope"] as? String, !scope.isEmpty {
                    ragSection += "Scope: \(scope)\n"
                }
            }
            base += "\n\n" + ragSection
            ctxLog.info("RAG enhanced context: \(ragResults.count) results")
        }

        return base
    }

    func loadClaudeMd(from rootPath: String) -> String {
        let candidates = ["CLAUDE.md", "claude.md", ".claude.md"]
        for name in candidates {
            let url = URL(fileURLWithPath: rootPath).appendingPathComponent(name)
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                ctxLog.info("Found \(name) at \(rootPath)")
                return content
            }
        }
        return ""
    }

    func assembleKnowledge(_ files: [KnowledgeFile], query: String?) -> String {
        guard !files.isEmpty else { return "" }
        var sections: [String] = []
        for file in files {
            // 审计0827 #2: knowledgeFiles 路径可能来自导入项目, 防 symlink/.. 越界读, validateFilePath 拒则跳过。
            guard SecurityManager.shared.validateFilePath(file.filePath) else { continue }
            guard let content = try? String(contentsOfFile: file.filePath, encoding: .utf8) else { continue }
            let truncated = truncate(content, maxChars: maxKnowledgeDirectChars)
            sections.append("### \(file.fileName)\n\(truncated)")
        }
        return sections.joined(separator: "\n\n")
    }

    func summarizeProjectStructure(_ rootPath: String) -> String {
        let root = URL(fileURLWithPath: rootPath)
        let fm = FileManager.default
        var lines: [String] = []

        func scan(_ url: URL, prefix: String, depth: Int) {
            guard depth < 3, lines.count < maxStructureLines else { return }
            guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: [.skipsHiddenFiles]) else { return }
            let sorted = contents.sorted { $0.lastPathComponent < $1.lastPathComponent }
            for item in sorted {
                let name = item.lastPathComponent
                if skipNames.contains(name) { continue }
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    lines.append("\(prefix)\(name)/")
                    scan(item, prefix: prefix + "  ", depth: depth + 1)
                } else {
                    lines.append("\(prefix)\(name)")
                }
            }
        }

        scan(root, prefix: "", depth: 0)
        return lines.joined(separator: "\n")
    }

    // MARK: - RAG via IPCClient

    private func searchKnowledge(query: String, limit: Int = 5) async -> [[String: Any]] {
        guard let client = ipcClient else {
            ctxLog.warning("IPCClient not set, skipping RAG search")
            return []
        }
        do {
            let result = try await client.knowledgeSearch(query: query, limit: limit)
            if let results = result["results"] as? [[String: Any]] {
                return results
            }
        } catch {
            ctxLog.warning("RAG search failed: \(error.localizedDescription)")
        }
        return []
    }

    // MARK: - Embedding via MLX HTTP API

    func getEmbedding(text: String, model: String = "bge-small-en-v1.5") async -> [Double]? {
        let port = getMLXPort()

        let url = URL(string: "http://127.0.0.1:\(port)/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "input": text,
            "model": model,
            "encoding_format": "float"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                ctxLog.warning("Embedding API returned non-200 status")
                return nil
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]],
               let first = dataArray.first,
               let embedding = first["embedding"] as? [Double] {
                ctxLog.info("Got embedding: \(embedding.count) dimensions")
                return embedding
            }
        } catch {
            ctxLog.warning("Embedding request failed: \(error.localizedDescription)")
        }
        return nil
    }

    private func getMLXPort() -> Int {
        return FusionConfig.shared.mlxPort
    }

    private func truncate(_ text: String, maxChars: Int) -> String {
        if text.count <= maxChars { return text }
        let idx = text.index(text.startIndex, offsetBy: maxChars)
        return String(text[..<idx]) + "\n... [truncated]"
    }

    private let skipNames: Set<String> = [
        ".git", "node_modules", ".venv", "venv", "__pycache__", ".build",
        "build", "DerivedData", ".swiftpm", "Pods", ".cargo", "target",
        "dist", ".next", ".nuxt", "out", ".cache"
    ]
}
