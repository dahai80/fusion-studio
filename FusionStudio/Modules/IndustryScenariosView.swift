// Callers: ModuleDetailView routing.
// Affected API: IndustryScenariosView (replacing NSColor with StudioTheme tokens).
// Data schemas: None changed.
// User instruction: "帮我用 UI/UX Pro Max 重新设计 fusion-studio 的整体 GUI - macOS 原生风格 - 三栏 - 暗色模式优先 - 主色 #007AFF"

import SwiftUI

// MARK: - 行业场景

struct IndustryScenario: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let industry: String
    let icon: String
    let color: Color
    let modules: [String]
    let difficulty: String
    let estimatedTime: String
    let isBuiltin: Bool
    var isInstalled: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: IndustryScenario, rhs: IndustryScenario) -> Bool { lhs.id == rhs.id }
}

// MARK: - 场景管理器

class IndustryScenarioManager: ObservableObject {
    static let shared = IndustryScenarioManager()

    @Published var scenarios: [IndustryScenario] = []
    @Published var searchText = ""
    @Published var selectedIndustry: String = "全部"
    @Published var activeScenario: IndustryScenario?

    var industries: [String] {
        ["全部"] + Set(scenarios.map(\.industry)).sorted()
    }

    var filteredScenarios: [IndustryScenario] {
        var result = scenarios
        if selectedIndustry != "全部" { result = result.filter { $0.industry == selectedIndustry } }
        if !searchText.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText) } }
        return result
    }

    init() { loadScenarios() }

    private func loadScenarios() {
        scenarios = [
            IndustryScenario(id: "scene-robot-arm", name: "六轴机械臂仿真", description: "完整的六轴工业机器人仿真场景，包含运动学模型、轨迹规划和控制面板", industry: "机器人", icon: "gearshape.2.fill", color: .blue, modules: ["Simulation", "Design", "Code"], difficulty: "中级", estimatedTime: "2-3 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-robot-walk", name: "双足行走机器人", description: "双足机器人步行仿真，包含平衡控制、步态规划和传感器融合", industry: "机器人", icon: "figure.walk", color: .cyan, modules: ["Simulation", "Code"], difficulty: "高级", estimatedTime: "4-6 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-content-blog", name: "博客内容创作", description: "AI 辅助博客写作工作流，包含选题、大纲、写作、配图、发布全流程", industry: "内容创作", icon: "doc.text.fill", color: .orange, modules: ["Code", "MultiModal", "Agent"], difficulty: "初级", estimatedTime: "30 分钟", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-content-video", name: "短视频批量生成", description: "AI 短视频批量生产流水线：脚本生成、配音、配图、字幕一站式", industry: "内容创作", icon: "video.fill", color: .red, modules: ["MultiModal", "Code", "Agent"], difficulty: "中级", estimatedTime: "1-2 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-enterprise-kb", name: "企业知识库搭建", description: "搭建企业级 RAG 知识库，支持多格式文档导入、智能检索和权限管理", industry: "企业", icon: "books.vertical.fill", color: .indigo, modules: ["KB", "Doc", "Security"], difficulty: "中级", estimatedTime: "3-4 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-enterprise-report", name: "智能报表系统", description: "自动生成企业周报/月报/季报，集成数据分析和可视化图表", industry: "企业", icon: "chart.bar.fill", color: .purple, modules: ["DataTools", "Analytics", "Code"], difficulty: "初级", estimatedTime: "1 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-ai-agent", name: "AI 客服机器人", description: "基于 RAG 和智能体编排的客服机器人，支持多轮对话和工单管理", industry: "AI 工具", icon: "message.fill", color: .green, modules: ["Agent", "KB", "Training"], difficulty: "高级", estimatedTime: "5-8 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-ai-code-review", name: "自动化代码审查", description: "多智能体协作的代码审查流水线：风格检查、安全扫描、性能分析", industry: "AI 工具", icon: "chevron.left.forwardslash.chevron.right", color: .blue, modules: ["Agent", "Code", "Security"], difficulty: "中级", estimatedTime: "2 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-design-app", name: "移动 App 设计", description: "从需求到原型的一站式移动 App 设计流程，含设计系统和代码导出", industry: "设计", icon: "apps.iphone", color: .pink, modules: ["Design", "Code", "MultiModal"], difficulty: "中级", estimatedTime: "3-5 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-design-dashboard", name: "数据仪表盘设计", description: "企业数据仪表盘设计模板，包含实时图表、指标卡片和交互原型", industry: "设计", icon: "square.grid.3x3.fill", color: .orange, modules: ["Design", "DataTools", "Analytics"], difficulty: "初级", estimatedTime: "1-2 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-science-lab", name: "科研实验管理", description: "科研实验数据管理、分析、报告生成工作流", industry: "科研", icon: "flask.fill", color: .teal, modules: ["DataTools", "Doc", "Analytics"], difficulty: "中级", estimatedTime: "2-3 小时", isBuiltin: true, isInstalled: false),
            IndustryScenario(id: "scene-science-paper", name: "论文写作助手", description: "AI 辅助学术论文写作：文献检索、大纲生成、内容撰写、格式校对", industry: "科研", icon: "doc.text.magnifyingglass", color: .mint, modules: ["KB", "Code", "Agent"], difficulty: "高级", estimatedTime: "4-6 小时", isBuiltin: true, isInstalled: false),
        ]
    }

    func installScene(_ id: String) {
        guard let idx = scenarios.firstIndex(where: { $0.id == id }) else { return }
        scenarios[idx].isInstalled = true
        activeScenario = scenarios[idx]
        objectWillChange.send()
    }

    func uninstallScene(_ id: String) {
        guard let idx = scenarios.firstIndex(where: { $0.id == id }) else { return }
        scenarios[idx].isInstalled = false
        objectWillChange.send()
    }
}

