// Callers: ModuleDetailView routing.
// Affected API: DocGeneratorView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Foundation
import os.log

private let docGenLogger = Logger(subsystem: "com.fusion.studio", category: "DocGeneratorView")

// MARK: - 文档类型

enum DocGenType: String, CaseIterable {
    case api
    case arch
    case changelog
    case readme
    case module
    case full

    var localizedName: String {
        switch self {
        case .api:       return I18nManager.shared.t(.docgen_type_api)
        case .arch:      return I18nManager.shared.t(.docgen_type_arch)
        case .changelog: return I18nManager.shared.t(.docgen_type_changelog)
        case .readme:    return I18nManager.shared.t(.docgen_type_readme)
        case .module:    return I18nManager.shared.t(.docgen_type_module)
        case .full:      return I18nManager.shared.t(.docgen_type_full)
        }
    }

    var icon: String {
        switch self {
        case .api:       return "doc.text.magnifyingglass"
        case .arch:      return "square.3.layers.3d"
        case .changelog: return "clock.arrow.circlepath"
        case .readme:    return "doc.richtext"
        case .module:    return "square.grid.3x2"
        case .full:      return "book.closed"
        }
    }
    var description: String {
        switch self {
        case .api:       return I18nManager.shared.t(.docgen_desc_api)
        case .arch:      return I18nManager.shared.t(.docgen_desc_arch)
        case .changelog: return I18nManager.shared.t(.docgen_desc_changelog)
        case .readme:    return I18nManager.shared.t(.docgen_desc_readme)
        case .module:    return I18nManager.shared.t(.docgen_desc_module)
        case .full:      return I18nManager.shared.t(.docgen_desc_full)
        }
    }
}

// MARK: - 文档生成配置

struct DocGenConfig {
    var includePrivate: Bool = false
    var includeCodeExamples: Bool = true
    var outputFormat: OutputFormat = .markdown
    var includeDiagrams: Bool = true
    var includeChangelog: Bool = true
    var maxDepth: Int = 3

    enum OutputFormat: String, CaseIterable {
        case markdown  = "Markdown"
        case html      = "HTML"
        case pdf       = "PDF"
        case json      = "JSON"

        var icon: String {
            switch self {
            case .markdown: return "doc.richtext"
            case .html:     return "globe"
            case .pdf:      return "doc.viewfinder"
            case .json:     return "curlybraces"
            }
        }
    }
}

// MARK: - 文档生成器

class DocGenerator: ObservableObject {
    static let shared = DocGenerator()

    @Published var isGenerating = false
    @Published var progress: Double = 0
    @Published var currentFile: String = ""
    @Published var generatedFiles: [GeneratedDoc] = []
    @Published var config = DocGenConfig()
    @Published var log: [String] = []

    struct GeneratedDoc: Identifiable {
        let id = UUID()
        let name: String
        let type: DocGenType
        let path: String
        let size: Int64
        let generatedAt: Date
        let format: DocGenConfig.OutputFormat

        var sizeFormatted: String {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
    }

    // MARK: - 生成文档

    func generate(type: DocGenType) {
        isGenerating = true
        progress = 0
        log = []
        let name = type.localizedName
        let startMsg = I18nManager.shared.tf(.docgen_log_start, name)
        log.append(startMsg)
        // 审计0827 #13: log 无界 append, 长运行累积, cap 500 复用 PERF-3 ragResults 范式。
        if log.count > 500 { log.removeFirst(log.count - 500) }
        docGenLogger.info("start generate type=\(type.rawValue, privacy: .public)")

        switch type {
        case .api:       generateAPIDocs()
        case .arch:      generateArchDocs()
        case .changelog: generateChangelog()
        case .readme:    generateREADME()
        case .module:    generateModuleDocs()
        case .full:      generateFullDocs()
        }
    }

