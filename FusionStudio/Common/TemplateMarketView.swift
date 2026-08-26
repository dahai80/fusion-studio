// Callers: ModuleDetailView routing.
// Refactored: GUI reads bridge.agentState.marketplaceEntries directly, TemplateMarket singleton removed.

import SwiftUI
import os

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

    var bridgeKey: String {
        switch self {
        case .all: return ""
        case .design: return "design"
        case .code: return "code"
        case .simulation: return "simulation"
        case .workflow: return "workflow"
        case .report: return "report"
        case .automation: return "automation"
        }
    }

    static func fromBridgeKey(_ key: String) -> TemplateCategory {
        switch key {
        case "design": return .design
        case "code": return .code
        case "simulation": return .simulation
        case "workflow": return .workflow
        case "report": return .report
        case "automation": return .automation
        default: return .all
        }
    }
}

struct TemplateMarketView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var bridge: AgentBridge
    @State private var showCreateSheet = false
    @State private var selectedEntry: MarketplaceEntryModel?
    @State private var viewMode: TemplateViewMode = .grid
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory = .all
    @State private var showFavoritesOnly = false
    @State private var favorites: Set<String> = []
    @State private var isLoading = false
    private let logger = Logger(subsystem: "com.fusion.studio", category: "TemplateMarket")

    enum TemplateViewMode: String, CaseIterable {
        case grid = "网格"; case list = "列表"
    }

    private var filteredEntries: [MarketplaceEntryModel] {
        var result = bridge.agentState.marketplaceEntries
        if selectedCategory != .all {
            result = result.filter { TemplateCategory.fromBridgeKey($0.category) == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        if showFavoritesOnly {
            result = result.filter { favorites.contains($0.id) }
        }
        return result
    }

    private func isInstalled(_ entry: MarketplaceEntryModel) -> Bool {
        bridge.agentState.agents.contains(where: { $0.id == entry.id })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("搜索模板...", text: $searchText).textFieldStyle(.plain)
                    .onSubmit {
                        Task { await search() }
                    }
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                Picker("", selection: $viewMode) {
                    ForEach(TemplateViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented).frame(width: 100)
                Toggle("仅收藏", isOn: $showFavoritesOnly).toggleStyle(.checkbox).controlSize(.small)
                Button(action: { showCreateSheet = true }) { Label("新建", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            .padding(8)
            .background(theme.surfaceSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(TemplateCategory.allCases, id: \.self) { cat in
                        let isSelected = selectedCategory == cat
                        Button(action: { selectedCategory = cat }) {
                            Label(cat.rawValue, systemImage: cat.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isSelected ? .accentColor : nil)
                    }
                }
                .padding(8)
            }

            Divider()

            if filteredEntries.isEmpty && !isLoading {
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
                            ForEach(filteredEntries) { entry in
                                TemplateCardView(entry: entry, isFavorite: favorites.contains(entry.id), isInstalled: isInstalled(entry))
                                    .onTapGesture { selectedEntry = entry }
                            }
                        }
                        .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredEntries) { entry in
                                TemplateListRow(entry: entry, isFavorite: favorites.contains(entry.id), isInstalled: isInstalled(entry))
                                    .onTapGesture { selectedEntry = entry }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) { CreateTemplateSheet() }
        .sheet(item: $selectedEntry) { entry in
            MarketEntryDetailView(entry: entry, isFavorite: favorites.contains(entry.id), isInstalled: isInstalled(entry))
        }
        .onAppear {
            Task { await search() }
        }
        .onChange(of: selectedCategory) { _ in
            Task { await search() }
        }
    }

    private func search() async {
        isLoading = true
        do {
            _ = try await bridge.marketplaceSearch(query: searchText, category: selectedCategory.bridgeKey)
            _ = try await bridge.fetchMarketplaceCategories()
        } catch {
            logger.error("search: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

struct TemplateCardView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var bridge: AgentBridge
    let entry: MarketplaceEntryModel
    let isFavorite: Bool
    let isInstalled: Bool
    @State private var localIsInstalled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: TemplateCategory.fromBridgeKey(entry.category).icon)
                    .font(.title2).foregroundColor(.accentColor)
                Spacer()
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundColor(isFavorite ? .yellow : .gray)
            }
            Text(entry.name).font(.headline).lineLimit(1)
            Text(entry.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
            HStack {
                Image(systemName: "person").font(.caption2)
                Text(entry.author).font(.caption2)
                Spacer()
                Image(systemName: "star.fill").font(.caption2).foregroundColor(.yellow)
                Text("\(entry.rating, specifier: "%.1f")").font(.caption2)
            }
            HStack {
                Text("v\(entry.version)").font(.caption2).foregroundColor(.secondary)
                Spacer()
                if localIsInstalled {
                    Label("已安装", systemImage: "checkmark.circle.fill").font(.caption2).foregroundColor(.green)
                } else {
                    Button("安装") {
                        Task {
                            _ = try? await bridge.marketplaceInstall(entryId: entry.id)
                            localIsInstalled = true
                        }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
        }
        .padding()
        .background(theme.surfaceSecondary)
        .cornerRadius(10)
        .onAppear { localIsInstalled = isInstalled }
    }
}

struct TemplateListRow: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject private var bridge: AgentBridge
    let entry: MarketplaceEntryModel
    let isFavorite: Bool
    let isInstalled: Bool
    @State private var localIsInstalled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: TemplateCategory.fromBridgeKey(entry.category).icon)
                .foregroundColor(.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.name).font(.headline)
                    if isFavorite { Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow) }
                }
                Text(entry.description).font(.caption).foregroundColor(.secondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text(entry.author).font(.caption2).foregroundColor(.secondary)
                    Text("v\(entry.version)").font(.caption2).foregroundColor(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(.yellow)
                        Text("\(entry.rating, specifier: "%.1f")").font(.caption2)
                    }
                    Text("· \(entry.downloads) 下载").font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            if localIsInstalled {
                Label("已安装", systemImage: "checkmark.circle.fill").font(.caption).foregroundColor(.green)
            } else {
                Button("安装") {
                    Task {
                        _ = try? await bridge.marketplaceInstall(entryId: entry.id)
                        localIsInstalled = true
                    }
                }.buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .padding(8)
        .background(theme.surfaceSecondary)
        .cornerRadius(8)
        .onAppear { localIsInstalled = isInstalled }
    }
}

struct MarketEntryDetailView: View {
    let entry: MarketplaceEntryModel
    let isFavorite: Bool
    let isInstalled: Bool
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var bridge: AgentBridge
    @State private var localIsInstalled: Bool = false
    @State private var isOperating: Bool = false
    @State private var operationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: TemplateCategory.fromBridgeKey(entry.category).icon)
                    .font(.title).foregroundColor(.accentColor)
                Text(entry.name).font(.title2).bold()
                Spacer()
                Button("关闭") { dismiss() }.buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox("基本信息") {
                VStack(alignment: .leading, spacing: 6) {
                    TDetailRow("描述", entry.description)
                    TDetailRow("分类", TemplateCategory.fromBridgeKey(entry.category).rawValue)
                    TDetailRow("作者", entry.author)
                    TDetailRow("版本", entry.version)
                    TDetailRow("评分", String(format: "%.1f", entry.rating) + " / 5.0")
                    TDetailRow("下载", "\(entry.downloads)")
                }
                .padding(8)
            }

            GroupBox("标签") {
                HStack {
                    ForEach(entry.tags, id: \.self) { tag in
                        Text(tag).font(.caption).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1)).cornerRadius(3)
                    }
                }
                .padding(8)
            }

            if let msg = operationMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(msg.contains("成功") ? .green : .orange)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.05))
                    .cornerRadius(6)
            }

            Spacer()

            HStack {
                Spacer()
                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                }
                if localIsInstalled {
                    Button("卸载") {
                        Task {
                            isOperating = true
                            operationMessage = nil
                            do {
                                let ok = try await bridge.marketplaceUninstall(entryId: entry.id)
                                operationMessage = ok ? "卸载成功" : "卸载失败"
                                if ok { localIsInstalled = false }
                            } catch {
                                operationMessage = "卸载失败: \(error.localizedDescription)"
                            }
                            isOperating = false
                        }
                    }
                    .buttonStyle(.bordered).foregroundColor(.red)
                    .disabled(isOperating)
                    Button("应用") {
                        Task {
                            isOperating = true
                            operationMessage = nil
                            do {
                                _ = try await bridge.templateInstantiate(templateId: entry.id)
                                operationMessage = "应用成功"
                            } catch {
                                operationMessage = "应用失败: \(error.localizedDescription)"
                            }
                            isOperating = false
                        }
                    }.buttonStyle(.borderedProminent)
                    .disabled(isOperating)
                } else {
                    Button("安装模板") {
                        Task {
                            isOperating = true
                            operationMessage = nil
                            do {
                                _ = try await bridge.marketplaceInstall(entryId: entry.id)
                                localIsInstalled = true
                                operationMessage = "安装成功"
                            } catch {
                                operationMessage = "安装失败: \(error.localizedDescription)"
                            }
                            isOperating = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isOperating)
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 400, height: 480)
        .onAppear { localIsInstalled = isInstalled }
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

struct CreateTemplateSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var bridge: AgentBridge
    @State private var name = ""
    @State private var description = ""
    @State private var category: TemplateCategory = .design
    @State private var tags = ""
    @State private var version = "1.0.0"

    var body: some View {
        VStack(spacing: 16) {
            Text("发布新模板").font(.title2).bold()
            TextField("模板名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("描述", text: $description).textFieldStyle(.roundedBorder)
            Picker("分类", selection: $category) {
                ForEach(TemplateCategory.allCases.filter { $0 != .all }, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }
            TextField("标签 (逗号分隔)", text: $tags).textFieldStyle(.roundedBorder)
            TextField("版本", text: $version).textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.bordered)
                Button("发布") {
                    let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    Task {
                        _ = try? await bridge.marketplacePublish(
                            name: name,
                            author: "本地",
                            description: description,
                            category: category.bridgeKey,
                            tags: tagList,
                            version: version
                        )
                    }
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(name.isEmpty)
            }
        }
        .padding().frame(width: 320)
    }
}
