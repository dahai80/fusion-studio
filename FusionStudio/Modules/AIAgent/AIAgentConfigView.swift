import SwiftUI
import os.log

// Callers: AIAgentListView $showCreateSheet presents AIAgentConfigView(mode:.create);
// AIAgentListView edit action presents AIAgentConfigView(mode:.edit(agent)).
// Affected API: ipc.agentCreate/agentUpdate/agentPublish/agentGetApiEndpoint/connectorList/styleList/fetchModels.
// Data schemas: AgentModel (id,name,model,system_prompt,temperature,max_tokens,knowledge_base_ids,rag_strategy,
//   web_search_enabled,deep_research_enabled,connector_ids,style,top_p,context_window,rate_limit_qps,visibility).
// User instruction: "按照GUI草图实现fusion-ai-agent... 一定要做的比claude ai agent更有竞争力"

private let configLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.Config")

enum AgentConfigMode {
    case create
    case edit(AgentModel)
}

enum AgentConfigTab: String, CaseIterable {
    case basic = "基础信息"
    case instructions = "系统指令"
    case soul = "人格 Soul"
    case knowledge = "知识库"
    case tools = "工具配置"
    case advanced = "高级参数"
    case publish = "发布"

    var icon: String {
        switch self {
        case .basic: return "info.circle"
        case .instructions: return "text.alignleft"
        case .soul: return "person.crop.circle.badge.sparkles"
        case .knowledge: return "books.vertical"
        case .tools: return "wrench.and.screwdriver"
        case .advanced: return "slider.horizontal.3"
        case .publish: return "arrow.up.circle"
        }
    }
}