    private func generateAPIDocs() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_scan_ipc), 0.1),
            (I18nManager.shared.t(.docgen_step_parse_rpc), 0.3),
            (I18nManager.shared.t(.docgen_step_gen_request), 0.5),
            (I18nManager.shared.t(.docgen_step_gen_errors), 0.7),
            (I18nManager.shared.t(.docgen_step_gen_client), 0.85),
            (I18nManager.shared.t(.docgen_step_write_file), 1.0),
        ], outputName: "api-reference.md", type: .api)
    }

    private func generateArchDocs() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_scan_structure), 0.1),
            (I18nManager.shared.t(.docgen_step_parse_deps), 0.3),
            (I18nManager.shared.t(.docgen_step_gen_arch_diagram), 0.5),
            (I18nManager.shared.t(.docgen_step_gen_module_desc), 0.7),
            (I18nManager.shared.t(.docgen_step_gen_dataflow), 0.85),
            (I18nManager.shared.t(.docgen_step_write_file), 1.0),
        ], outputName: "architecture.md", type: .arch)
    }

    private func generateChangelog() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_read_git), 0.1),
            (I18nManager.shared.t(.docgen_step_parse_commits), 0.3),
            (I18nManager.shared.t(.docgen_step_classify_changes), 0.5),
            (I18nManager.shared.t(.docgen_step_gen_versions), 0.7),
            (I18nManager.shared.t(.docgen_step_gen_changelog), 0.9),
            (I18nManager.shared.t(.docgen_step_write_file), 1.0),
        ], outputName: "CHANGELOG.md", type: .changelog)
    }

    private func generateREADME() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_scan_project), 0.1),
            (I18nManager.shared.t(.docgen_step_gen_project_desc), 0.3),
            (I18nManager.shared.t(.docgen_step_gen_features), 0.5),
            (I18nManager.shared.t(.docgen_step_gen_install), 0.7),
            (I18nManager.shared.t(.docgen_step_gen_usage), 0.85),
            (I18nManager.shared.t(.docgen_step_write_file), 1.0),
        ], outputName: "README.md", type: .readme)
    }

    private func generateModuleDocs() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_scan_modules), 0.1),
            (I18nManager.shared.t(.docgen_step_parse_module_api), 0.2),
            (I18nManager.shared.t(.docgen_step_gen_module_desc), 0.5),
            (I18nManager.shared.t(.docgen_step_gen_index), 0.9),
            (I18nManager.shared.t(.docgen_step_write_file), 1.0),
        ], outputName: "modules/index.md", type: .module)
    }

    private func generateFullDocs() {
        simulateGeneration(steps: [
            (I18nManager.shared.t(.docgen_step_gen_request), 0.15),
            (I18nManager.shared.t(.docgen_step_gen_arch_diagram), 0.3),
            (I18nManager.shared.t(.docgen_step_gen_changelog), 0.45),
            (I18nManager.shared.t(.docgen_step_gen_project_desc), 0.55),
            (I18nManager.shared.t(.docgen_step_gen_module_desc), 0.7),
            (I18nManager.shared.t(.docgen_step_gen_user_guide), 0.8),
            (I18nManager.shared.t(.docgen_step_gen_dev_guide), 0.9),
            (I18nManager.shared.t(.docgen_step_gen_index), 1.0),
        ], outputName: "index.html", type: .full)
    }

    private func simulateGeneration(steps: [(String, Double)], outputName: String, type: DocGenType) {
        var stepIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard stepIndex < steps.count else {
                timer.invalidate()
                self.finishGeneration(outputName: outputName, type: type)
                return
            }
            let (msg, prog) = steps[stepIndex]
            self.currentFile = msg
            self.progress = prog
            self.log.append("  [\(Int(prog * 100))%] \(msg)")
            // 审计0827 #13: log 无界 append (进度循环高频), cap 500 复用 PERF-3 ragResults 范式。
            if self.log.count > 500 { self.log.removeFirst(self.log.count - 500) }
            stepIndex += 1
        }
    }

    private func finishGeneration(outputName: String, type: DocGenType) {
        let outputDir = docsOutputDir()
        let filePath = outputDir.appendingPathComponent(outputName)

        let content = generateSampleContent(type: type, name: outputName)
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        try? content.write(to: filePath, atomically: true, encoding: .utf8)

        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath.path)
        let size = attrs?[.size] as? Int64 ?? 0

        let doc = GeneratedDoc(
            name: outputName,
            type: type,
            path: filePath.path,
            size: size,
            generatedAt: Date(),
            format: config.outputFormat
        )
        generatedFiles.append(doc)
        // 审计0827 #13: generatedFiles 无界 append, cap 200 复用 PERF-3 ragResults 范式。
        if generatedFiles.count > 200 { generatedFiles.removeFirst(generatedFiles.count - 200) }
        let doneMsg = I18nManager.shared.tf(.docgen_log_done, outputName, doc.sizeFormatted)
        log.append(doneMsg)
        // 审计0827 #13: log 无界 append, cap 500 复用 PERF-3 ragResults 范式。
        if log.count > 500 { log.removeFirst(log.count - 500) }
        docGenLogger.info("generate done name=\(outputName, privacy: .public) size=\(size)")

        isGenerating = false
        objectWillChange.send()
    }

    private func generateSampleContent(type: DocGenType, name: String) -> String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        let genTime = I18nManager.shared.tf(.docgen_sample_api_gen_time, date)
        switch type {
        case .api:
            return """
            # \(I18nManager.shared.t(.docgen_sample_api_title))

            > \(genTime)
            > \(I18nManager.shared.t(.docgen_sample_api_version))

            ## \(I18nManager.shared.t(.docgen_sample_api_section))

            ### env.health_check
            \(I18nManager.shared.t(.docgen_sample_api_env_check))

            \(I18nManager.shared.t(.docgen_md_request)): `{"jsonrpc": "2.0", "id": 1, "method": "env.health_check"}`
            \(I18nManager.shared.t(.docgen_md_response)): `{"jsonrpc": "2.0", "id": 1, "result": [...]}`

            ### env.repair
            \(I18nManager.shared.t(.docgen_sample_api_env_repair))

            \(I18nManager.shared.t(.docgen_md_params)): `{"item_id": "mlx"}`
            \(I18nManager.shared.t(.docgen_md_response)): `{"jsonrpc": "2.0", "id": 1, "result": {"success": true}}`

            ### mlx.status
            \(I18nManager.shared.t(.docgen_sample_api_mlx_status))

            \(I18nManager.shared.t(.docgen_md_response)): `{"jsonrpc": "2.0", "id": 1, "result": {"running": true, "model": "..."}}`
            """
        case .arch:
            return """
            # \(I18nManager.shared.t(.docgen_sample_arch_title))

            > \(genTime)

            \(I18nManager.shared.t(.docgen_md_layers))

            ```
            📱 \(I18nManager.shared.t(.docgen_sample_arch_layer_app))
            🛠️ \(I18nManager.shared.t(.docgen_sample_arch_layer_container))
            🔗 \(I18nManager.shared.t(.docgen_sample_arch_layer_bridge))
            ⚙️ \(I18nManager.shared.t(.docgen_sample_arch_layer_service))
            🧠 \(I18nManager.shared.t(.docgen_sample_arch_layer_base))
            ```

            \(I18nManager.shared.t(.docgen_md_deps))

            - Design → IPC → Code
            - Code → IPC → Simulation
            - Simulation → IPC → Design
            """
        case .changelog:
            return """
            # \(I18nManager.shared.t(.docgen_sample_changelog_title))

            ## [1.0.0] - \(date)

            \(I18nManager.shared.t(.docgen_sample_changelog_added))
            \(I18nManager.shared.t(.docgen_md_changelog_bullet1))
            \(I18nManager.shared.t(.docgen_md_changelog_bullet2))
            \(I18nManager.shared.t(.docgen_md_changelog_bullet3))

            \(I18nManager.shared.t(.docgen_sample_changelog_fixed))
            \(I18nManager.shared.t(.docgen_md_changelog_fix))
            """
        case .readme:
            return """
            # \(I18nManager.shared.t(.docgen_sample_readme_title))

            > \(genTime)

            \(I18nManager.shared.t(.docgen_sample_readme_desc))

            \(I18nManager.shared.t(.docgen_sample_readme_features))

            - \(I18nManager.shared.t(.docgen_sample_readme_feat_modules))
            - \(I18nManager.shared.t(.docgen_sample_readme_feat_offline))
            - \(I18nManager.shared.t(.docgen_sample_readme_feat_native))
            \(I18nManager.shared.t(.docgen_md_readme_bullet1))
            \(I18nManager.shared.t(.docgen_md_readme_bullet2))
            \(I18nManager.shared.t(.docgen_md_readme_bullet3))
            """
        case .module:
            return """
            # \(I18nManager.shared.t(.docgen_sample_module_title))

            > \(genTime)

            \(I18nManager.shared.t(.docgen_md_design_h))
            \(I18nManager.shared.t(.docgen_sample_module_design))

            \(I18nManager.shared.t(.docgen_md_code_h))
            \(I18nManager.shared.t(.docgen_sample_module_code))

            \(I18nManager.shared.t(.docgen_md_sim_h))
            \(I18nManager.shared.t(.docgen_sample_module_sim))

            \(I18nManager.shared.t(.docgen_md_hub_h))
            \(I18nManager.shared.t(.docgen_sample_module_hub))

            \(I18nManager.shared.t(.docgen_md_cli_h))
            \(I18nManager.shared.t(.docgen_sample_module_cli))
            """
        case .full:
            return """
            <!DOCTYPE html>
            <html>
            <head><title>\(I18nManager.shared.t(.docgen_sample_full_title))</title>
            <style>
            body { font-family: -apple-system; max-width: 800px; margin: auto; padding: 2em; }
            h1 { color: #7c3aed; }
            </style></head>
            <body>
            <h1>\(I18nManager.shared.t(.docgen_sample_full_title))</h1>
            <p>\(genTime)</p>
            <ul>
            <li><a href="api-reference.md">\(I18nManager.shared.t(.docgen_sample_full_api))</a></li>
            <li><a href="architecture.md">\(I18nManager.shared.t(.docgen_sample_full_arch))</a></li>
            <li><a href="CHANGELOG.md">\(I18nManager.shared.t(.docgen_sample_full_changelog))</a></li>
            <li><a href="README.md">README</a></li>
            <li><a href="modules/index.md">\(I18nManager.shared.t(.docgen_type_module))</a></li>
            </ul>
            </body></html>
            """
        }
    }

    private func docsOutputDir() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent("FusionStudio/GeneratedDocs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func clearHistory() {
        generatedFiles.removeAll()
        log.removeAll()
        objectWillChange.send()
    }

    func openOutputFolder() {
        NSWorkspace.shared.open(docsOutputDir())
    }
}

