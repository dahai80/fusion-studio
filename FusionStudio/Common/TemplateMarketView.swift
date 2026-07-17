import SwiftUI

// MARK: - 模板分类

enum TemplateCategory: String, CaseIterable {
    case all        = "全部"
    case design     = "设计"
    case code       = "代码"
    case simulation = "仿真"
    case workflow   = "工作流"
    case report     = "报表"
    case automation = "自动化"

    var icon: String {
        switch self {
        case .all:        return "square.grid.2x2"
        case .design:     return "pencil.and.outline"
        case .code:       return "chevron.left.forwardslash.chevron.right"
        case .simulation: return "gearshape.2"
        case .workflow:   return "arrow.triangle.branch"
        case .report:     return "doc.text"
        case .automation: return "desktopcomputer"
        }
    }
}

// MARK: - 模板

struct UserTemplate: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var category: TemplateCategory
    var author: String
    var version: String
    var rating: Double
    var downloadCount: Int
    var tags: [String]
    var isLocal: Bool
    var isFavorite: Bool
    var installDate: Date?
    var content: [String: Any]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: UserTemplate, rhs: UserTemplate) -> Bool { lhs.id == rhs.id }
}

// MARK: - 模板市场

class TemplateMarket: ObservableObject {
    static let shared = TemplateMarket()

    @Published var templates: [UserTemplate] = []
    @Published var searchText = ""
    @Published var selectedCategory: TemplateCategory = .all
    @Published var showFavoritesOnly = false

    var filteredTemplates: [UserTemplate] {
        var result = templates
        if selectedCategory != .all { result = result.filter { $0.category == selectedCategory } }
        if !searchText.isEmpty { result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } } }
        if showFavoritesOnly { result = result.filter { $0.isFavorite } }
        return result
    }

    init() { loadSampleTemplates() }

    private func loadSampleTemplates() {
        templates = [
            UserTemplate(id: "tpl-1", name: "现代仪表盘", description: "数据可视化仪表盘模板，支持实时图表和指标卡片", category: .design, author: "Fusion Studio", version: "1.0.0", rating: 4.8, downloadCount: 2340, tags: ["仪表盘", "数据可视化", "图表"], isLocal: true, isFavorite: true, installDate: Date(), content: [:]),
            UserTemplate(id: "tpl-2", name: "SwiftUI 列表页", description: "标准列表页模板，包含搜索、筛选、下拉刷新", category: .code, author: "Fusion Studio", version: "1.2.0", rating: 4.6, downloadCount: 1890, tags: ["SwiftUI", "列表", "iOS"], isLocal: true, isFavorite: false, installDate: Date(), content: [:]),
            UserTemplate(id: "tpl-3", name: "六轴机械臂", description: "六轴工业机器人仿真场景，包含运动学模型", category: .simulation, author: "SimLab", version: "0.9.0", rating: 4.9, downloadCount: 1560, tags: ["机器人", "机械臂", "运动学"], isLocal: false, isFavorite: true, installDate: nil, content: [:]),
            UserTemplate(id: "tpl-4", name: "代码审查流程", description: "自动代码审查工作流，集成多智能体协作", category: .workflow, author: "DevTools", version: "1.0.0", rating: 4.5, downloadCount: 980, tags: ["代码审查", "工作流", "自动化"], isLocal: false, isFavorite: false, installDate: nil, content: [:]),
            UserTemplate(id: "tpl-5", name: "季度报告", description: "季度业务报告模板，自动生成数据分析和图表", category: .report, author: "DataViz", version: "2.1.0", rating: 4.3, downloadCount: 3200, tags: ["报表", "数据分析", "季度"], isLocal: true, isFavorite: true, installDate: Date(), content: [:]),
            UserTemplate(id: "tpl-6", name: "文件整理助手", description: "自动化文件分类整理模板，按类型/日期/项目归档", category: .automation, author: "DeskBot", version: "1.1.0", rating: 4.7, downloadCount: 4500, tags: ["文件管理", "自动化", "整理"], isLocal: false, isFavorite: false, installDate: nil, content: [:]),
            UserTemplate(id: "tpl-7", name: "深色主题", description: "完整的深色主题设计系统，包含配色和组件", category: .design, author: "DesignPro", version: "2.0.0", rating: 4.4, downloadCount: 6700, tags: ["主题", "深色模式", "设计系统"], isLocal: false, isFavorite: false, installDate: nil, content: [:]),
            UserTemplate(id: "tpl-8", name: "API 接口生成", description: "根据 OpenAPI 规范自动生成 Swift/TypeScript 客户端", category: .code, author: "APIGen", version: "1.3.0", rating: 4.2, downloadCount: 1200, tags: ["API", "代码生成", "OpenAPI"], isLocal: false, isFavorite: false, installDate: nil, content: [:]),
        ]
    }

    func toggleFavorite(_ id: String) {
        guard let idx = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[idx].isFavorite.toggle()
        objectWillChange.send()
    }

    func installTemplate(_ id: String) {
        guard let idx = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[idx].isLocal = true
        templates[idx].installDate = Date()
        objectWillChange.send()
    }

    func uninstallTemplate(_ id: String) {
        guard let idx = templates.firstIndex(where: { $0.id == id }) else { return }
        templates[idx].isLocal = false
        templates[idx].installDate = nil
        objectWillChange.send()
    }

    func createTemplate(name: String, description: String, category: TemplateCategory) {
        let template = UserTemplate(
            id: "tpl-\(UUID().uuidString.prefix(6))",
            name: name,
            description: description,
            category: category,
            author: "本地",
            version: "0.1.0",
            rating: 0,
            downloadCount: 0,
            tags: [],
            isLocal: true,
            isFavorite: false,
            installDate: Date(),
            content: [:]
        )
        templates.insert(template, at: 0)
        objectWillChange.send()
    }
}

