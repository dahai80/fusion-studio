// Callers: ModuleDetailView routing.
// Affected API: DocGeneratorView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI
import Foundation

// MARK: - 文档类型

enum DocGenType: String, CaseIterable {
    case api        = "API 文档"
    case arch       = "架构文档"
    case changelog  = "更新日志"
    case readme     = "README"
    case module     = "模块文档"
    case full       = "完整文档"

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
        case .api:       return "从源代码生成 JSON-RPC API 参考文档"
        case .arch:      return "从项目结构生成架构概览文档"
        case .changelog: return "从 Git 历史生成更新日志"
        case .readme:    return "生成项目 README 文档"
        case .module:    return "为每个模块生成独立文档"
        case .full:      return "生成完整文档集"
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
        log.append("开始生成 \(type.rawValue)...")

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
            ("扫描 IPC 方法定义...", 0.1),
            ("解析 JSON-RPC 2.0 接口...", 0.3),
            ("生成请求/响应示例...", 0.5),
            ("生成错误码文档...", 0.7),
            ("生成 Swift 客户端 API...", 0.85),
            ("写入文件...", 1.0),
        ], outputName: "api-reference.md", type: .api)
    }

    private func generateArchDocs() {
        simulateGeneration(steps: [
            ("扫描项目结构...", 0.1),
            ("解析模块依赖关系...", 0.3),
            ("生成架构图...", 0.5),
            ("生成模块描述...", 0.7),
            ("生成数据流文档...", 0.85),
            ("写入文件...", 1.0),
        ], outputName: "architecture.md", type: .arch)
    }

    private func generateChangelog() {
        simulateGeneration(steps: [
            ("读取 Git 历史...", 0.1),
            ("解析提交信息...", 0.3),
            ("分类变更类型...", 0.5),
            ("生成版本列表...", 0.7),
            ("生成更新日志...", 0.9),
            ("写入文件...", 1.0),
        ], outputName: "CHANGELOG.md", type: .changelog)
    }

    private func generateREADME() {
        simulateGeneration(steps: [
            ("扫描项目信息...", 0.1),
            ("生成项目描述...", 0.3),
            ("生成功能列表...", 0.5),
            ("生成安装说明...", 0.7),
            ("生成使用示例...", 0.85),
            ("写入文件...", 1.0),
        ], outputName: "README.md", type: .readme)
    }

    private func generateModuleDocs() {
        simulateGeneration(steps: [
            ("扫描模块列表...", 0.1),
            ("解析模块接口...", 0.2),
            ("生成 Design 模块文档...", 0.35),
            ("生成 Code 模块文档...", 0.45),
            ("生成 Simulation 模块文档...", 0.55),
            ("生成 Model Hub 模块文档...", 0.65),
            ("生成其他模块文档...", 0.8),
            ("生成索引文件...", 0.9),
            ("写入文件...", 1.0),
        ], outputName: "modules/index.md", type: .module)
    }

    private func generateFullDocs() {
        simulateGeneration(steps: [
            ("生成 API 文档...", 0.15),
            ("生成架构文档...", 0.3),
            ("生成更新日志...", 0.45),
            ("生成 README...", 0.55),
            ("生成模块文档...", 0.7),
            ("生成用户指南...", 0.8),
            ("生成开发指南...", 0.9),
            ("生成索引文件...", 1.0),
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
            stepIndex += 1
        }
    }

    private func finishGeneration(outputName: String, type: DocGenType) {
        let outputDir = docsOutputDir()
        let filePath = outputDir.appendingPathComponent(outputName)

        // 创建示例文档内容
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
        log.append("✅ 生成完成: \(outputName) (\(doc.sizeFormatted))")

        isGenerating = false
        objectWillChange.send()
    }

    private func generateSampleContent(type: DocGenType, name: String) -> String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        switch type {
        case .api:
            return """
            # Fusion Studio API 参考文档

            > 生成时间: \(date)
            > 版本: 1.0.0

            ## JSON-RPC 2.0 接口

            ### env.health_check
            运行环境健康检查。

            **请求**: `{"jsonrpc": "2.0", "id": 1, "method": "env.health_check"}`
            **响应**: `{"jsonrpc": "2.0", "id": 1, "result": [...]}`

            ### env.repair
            修复指定的环境检查项。

            **参数**: `{"item_id": "mlx"}`
            **响应**: `{"jsonrpc": "2.0", "id": 1, "result": {"success": true}}`

            ### mlx.status
            获取 MLX 推理服务状态。

            **响应**: `{"jsonrpc": "2.0", "id": 1, "result": {"running": true, "model": "..."}}`
            """
        case .arch:
            return """
            # Fusion Studio 架构文档

            > 生成时间: \(date)

            ## 分层架构

            ```
            📱 应用层 - SwiftUI 原生桌面
            🛠️ 容器层 - WKWebView + 原生组件
            🔗 桥接层 - Unix Domain Socket + JSON-RPC 2.0
            ⚙️ 服务层 - Rust/Python 守护进程
            🧠 底座层 - Apple Silicon 原生
            ```

            ## 模块依赖

            - Design → IPC → Code
            - Code → IPC → Simulation
            - Simulation → IPC → Design
            """
        case .changelog:
            return """
            # 更新日志

            ## [1.0.0] - \(date)

            ### 新增
            - 全部 10 个模块已完善
            - 局域网协作功能
            - 插件系统支持
            - 高级渲染/仿真参数调节

            ### 修复
            - 多项性能优化和内存泄漏修复

            ## [0.2.0] - 2026-07-10

            ### 新增
            - Simulation 仿真视图
            - Model Hub 模型管理
            - CLI 图形化面板

            ## [Unreleased]

            ## [0.1.30] - 2026-08-07

            ### 修复
            - Design 模块提交卡死/预览不可见/Canvas 修复：mlx 直连 401 鉴权回退到 settings.json、sendChat 实时 probe、预览白色背景、Canvas wasm Bundle.module 加载、runFusionDesign 管道死锁、Design RAG 暂禁+超时保护
            - Project 会话无 AI 回复：新增 generateReply 调 infer 回填 assistant 气泡（用户右对齐/AI 左对齐）
            - 严格健康检查：仅 HTTP 200-299 + UDS result 字段计为健康；9 子系统逐项探活 + 启动按钮；UDS 探活循环读至换行修复截断假阴性
            - Projects 删除 "project not found"：FusionProject.id let→var + fromDict 直赋值，移除 encode-decode 往返
            - Code 模块：聊天输入框移入中列；fusion-code offline 根因 /api/model/status 401，全量 HTTP+WS 加 Bearer
            - AI 鉴权自愈：probeMLXRunningStatus 401/403 读 settings.json auth.api_key 重试并持久化覆盖失效 env
            - Artifacts：X-API-Key header 从 FUSION_ARTIFACTS_API_KEY env 读取；artifactGet 解包嵌套 result + shareGet REST 404 fallback

            ### 新增
            - 侧边栏/IconRail 无障碍标识符 (closes #123)
            - fusion-model-hub 生命周期 start.sh + 公开健康端点 /api/v1/system/health

            ## [0.1.11] - 2026-07-31

            ### 新增
            - IPCClient REST 直连：GET /api/v1/share/{share_id} 公开分享只读渲染（Issue #26-B）
            - IPCClient SSE 事件流订阅：artifactEventStream / sessionEventStream + Last-Event-ID 断线重连（Issue #26-C）
            - IPCClient artifact.list_events 事件时间线 + artifact.update 乐观锁 expected_content_hash（Issue #26-A）
            - Artifacts GUI：ArtifactShareDialog 分享弹窗、ArtifactVersionHistory 版本历史
            - CoWork GUI：SessionSnapshotView 快照/Fork 交互
            - FSB 模块：FSBWorkspaceView 工作台 + FSBWorkflowEditorView DAG 编辑器
            - Projects GUI：ProjectInstructionsPanel Markdown/富文本双模 + 版本历史、KnowledgeBaseTreeView kb.list/add/remove
            - Foundation IPC 层：projectCall(UDS) / spaceCall(UDS) / artifactCall(HTTP) 路由
            - desk.* 47 方法全量路由至 /tmp/fusion-cowork.sock

            ### 修复
            - desk.* 方法从 env-daemon 转发修正为直连 desk_rpc socket（#38）
            - start.sh readiness check socket path 不再拼接（安全修复）

            ### 文档
            - docs/upstream-http-endpoints.md 全量更新：29 artifact.* 方法表 + REST 路由 + SSE 契约

            ## [0.1.10] - 2026-07-31

            ### 新增
            - 侧边栏菜单入口全量补齐：新增 Fusion-MLX 段（控制台/模型/调优/测评）、Multi-Node 段（集群总览/拓扑图/任务监控/告警中心/节点管理/提交任务/任务详情/路由策略/KV缓存/服务面板/多模态/分析/协作/外部集成/运维/部署），Agent 段追加知识库/自动化
            - 22 个原孤儿模块视图现可经侧边栏直达（排除训练/仿真/教育三个待补能力模块）
            - SectionContentView 新增 .mlx/.multiNode 段路由至 ModuleDetailView，IconRailView/FusionSidebarView 同步接入
            - CoWork space GUI：connector/apikey/style/analytics/alert tabs（Issue #17 P1/P2）+ 38 RPC + Team/Cron/Hooks/memory/safety/planner/context compact/usage/rag/tools/skills/research tabs（Issue #18）
            - 截图粘贴 + OCR + artifact 渲染 + skill/research/RAG watch（Issue #16）
            - 项目过滤器 + agent lifecycle + dashboard tab（Issue #15 + #17 P0）

            ### 修复
            - bug41: 消息对齐（用户右对齐/AI 左对齐）+ 编辑/重发按钮贴边 + 附件缩略图异步解码
            - bug35/37/38: 截图粘贴板、麦克风音量滑块、图片处理

            ## [0.1.9] - 2026-07-31

            ### 新增
            - FusionCodeProject 模型 + FusionCodeAPIClient.fetchProjects() 调用 GET /api/projects
            - ChatSessionStore 注入 FusionCodeAPIClient + fetchProjects() 包装方法
            - FusionStudioApp 启动时创建 FusionCodeAPIClient 实例并注入 ChatSessionStore
            - 上游 fusion-code API 集成验证通过 (/api/projects, /api/projects/:id/context, /api/sessions)

            ## [0.1.8] - 2026-07-31

            ### 新增
            - ChatPreset 枚举 (Code/Write/Create/Learn/Life) + systemPrompt 注入，快捷按钮对齐 Claude.ai L1
            - OutputStyle 枚举 (正式/极简/技术文档/学术) + stylePrompt 注入，+ 菜单 Use style 选择器
            - AttachmentData 附件模型 + 截图/文件附件 UI + 输入框附件条 + 消息气泡缩略图
            - AgentBridge.inferStream/infer messages 扩展 [[String:Any]] 支持多模态 + webSearch 参数
            - ChatSessionData.projectId 字段 + Project 选择器 + 关联指示器
            - BridgeError.userMessage 用户友好中文错误封装 (authFailed/serviceUnavailable/ipcError 分类)
            - + 菜单完整化：Add files (⌘U) / Take screenshot / Web search / Project

            ## [0.1.7] - 2026-07-30

            ### 新增
            - Issue #8: OrchestrationPattern 映射修正 — 6 模式 (sequential/parallel/masterWorker/handoff/broadcast/supervisor) 与 IndependentRouter (swarm/plaza/fmp) 分离
            - Issue #11: StreamingBridge WebSocket 模式 — connectWebSocket/streamChatWS/disconnectWebSocket，对接 fusion-code /ws/chat
            - RouterCard 视图 + IndependentRouter 网格加入 OrchestrationArea

            ### 修复
            - FusionCodeAPIClient SessionSummary/SessionDetail 字段对齐上游 (sessionId/summary/firstPrompt/lastModified/createdAt/gitBranch/cwd/fileSize)
            - 测试修复: AppState default module .code -> .chat

            ## [0.1.4] - 2026-07-29

            ### 新增
            - UI/UX Pro Max 审视优化：三栏布局对齐、暗色主题默认、8px 栅格系统、AccentColor 统一资源
            - accent #007AFF 统一原生 .accentColor/.tint，组件级主题令牌（auxiliary #1F2937 等）

            ### 修复
            - AgentStudio ConfigureAgentSheet：模型字段改下拉选择 + L1-L3 安全等级说明（对齐后端 SafetyGateway 三级）
            - 修复过期测试用例：RAGEngine -> RAGAPIClient、InfoPanelTab 断言 2 -> 7 cases

            ## [0.1.27] - 2026-08-04

            ### 新增
            - Fusion Simulation 模块: fusion-simulation GUI 工作台 (SimulationBridge + 4-zone WorkbenchView)
            - REST :11455 + gRPC :11447 集成: 场景加载/传感器/LLM Agent 策略/快照/实时监控

            ## [0.1.3] - 2026-07-29

            ### 新增
            - Desk 模块全量 GUI 覆盖 + IPCClient/AgentBridge/Artifacts 增强
            - UpstreamServiceManager 注册 fusion-cowork / model-hub / security 上游服务
            - 可复用 UpstreamServiceStatusBanner 组件（DeskView / ModelHubView / SecurityView）

            ### 修复
            - fusion-cowork / model-hub / security 模块"无内容"问题：缺少上游服务时展示状态横幅与启动入口

            ## [0.1.2] - 2026-07-01

            ### 新增
            - 初始 MVP 版本
            - SwiftUI 主框架
            - 环境自检 & 修复引擎
            - IPC 桥接
            """
        case .readme:
            return """
            # Fusion Studio

            > 生成时间: \(date)

            Fusion-MLX 本地 AI 生态的统一 macOS 桌面客户端。

            ## 功能特性

            - 10 个模块集成（设计、编码、仿真、模型管理等）
            - 100% 本地离线
            - Apple Silicon 原生优化
            - 环境自检 & 一键修复
            - 局域网协作
            - 插件系统
            """
        case .module:
            return """
            # 模块文档

            > 生成时间: \(date)

            ## Design 模块
            AI 驱动的设计画布，支持对话式 UI 生成。

            ## Code 模块
            内置代码编辑器和集成终端。

            ## Simulation 模块
            3D 物理仿真引擎。

            ## Model Hub 模块
            模型可视化管理。

            ## CLI 模块
            命令行工具图形化面板。
            """
        case .full:
            return """
            <!DOCTYPE html>
            <html>
            <head><title>Fusion Studio 文档</title>
            <style>
            body { font-family: -apple-system; max-width: 800px; margin: auto; padding: 2em; }
            h1 { color: #7c3aed; }
            </style></head>
            <body>
            <h1>Fusion Studio 文档</h1>
            <p>生成时间: \(date)</p>
            <ul>
            <li><a href="api-reference.md">API 参考文档</a></li>
            <li><a href="architecture.md">架构文档</a></li>
            <li><a href="CHANGELOG.md">更新日志</a></li>
            <li><a href="README.md">README</a></li>
            <li><a href="modules/index.md">模块文档</a></li>
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
            // 类型选择
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DocGenType.allCases, id: \.self) { type in
                        Button(action: { selectedType = type }) {
                            Label(type.rawValue, systemImage: type.icon)
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
                // 左侧：配置和操作
                VStack(spacing: 12) {
                    GroupBox("生成配置") {
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("输出格式", selection: $generator.config.outputFormat) {
                                ForEach(DocGenConfig.OutputFormat.allCases, id: \.self) { fmt in
                                    Label(fmt.rawValue, systemImage: fmt.icon).tag(fmt)
                                }
                            }
                            Toggle("包含私有成员", isOn: $generator.config.includePrivate)
                            Toggle("包含代码示例", isOn: $generator.config.includeCodeExamples)
                            Toggle("包含架构图", isOn: $generator.config.includeDiagrams)
                            Stepper("最大深度: \(generator.config.maxDepth)", value: $generator.config.maxDepth, in: 1...5)
                        }
                        .padding(8)
                    }

                    Button(action: { generator.generate(type: selectedType) }) {
                        Label("生成 \(selectedType.rawValue)", systemImage: "doc.badge.gearshape")
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
                        Button("打开输出目录") { generator.openOutputFolder() }
                            .buttonStyle(.bordered)
                    }

                    Spacer()

                    // 输出历史
                    if !generator.log.isEmpty {
                        GroupBox("生成日志") {
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

                // 右侧：已生成文件
                VStack {
                    if generator.generatedFiles.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "doc.badge.gearshape")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("选择文档类型并点击生成")
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
                                        Text(doc.type.rawValue)
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
                                        Button("打开") { NSWorkspace.shared.open(URL(fileURLWithPath: doc.path)) }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                        Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: doc.path)]) }
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
                Button("清空历史") { generator.clearHistory() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button("打开输出目录") { generator.openOutputFolder() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}