// MARK: - 文档生成面板

struct DocGeneratorView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var generator = DocGenerator.shared
    @State private var selectedType: DocGenType = .api

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DocGenType.allCases, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            Label(type.localizedName, systemImage: type.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(selectedType == type ? .accentColor : nil)
                    }
                }
                .padding(8)
            }
            .background(theme.surfaceSecondary)

            Divider()

            HSplitView {
                VStack(spacing: 12) {
                    GroupBox(I18nManager.shared.t(.docgen_cfg_title)) {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker(I18nManager.shared.t(.docgen_cfg_output_format), selection: $generator.config.outputFormat) {
                                ForEach(DocGenConfig.OutputFormat.allCases, id: \.self) { fmt in
                                    Label(fmt.rawValue, systemImage: fmt.icon).tag(fmt)
                                }
                            }
                            Toggle(I18nManager.shared.t(.docgen_cfg_include_private), isOn: $generator.config.includePrivate)
                            Toggle(I18nManager.shared.t(.docgen_cfg_include_examples), isOn: $generator.config.includeCodeExamples)
                            Toggle(I18nManager.shared.t(.docgen_cfg_include_diagrams), isOn: $generator.config.includeDiagrams)
                            Text(I18nManager.shared.tf(.docgen_cfg_max_depth, generator.config.maxDepth))
                            Stepper("", value: $generator.config.maxDepth, in: 1...5).labelsHidden()
                        }
                        .padding(8)
                    }

                    Button(action: { generator.generate(type: selectedType) }) {
                        Label(I18nManager.shared.tf(.docgen_btn_generate, selectedType.localizedName), systemImage: "doc.badge.gearshape")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(generator.isGenerating)

                    if generator.isGenerating {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: generator.progress)
                            Text(generator.currentFile)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }

                    if !generator.generatedFiles.isEmpty {
                        Button(I18nManager.shared.t(.docgen_btn_open_output)) { generator.openOutputFolder() }
                            .buttonStyle(.bordered)
                    }

                    Spacer()

                    if !generator.log.isEmpty {
                        GroupBox(I18nManager.shared.t(.docgen_log_title)) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(generator.log, id: \.self) { line in
                                        Text(line)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(line.hasPrefix("✅") ? .green : .secondary)
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                }
                .padding()
                .frame(minWidth: 250, maxWidth: 300)

                VStack {
                    if generator.generatedFiles.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text(I18nManager.shared.t(.docgen_empty_hint))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(generator.generatedFiles.reversed()) { doc in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Image(systemName: doc.type.icon)
                                            .foregroundColor(.accentColor)
                                        Text(doc.name)
                                            .font(.headline)
                                        Spacer()
                                        Text(doc.sizeFormatted)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text(doc.type.localizedName)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .background(Color.accentColor.opacity(0.1))
                                            .cornerRadius(3)
                                        Text(doc.generatedAt, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(doc.format.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text(doc.path)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Button(I18nManager.shared.t(.docgen_btn_open)) { NSWorkspace.shared.open(URL(fileURLWithPath: doc.path)) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        Button(I18nManager.shared.t(.docgen_btn_show)) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: doc.path)]) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .frame(minWidth: 300)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(I18nManager.shared.t(.docgen_btn_clear_history)) { generator.clearHistory() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button(I18nManager.shared.t(.docgen_btn_open_output)) { generator.openOutputFolder() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}