// MARK: - 模板市场视图

struct TemplateMarketView: View {
    @StateObject private var market = TemplateMarket.shared
    @State private var showCreateSheet = false
    @State private var selectedTemplate: UserTemplate?
    @State private var viewMode: TemplateViewMode = .grid

    enum TemplateViewMode: String, CaseIterable {
        case grid = "网格"; case list = "列表"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索模板...", text: $market.searchText).textFieldStyle(.plain)
                Spacer()
                Picker("", selection: $viewMode) {
                    ForEach(TemplateViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented).frame(width: 100)
                Toggle("仅收藏", isOn: $market.showFavoritesOnly).toggleStyle(.checkbox).controlSize(.small)
                Button(action: { showCreateSheet = true }) { Label("新建", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))

            // 分类
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TemplateCategory.allCases, id: \.self) { cat in
                        Button(action: { market.selectedCategory = cat }) {
                            Label(cat.rawValue, systemImage: cat.icon)
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(market.selectedCategory == cat ? .accentColor : nil)
                    }
                }
                .padding(8)
            }

            Divider()

            // 内容
            if market.filteredTemplates.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.grid.2x2").font(.system(size: 40)).foregroundColor(.secondary)
                    Text("无匹配模板").foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    if viewMode == .grid {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                            ForEach(market.filteredTemplates) { template in
                                TemplateCardView(template: template)
                                    .onTapGesture { selectedTemplate = template }
                            }
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(market.filteredTemplates) { template in
                                TemplateListRow(template: template)
                                    .onTapGesture { selectedTemplate = template }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) { CreateTemplateSheet() }
        .sheet(item: $selectedTemplate) { template in MarketTemplateDetailView(template: template) }
    }
}

// MARK: - 模板卡片

struct TemplateCardView: View {
    let template: UserTemplate
    @StateObject private var market = TemplateMarket.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.category.icon).font(.title2).foregroundColor(.accentColor)
                Spacer()
                Button(action: { market.toggleFavorite(template.id) }) {
                    Image(systemName: template.isFavorite ? "star.fill" : "star")
                        .foregroundColor(template.isFavorite ? .yellow : .gray)
                }.buttonStyle(.plain)
            }
            Text(template.name).font(.headline).lineLimit(1)
            Text(template.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Image(systemName: "person").font(.caption2)
                Text(template.author).font(.caption2)
                Spacer()
                Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                Text("\(template.rating, specifier: "%.1f")").font(.caption2)
            }
            HStack {
                Text("v\(template.version)").font(.caption2).foregroundColor(.secondary)
                Spacer()
                if template.isLocal {
                    Label("已安装", systemImage: "checkmark.circle.fill").font(.caption2).foregroundColor(.green)
                } else {
                    Button("安装") { market.installTemplate(template.id) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 模板列表行

struct TemplateListRow: View {
    let template: UserTemplate
    @StateObject private var market = TemplateMarket.shared

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: template.category.icon).foregroundColor(.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(template.name).font(.headline)
                    if template.isFavorite { Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow) }
                }
                Text(template.description).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(template.author).font(.caption2).foregroundColor(.secondary)
                    Text("v\(template.version)").font(.caption2).foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow)
                        Text("\(template.rating, specifier: "%.1f")").font(.caption2)
                    }
                    Text("· \(template.downloadCount) 下载").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if template.isLocal {
                Label("已安装", systemImage: "checkmark.circle.fill").font(.caption).foregroundColor(.green)
            } else {
                Button("安装") { market.installTemplate(template.id) }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - 模板详情

struct MarketTemplateDetailView: View {
    let template: UserTemplate
    @Environment(\.dismiss) var dismiss
    @StateObject private var market = TemplateMarket.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: template.category.icon).font(.title).foregroundColor(.accentColor)
                Text(template.name).font(.title2).bold()
                Spacer()
                Button("关闭") { dismiss() }.buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox("基本信息") {
                VStack(alignment: .leading, spacing: 6) {
                    TDetailRow("描述", template.description)
                    TDetailRow("分类", template.category.rawValue)
                    TDetailRow("作者", template.author)
                    TDetailRow("版本", template.version)
                    TDetailRow("评分", String(format: "%.1f", template.rating) + " / 5.0")
                    TDetailRow("下载", "\(template.downloadCount)")
                    if let date = template.installDate {
                        TDetailRow("安装时间", date.formatted(date: .numeric, time: .shortened))
                    }
                }
                .padding(8)
            }

            GroupBox("标签") {
                HStack {
                    ForEach(template.tags, id: \.self) { tag in
                        Text(tag).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                    }
                }
                .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                if template.isLocal {
                    Button("卸载") { market.uninstallTemplate(template.id); dismiss() }
                        .buttonStyle(.bordered).foregroundColor(.red)
                    Button("应用") { dismiss() }.buttonStyle(.borderedProminent)
                } else {
                    Button("安装模板") { market.installTemplate(template.id); dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}

struct TDetailRow: View {
    let label: String; let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        HStack {
            Text(label).foregroundColor(.secondary).frame(width: 60, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - 创建模板

struct CreateTemplateSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var market = TemplateMarket.shared
    @State private var name = ""
    @State private var description = ""
    @State private var category: TemplateCategory = .design

    var body: some View {
        VStack(spacing: 16) {
            Text("创建新模板").font(.title2).bold()
            TextField("模板名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("描述", text: $description).textFieldStyle(.roundedBorder)
            Picker("分类", selection: $category) {
                ForEach(TemplateCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("创建") {
                    market.createTemplate(name: name, description: description, category: category)
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding().frame(width: 320)
    }
}