// MARK: - 行业场景面板

struct IndustryScenariosView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var manager = IndustryScenarioManager.shared
    @State private var viewMode: SceneViewMode = .grid
    @State private var selectedScenario: IndustryScenario?

    enum SceneViewMode: String, CaseIterable { case grid = "网格"; case list = "列表" }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("行业场景模板", systemImage: "square.stack.3d.forward.dottedline").font(.headline)
                Spacer()
                Picker("", selection: $viewMode) {
                    ForEach(SceneViewMode.allCases, id: \.self) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented).frame(width: 100)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(theme.surfaceSecondary)

            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索场景...", text: $manager.searchText).textFieldStyle(.plain)
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(manager.industries, id: \.self) { ind in
                            Button(ind) { manager.selectedIndustry = ind }
                                .buttonStyle(.bordered).controlSize(.small)
                                .tint(manager.selectedIndustry == ind ? .accentColor : nil)
                        }
                    }
                }
            }
            .padding(8)

            Divider()

            if manager.filteredScenarios.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.forward.dottedline").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("无匹配场景").foregroundColor(.secondary)
                    Spacer()
                }
            } else if viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                        ForEach(manager.filteredScenarios) { scene in
                            ScenarioCard(scene: scene)
                                .onTapGesture { selectedScenario = scene }
                        }
                    }
                    .padding()
                }
            } else {
                List(manager.filteredScenarios) { scene in
                    ScenarioRow(scene: scene)
                        .onTapGesture { selectedScenario = scene }
                }
            }
        }
        .sheet(item: $selectedScenario) { scene in ScenarioDetailView(scene: scene) }
    }
}

// MARK: - 场景卡片

struct ScenarioCard: View {
    @Environment(\.studioTheme) private var theme
    let scene: IndustryScenario
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: scene.icon).font(.title2).foregroundColor(scene.color)
                Spacer()
                Text(scene.industry).font(.system(size: 8)).padding(.horizontal, 4).padding(.vertical, 1)
                    .background(scene.color.opacity(0.1)).cornerRadius(3)
            }
            Text(scene.name).font(.headline)
            Text(scene.description).font(.caption).foregroundColor(.secondary).lineLimit(3)
            HStack(spacing: 4) {
                ForEach(scene.modules, id: \.self) { mod in
                    Text(mod).font(.system(size: 7)).padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1)).cornerRadius(2)
                }
            }
            HStack {
                Label(scene.difficulty, systemImage: "signal").font(.caption2).foregroundColor(.secondary)
                Spacer()
                Label(scene.estimatedTime, systemImage: "clock").font(.caption2).foregroundColor(.secondary)
            }
            Button(action: { scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id) }) {
                Label(scene.isInstalled ? "已安装" : "安装场景", systemImage: scene.isInstalled ? "checkmark.circle.fill" : "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .tint(scene.isInstalled ? .green : nil)
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
    }
}

// MARK: - 场景行

struct ScenarioRow: View {
    let scene: IndustryScenario
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: scene.icon).foregroundColor(scene.color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(scene.name).font(.headline)
                Text(scene.description).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(scene.industry).font(.caption2).padding(.horizontal, 4).background(scene.color.opacity(0.1)).cornerRadius(3)
                    Text(scene.difficulty).font(.caption2).foregroundColor(.secondary)
                    Text(scene.estimatedTime).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(scene.isInstalled ? "已安装" : "安装") { scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id) }
                .buttonStyle(.borderedProminent).controlSize(.small).tint(scene.isInstalled ? .green : nil)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 场景详情

struct ScenarioDetailView: View {
    let scene: IndustryScenario
    @Environment(\.dismiss) var dismiss
    @StateObject private var manager = IndustryScenarioManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: scene.icon).font(.title).foregroundColor(scene.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(scene.name).font(.title2).bold()
                    Text(scene.industry).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Button("关闭") { dismiss() }.buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox("场景信息") {
                VStack(alignment: .leading, spacing: 6) {
                    SceneDetailRow("描述", scene.description)
                    SceneDetailRow("难度", scene.difficulty)
                    SceneDetailRow("预计时间", scene.estimatedTime)
                    SceneDetailRow("类型", scene.isBuiltin ? "内置" : "自定义")
                }
                .padding(8)
            }

            GroupBox("涉及模块") {
                HStack {
                    ForEach(scene.modules, id: \.self) { mod in
                        Text(mod).font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1)).cornerRadius(4)
                    }
                }
                .padding(8)
            }

            GroupBox("安装说明") {
                Text("安装此场景将自动配置相关模块的参数和预设。场景模板包含配置文件、示例数据和初始化脚本。")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                Button(action: {
                    scene.isInstalled ? manager.uninstallScene(scene.id) : manager.installScene(scene.id)
                    dismiss()
                }) {
                    Label(scene.isInstalled ? "卸载场景" : "安装场景", systemImage: scene.isInstalled ? "trash" : "plus.circle")
                        .frame(width: 160)
                }
                .buttonStyle(.borderedProminent)
                .tint(scene.isInstalled ? .red : nil)
                Spacer()
            }
        }
        .padding()
        .frame(width: 420, height: 480)
    }
}

struct SceneDetailRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}