struct AIAgentConfigView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let mode: AgentConfigMode
    @State private var selectedTab: AgentConfigTab = .basic

    @State private var agentName = ""
    @State private var agentDesc = ""
    @State private var agentModel = ""
    @State private var agentVisibility = "private"
    @State private var systemInstructions = ""
    @State private var knowledgeBaseIds: [String] = []
    @State private var ragStrategy = "hybrid"
    @State private var allowAgentQuery = true
    @State private var webSearchEnabled = false
    @State private var deepResearchEnabled = false
    @State private var connectorIds: [String] = []
    @State private var temperature: Double = 0.3
    @State private var topP: Double = 0.8
    @State private var maxTokens: Int = 8192
    @State private var contextWindow: Int = 128000
    @State private var styleId = ""
    @State private var rateLimitQps: Int = 10

    @State private var isSaving = false
    @State private var isPublishing = false
    @State private var saveError: String?
    @State private var availableConnectors: [[String: Any]] = []
    @State private var availableStyles: [[String: Any]] = []
    @State private var availableModels: [String] = []
    @State private var instructionSnapshots: [[String: Any]] = []
    @State private var agentSkills: [String] = []
    @State private var newSkillName = ""
    @State private var newSkillDesc = ""
    @State private var showAddSkill = false
    @State private var soulContent = ""
    @State private var soulLoaded = false

    private var editingAgentId: String? {
        if case .edit(let agent) = mode { return agent.id }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(theme.separator).frame(height: 1)
            tabBar
            Rectangle().fill(theme.separator).frame(height: 1)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .frame(minWidth: 680, minHeight: 520)
        .background(theme.surfaceElevated)
        .onAppear { loadInitialData() }
        .sheet(isPresented: $showAddSkill) {
            VStack(spacing: theme.spacingL) {
                Text("添加技能")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                TextField("技能名称", text: $newSkillName)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceElevated))
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).strokeBorder(theme.separator, lineWidth: 1))
                TextField("技能描述（可选）", text: $newSkillDesc)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceElevated))
                    .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).strokeBorder(theme.separator, lineWidth: 1))
                HStack(spacing: theme.spacingM) {
                    Button("取消") { showAddSkill = false }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)
                    Button("添加") { addSkill() }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                        .disabled(newSkillName.isEmpty)
                }
            }
            .padding(theme.spacingL)
            .frame(width: 320)
            .background(theme.surfaceElevated)
        }
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(modeTitle)
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text(modeSubtitle)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if let error = saveError {
                Text(error)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.accentDestructive)
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(AgentConfigTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: theme.spacingXS) {
                            Image(systemName: tab.icon)
                                .font(.system(size: theme.iconS))
                            Text(tab.rawValue)
                                .font(.system(size: theme.footnoteSize, weight: .medium))
                        }
                        .foregroundStyle(selectedTab == tab ? theme.accentText : theme.textSecondary)
                        .padding(.horizontal, theme.spacingM)
                        .padding(.vertical, theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(selectedTab == tab ? theme.accent : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingL)
        }
        .padding(.vertical, theme.spacingXS)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .basic: basicInfoTab
        case .instructions: instructionsTab
        case .soul: soulTab
        case .knowledge: knowledgeTab
        case .tools: toolsTab
        case .advanced: advancedTab
        case .publish: publishTab
        }
    }

    // MARK: - Tab 1: Basic Info

    private var basicInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                formGroup("Agent 名称") {
                    TextField("输入 Agent 名称", text: $agentName)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize))
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(theme.separator, lineWidth: 1)
                        )
                }

                formGroup("简介") {
                    TextField("描述 Agent 的功能和用途", text: $agentDesc, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize))
                        .lineLimit(3...6)
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(theme.separator, lineWidth: 1)
                        )
                }

                formGroup("模型选择") {
                    Picker("模型", selection: $agentModel) {
                        Text("选择模型").tag("")
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 300)
                }

                formGroup("可见范围") {
                    HStack(spacing: theme.spacingL) {
                        visibilityOption("private", label: "仅本人可见", icon: "lock")
                        visibilityOption("organization", label: "组织共享", icon: "person.3")
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    // MARK: - Tab 2: System Instructions

    private var instructionsTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    Text("编写 Agent 基础角色、行为约束、输出规范")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)

                    TextEditor(text: $systemInstructions)
                        .font(.system(size: theme.textSize, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                        .padding(theme.spacingS)
                        .background(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .fill(theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .strokeBorder(theme.separator, lineWidth: 1)
                        )

                    HStack {
                        Text("\(systemInstructions.count) 字符")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Button("保存模板") {
                            configLog.info("Save instruction template")
                        }
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)

                        Button("恢复历史版本") {
                            configLog.info("Restore instruction snapshot")
                        }
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)
                    }
                }
                .padding(theme.spacingL)
            }
        }
    }

    // MARK: - Tab 3: Soul

    private var soulTab: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingM) {
                    Text("定义 Agent 的人格特质、说话风格、情感偏好")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)

                    if editingAgentId != nil {
                        TextEditor(text: $soulContent)
                            .font(.system(size: theme.textSize, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 280)
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(theme.separator, lineWidth: 1)
                            )

                        HStack {
                            Text("\(soulContent.count) 字符")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                            Spacer()
                            Button("保存 Soul") { saveSoul() }
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.accent)
                                .buttonStyle(.plain)
                        }
                    } else {
                        Text("创建 Agent 后可编辑 Soul")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(theme.spacingL)
            }
        }
        .onAppear { loadSoulIfNeeded() }
    }

    // MARK: - Tab 4: Knowledge Base

    private var knowledgeTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                formGroup("绑定知识库 Project") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(knowledgeBaseIds, id: \.self) { kbId in
                            HStack {
                                Image(systemName: "books.vertical")
                                    .foregroundStyle(theme.auxiliary)
                                Text(kbId)
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.text)
                                Spacer()
                                Button(action: { knowledgeBaseIds.removeAll { $0 == kbId } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(theme.spacingS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                        }

                        Button("+ 添加知识库") {
                            configLog.info("Add knowledge base")
                        }
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.accent)
                        .buttonStyle(.plain)
                    }
                }

                formGroup("检索策略") {
                    HStack(spacing: theme.spacingL) {
                        ragOption("vector", label: "向量检索", icon: "arrow.triangle.2.circlepath")
                        ragOption("fulltext", label: "全文检索", icon: "doc.text.magnifyingglass")
                        ragOption("hybrid", label: "混合检索", icon: "arrow.up.arrow.down.circle")
                    }
                }

                formGroup("自主查询") {
                    Toggle("允许 Agent 主动查询知识库内容", isOn: $allowAgentQuery)
                        .font(.system(size: theme.footnoteSize))
                        .toggleStyle(.switch)
                }
            }
            .padding(theme.spacingL)
        }
    }

    // MARK: - Tab 4: Tools

    private var toolsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                formGroup("内置工具") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        toolToggle("Web Search 网页搜索", isOn: $webSearchEnabled, icon: "globe")
                        toolToggle("Deep Research 深度调研模式", isOn: $deepResearchEnabled, icon: "magnifyingglass")
                    }
                }

                formGroup("技能 Skills") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        if editingAgentId != nil {
                            HStack {
                                Text("已添加 \(agentSkills.count) 个技能")
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Button(action: { showAddSkill = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("添加技能")
                                    }
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(theme.accent)
                            }
                            if agentSkills.isEmpty {
                                Text("暂无技能，点击「添加技能」为 Agent 增加能力")
                                    .font(.system(size: theme.captionSize))
                                    .foregroundStyle(theme.textTertiary)
                            } else {
                                ForEach(Array(agentSkills.enumerated()), id: \.offset) { idx, skill in
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(theme.auxiliary)
                                        Text(skill)
                                            .font(.system(size: theme.footnoteSize))
                                            .foregroundStyle(theme.text)
                                        Spacer()
                                        Button(action: { deleteSkill(name: skill) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(theme.accentDestructive)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(theme.spacingXS)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .fill(theme.surfaceElevated)
                                    )
                                }
                            }
                        } else {
                            Text("创建 Agent 后可管理技能")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }

                formGroup("外部连接器 Connectors") {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        if availableConnectors.isEmpty {
                            Text("暂无已授权连接器")
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                        } else {
                            ForEach(Array(availableConnectors.enumerated()), id: \.offset) { _, conn in
                                let connId = conn["id"] as? String ?? ""
                                let connName = conn["name"] as? String ?? "Unknown"
                                let isConnected = connectorIds.contains(connId)
                                Toggle(isOn: Binding(
                                    get: { isConnected },
                                    set: { on in
                                        if on { connectorIds.append(connId) }
                                        else { connectorIds.removeAll { $0 == connId } }
                                    }
                                )) {
                                    HStack(spacing: theme.spacingXS) {
                                        Image(systemName: "link")
                                        Text(connName)
                                    }
                                }
                                .font(.system(size: theme.footnoteSize))
                                .toggleStyle(.switch)
                            }
                        }
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    // MARK: - Tab 5: Advanced Params

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                formGroup("Temperature") {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack {
                            Text("\(String(format: "%.2f", temperature))")
                                .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.text)
                            Spacer()
                            Text("低=精确 高=创造")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Slider(value: $temperature, in: 0...2, step: 0.05)
                    }
                }

                formGroup("Top P") {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack {
                            Text("\(String(format: "%.2f", topP))")
                                .font(.system(size: theme.footnoteSize, weight: .medium, design: .monospaced))
                                .foregroundStyle(theme.text)
                        }
                        Slider(value: $topP, in: 0...1, step: 0.05)
                    }
                }

                formGroup("最大输出 Token") {
                    HStack(spacing: theme.spacingS) {
                        TextField("8192", value: $maxTokens, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .frame(width: 100)
                            .padding(theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(theme.separator, lineWidth: 1)
                            )
                        Text("tokens")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                formGroup("上下文窗口") {
                    HStack(spacing: theme.spacingS) {
                        TextField("128000", value: $contextWindow, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .frame(width: 100)
                            .padding(theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(theme.separator, lineWidth: 1)
                            )
                        Text("tokens")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }

                formGroup("输出风格 Style") {
                    Picker("风格", selection: $styleId) {
                        Text("默认").tag("")
                        ForEach(Array(availableStyles.enumerated()), id: \.offset) { _, style in
                            Text(style["name"] as? String ?? "").tag(style["id"] as? String ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 300)
                }

                formGroup("QPS 限流") {
                    HStack(spacing: theme.spacingS) {
                        TextField("10", value: $rateLimitQps, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .frame(width: 60)
                            .padding(theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(theme.surfaceElevated)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .strokeBorder(theme.separator, lineWidth: 1)
                            )
                        Text("请求/秒")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    // MARK: - Tab 6: Publish

    private var publishTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                configSummaryCard

                formGroup("发布操作") {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        if let agentId = editingAgentId {
                            HStack(spacing: theme.spacingM) {
                                Button(action: { publishAgent(agentId: agentId) }) {
                                    HStack(spacing: theme.spacingXS) {
                                        if isPublishing {
                                            ProgressView().scaleEffect(0.6)
                                        } else {
                                            Image(systemName: "arrow.up.circle.fill")
                                        }
                                        Text("发布 Agent")
                                    }
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.accentText)
                                    .padding(.horizontal, theme.spacingL)
                                    .padding(.vertical, theme.spacingS)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .fill(theme.accent)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isPublishing)

                                Button(action: { getApiEndpoint(agentId: agentId) }) {
                                    HStack(spacing: theme.spacingXS) {
                                        Image(systemName: "link")
                                        Text("获取 API 地址")
                                    }
                                    .font(.system(size: theme.footnoteSize, weight: .medium))
                                    .foregroundStyle(theme.accent)
                                    .padding(.horizontal, theme.spacingL)
                                    .padding(.vertical, theme.spacingS)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                            .fill(theme.accent.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text("请先保存草稿后再发布")
                                .font(.system(size: theme.footnoteSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                }
            }
            .padding(theme.spacingL)
        }
    }

    private var configSummaryCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text("配置摘要")
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            summaryRow("名称", value: agentName.isEmpty ? "-" : agentName)
            summaryRow("模型", value: agentModel.isEmpty ? "-" : agentModel)
            summaryRow("可见范围", value: agentVisibility == "organization" ? "组织共享" : "仅本人可见")
            summaryRow("知识库", value: knowledgeBaseIds.isEmpty ? "未绑定" : knowledgeBaseIds.joined(separator: ", "))
            summaryRow("工具", value: toolSummary)
            summaryRow("Temperature", value: String(format: "%.2f", temperature))
            summaryRow("最大 Token", value: "\(maxTokens)")
        }
        .padding(theme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(theme.separator, lineWidth: 1)
        )
    }

    private var toolSummary: String {
        var parts: [String] = []
        if webSearchEnabled { parts.append("Web Search") }
        if deepResearchEnabled { parts.append("Deep Research") }
        if !connectorIds.isEmpty { parts.append("\(connectorIds.count) 连接器") }
        return parts.isEmpty ? "未启用" : parts.joined(separator: ", ")
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if let agentId = editingAgentId {
                Button("删除 Agent") {
                    configLog.info("Delete agent: \(agentId)")
                    Task {
                        do {
                            _ = try await ipc.agentDelete(agentId: agentId)
                            configLog.info("Agent deleted: \(agentId)")
                            try await bridge.fetchAgents()
                            dismiss()
                        } catch {
                            configLog.error("Delete agent failed: \(error.localizedDescription)")
                        }
                    }
                }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.accentDestructive)
                .buttonStyle(.plain)
            }
            Spacer()
            Button("取消") { dismiss() }
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .buttonStyle(.plain)

            Button(action: { saveDraft() }) {
                HStack(spacing: theme.spacingXS) {
                    if isSaving { ProgressView().scaleEffect(0.6) }
                    Text("保存草稿")
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    // MARK: - Helper Views

    private func formGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(title)
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            content()
        }
    }

    private func visibilityOption(_ value: String, label: String, icon: String) -> some View {
        Button(action: { agentVisibility = value }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                Text(label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
            }
            .foregroundStyle(agentVisibility == value ? theme.accentText : theme.textSecondary)
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(agentVisibility == value ? theme.accent : theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(agentVisibility == value ? theme.accent : theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func ragOption(_ value: String, label: String, icon: String) -> some View {
        Button(action: { ragStrategy = value }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                Text(label)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
            }
            .foregroundStyle(ragStrategy == value ? theme.accentText : theme.textSecondary)
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(ragStrategy == value ? theme.accent : theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(ragStrategy == value ? theme.accent : theme.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func toolToggle(_ label: String, isOn: Binding<Bool>, icon: String) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon)
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.auxiliary)
                Text(label)
            }
        }
        .font(.system(size: theme.footnoteSize))
        .toggleStyle(.switch)
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)
        }
    }

    // MARK: - Computed

    private var modeTitle: String {
        switch mode {
        case .create: return "创建新 Agent"
        case .edit(let agent): return "编辑 Agent：\(agent.name)"
        }
    }

    private var modeSubtitle: String {
        switch mode {
        case .create: return "配置智能体的基础信息、指令、工具和参数"
        case .edit: return "修改 Agent 配置后保存或发布"
        }
    }

    // MARK: - Actions

    private func loadInitialData() {
        if case .edit(let agent) = mode {
            agentName = agent.name
            agentDesc = agent.description
            agentModel = agent.model
            systemInstructions = agent.system_prompt
            temperature = agent.temperature
            maxTokens = agent.max_tokens
            knowledgeBaseIds = agent.knowledge_base_ids ?? []
            ragStrategy = agent.rag_strategy ?? "hybrid"
            webSearchEnabled = agent.web_search_enabled ?? false
            deepResearchEnabled = agent.deep_research_enabled ?? false
            connectorIds = agent.connector_ids ?? []
            styleId = agent.style ?? ""
            topP = agent.top_p ?? 0.8
            contextWindow = agent.context_window ?? 128000
            rateLimitQps = agent.rate_limit_qps ?? 10
            agentVisibility = agent.visibility ?? "private"
        }
        Task {
            do {
                let modelIds = bridge.models.map { $0.id }
                await MainActor.run { availableModels = modelIds }
            }
            do {
                let result = try await ipc.connectorList()
                let conns = result["connectors"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
                await MainActor.run { availableConnectors = conns }
            } catch { configLog.error("Fetch connectors failed: \(error.localizedDescription)") }
            do {
                let result = try await ipc.styleList()
                let styles = result["styles"] as? [[String: Any]] ?? (result["data"] as? [[String: Any]] ?? [])
                await MainActor.run { availableStyles = styles }
            } catch { configLog.error("Fetch styles failed: \(error.localizedDescription)") }
            if let aid = editingAgentId {
                do {
                    let result = try await ipc.agentListSkills(agentId: aid)
                    let skills = result["skills"] as? [String] ?? (result["data"] as? [String] ?? [])
                    await MainActor.run { agentSkills = skills }
                } catch { configLog.error("Fetch skills failed: \(error.localizedDescription)") }
            }
        }
    }

    private func addSkill() {
        guard let aid = editingAgentId, !newSkillName.isEmpty else { return }
        Task {
            do {
                var def: [String: Any] = [:]
                if !newSkillDesc.isEmpty { def["description"] = newSkillDesc }
                let _ = try await ipc.agentAddSkill(agentId: aid, skillName: newSkillName, skillDef: def)
                await MainActor.run {
                    agentSkills.append(newSkillName)
                    newSkillName = ""
                    newSkillDesc = ""
                    showAddSkill = false
                }
                configLog.info("Added skill \(newSkillName) to agent \(aid)")
            } catch {
                configLog.error("Add skill failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSkill(name: String) {
        guard let aid = editingAgentId else { return }
        Task {
            do {
                let _ = try await ipc.agentDeleteSkill(agentId: aid, skillName: name)
                await MainActor.run { agentSkills.removeAll { $0 == name } }
                configLog.info("Deleted skill \(name) from agent \(aid)")
            } catch {
                configLog.error("Delete skill failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSoulIfNeeded() {
        guard let aid = editingAgentId, !soulLoaded else { return }
        Task {
            do {
                let result = try await ipc.agentGetSoul(agentId: aid)
                let content = result["soul"] as? String ?? (result["content"] as? String ?? "")
                await MainActor.run {
                    soulContent = content
                    soulLoaded = true
                }
            } catch {
                configLog.error("Load soul failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveSoul() {
        guard let aid = editingAgentId else { return }
        Task {
            do {
                let _ = try await ipc.agentUpdateSoul(agentId: aid, soul: soulContent)
                configLog.info("Soul saved for agent \(aid)")
            } catch {
                configLog.error("Save soul failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveDraft() {
        isSaving = true
        saveError = nil
        Task {
            do {
                if let agentId = editingAgentId {
                    let _ = try await ipc.agentUpdate(
                        agentId: agentId,
                        name: agentName,
                        model: agentModel,
                        systemPrompt: systemInstructions,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        tools: buildToolsList(),
                        capabilities: [],
                        safetyLevel: "standard",
                        tags: [],
                        description: agentDesc,
                        visibility: agentVisibility,
                        ragStrategy: ragStrategy,
                        webSearchEnabled: webSearchEnabled,
                        deepResearchEnabled: deepResearchEnabled,
                        connectorIds: connectorIds,
                        style: styleId,
                        topP: topP,
                        contextWindow: contextWindow,
                        rateLimitQps: rateLimitQps
                    )
                    configLog.info("Agent updated: \(agentId)")
                } else {
                    let _ = try await ipc.agentCreate(
                        name: agentName,
                        model: agentModel,
                        systemPrompt: systemInstructions,
                        temperature: temperature,
                        maxTokens: maxTokens,
                        tools: buildToolsList(),
                        description: agentDesc,
                        visibility: agentVisibility,
                        ragStrategy: ragStrategy,
                        webSearchEnabled: webSearchEnabled,
                        deepResearchEnabled: deepResearchEnabled,
                        connectorIds: connectorIds,
                        style: styleId,
                        topP: topP,
                        contextWindow: contextWindow,
                        rateLimitQps: rateLimitQps
                    )
                    configLog.info("Agent created")
                }
                try await bridge.fetchAgents()
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                configLog.error("Save failed: \(error.localizedDescription)")
                await MainActor.run {
                    isSaving = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func publishAgent(agentId: String) {
        isPublishing = true
        Task {
            do {
                let _ = try await ipc.agentPublish(agentId: agentId)
                configLog.info("Agent published: \(agentId)")
                try await bridge.fetchAgents()
                await MainActor.run { isPublishing = false }
            } catch {
                configLog.error("Publish failed: \(error.localizedDescription)")
                await MainActor.run {
                    isPublishing = false
                    saveError = error.localizedDescription
                }
            }
        }
    }

    private func getApiEndpoint(agentId: String) {
        Task {
            do {
                let result = try await ipc.agentGetApiEndpoint(agentId: agentId)
                let endpoint = result["endpoint"] as? String ?? result["api_endpoint"] as? String ?? "N/A"
                configLog.info("API endpoint: \(endpoint)")
            } catch {
                configLog.error("Get endpoint failed: \(error.localizedDescription)")
            }
        }
    }

    private func buildToolsList() -> [String] {
        var tools: [String] = []
        if webSearchEnabled { tools.append("web_search") }
        if deepResearchEnabled { tools.append("deep_research") }
        tools.append(contentsOf: connectorIds)
        return tools
    }
}
