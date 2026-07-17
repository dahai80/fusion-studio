import Foundation
import SwiftUI
import Combine

// MARK: - 插件清单

struct PluginManifest: Codable {
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let minAppVersion: String
    let entryPoint: String
    let permissions: [PluginPermission]
    let categories: [String]
    let icon: String
    let homepage: String?

    enum PluginPermission: String, Codable, CaseIterable {
        case files    = "文件访问"
        case network  = "网络访问"
        case mlx      = "MLX 推理"
        case shell    = "Shell 执行"
        case ui       = "UI 扩展"
        case storage  = "本地存储"

        var description: String {
            switch self {
            case .files:   return "读取和写入文件系统"
            case .network: return "发起网络请求"
            case .mlx:     return "调用 fusion-mlx 推理接口"
            case .shell:   return "执行 Shell 命令"
            case .ui:      return "在 Fusion Studio 中添加 UI 面板"
            case .storage: return "读写本地存储"
            }
        }
    }
}

// MARK: - 插件状态

enum PluginState: Equatable {
    case inactive
    case active
    case error(String)
}

// MARK: - 插件

struct Plugin: Identifiable, Hashable {
    let id: String
    var manifest: PluginManifest
    var state: PluginState
    var installDate: Date
    var installPath: String
    var config: [String: Any]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Plugin, rhs: Plugin) -> Bool { lhs.id == rhs.id }
}

// MARK: - 插件指令

struct PluginCommand: Identifiable {
    let id: String
    let pluginId: String
    let name: String
    let action: () -> Void
}

// MARK: - 插件管理器

class PluginManager: ObservableObject {
    static let shared = PluginManager()

    @Published var plugins: [Plugin] = []
    @Published var showSystemPlugins = false
    @Published var lastScanDate: Date?

    private let fileManager = FileManager.default

    var pluginDir: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".fusion-studio/plugins")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    var activePluginCount: Int { plugins.filter { $0.state == .active }.count }
    var errorPluginCount: Int { plugins.filter { if case .error = $0.state { return true }; return false }.count }

    init() {
        loadBuiltinPlugins()
        scanInstalledPlugins()
    }

    // MARK: - 内置插件

    private func loadBuiltinPlugins() {
        let builtins: [(PluginManifest, PluginState)] = [
            (PluginManifest(
                id: "builtin-terminal", name: "高级终端", version: "1.0.0",
                author: "Fusion Studio", description: "增强终端功能，支持多标签页和主题",
                minAppVersion: "1.0.0", entryPoint: "terminal", permissions: [.shell, .ui],
                categories: ["工具", "终端"], icon: "terminal", homepage: nil
            ), .active),
            (PluginManifest(
                id: "builtin-git", name: "Git 可视化", version: "1.0.0",
                author: "Fusion Studio", description: "图形化 Git 操作：提交、分支、合并",
                minAppVersion: "1.0.0", entryPoint: "git", permissions: [.shell, .ui],
                categories: ["开发", "版本控制"], icon: "arrow.triangle.branch", homepage: nil
            ), .active),
            (PluginManifest(
                id: "builtin-export", name: "批量导出", version: "1.0.0",
                author: "Fusion Studio", description: "批量导出设计稿、代码、仿真结果",
                minAppVersion: "1.0.0", entryPoint: "export", permissions: [.files, .ui],
                categories: ["工具", "导出"], icon: "square.and.arrow.up", homepage: nil
            ), .active),
            (PluginManifest(
                id: "builtin-markdown", name: "Markdown 预览", version: "1.0.0",
                author: "Fusion Studio", description: "实时 Markdown 渲染与预览",
                minAppVersion: "1.0.0", entryPoint: "markdown", permissions: [.ui],
                categories: ["文档", "预览"], icon: "doc.text.magnifyingglass", homepage: nil
            ), .active),
        ]

        for (manifest, state) in builtins {
            let plugin = Plugin(
                id: manifest.id,
                manifest: manifest,
                state: state,
                installDate: Date(),
                installPath: "builtin",
                config: [:]
            )
            plugins.append(plugin)
        }
    }

    // MARK: - 插件扫描

    func scanInstalledPlugins() {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: pluginDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }

        let pluginDirs = contents.filter { $0.pathExtension == "plugin" || $0.lastPathComponent.hasSuffix(".fusion") }
        var newPlugins: [Plugin] = []

        for dir in pluginDirs {
            let manifestPath = dir.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestPath),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data) else { continue }

            let attrs = try? fileManager.attributesOfItem(atPath: dir.path)
            let date = attrs?[.creationDate] as? Date ?? Date()

            let plugin = Plugin(
                id: manifest.id,
                manifest: manifest,
                state: .inactive,
                installDate: date,
                installPath: dir.path,
                config: [:]
            )
            newPlugins.append(plugin)
        }

        // 合并已安装插件
        for plugin in newPlugins {
            if !plugins.contains(where: { $0.id == plugin.id }) {
                plugins.append(plugin)
            }
        }

        lastScanDate = Date()
        objectWillChange.send()
    }

    // MARK: - 插件操作

    func installPlugin(at url: URL) -> Bool {
        let fileName = url.lastPathComponent
        let dest = pluginDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: dest.path) {
                try fileManager.removeItem(at: dest)
            }
            try fileManager.copyItem(at: url, to: dest)
            scanInstalledPlugins()
            return true
        } catch {
            print("插件安装失败: \(error)")
            return false
        }
    }

    func activatePlugin(_ id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].state = .active
        objectWillChange.send()
    }

    func deactivatePlugin(_ id: String) {
        guard let idx = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[idx].state = .inactive
        objectWillChange.send()
    }

    func uninstallPlugin(_ id: String) {
        guard let plugin = plugins.first(where: { $0.id == id }),
              plugin.installPath != "builtin" else { return }

        try? fileManager.removeItem(atPath: plugin.installPath)
        plugins.removeAll { $0.id == id }
        objectWillChange.send()
    }

    func openPluginFolder() {
        NSWorkspace.shared.open(pluginDir)
    }

    func createPluginTemplate(name: String, author: String) -> URL? {
        let pluginName = name.lowercased().replacingOccurrences(of: " ", with: "-")
        let pluginDir = pluginDir.appendingPathComponent("\(pluginName).plugin")
        try? fileManager.createDirectory(at: pluginDir, withIntermediateDirectories: true)

        let manifest = PluginManifest(
            id: "custom-\(pluginName)",
            name: name,
            version: "0.1.0",
            author: author,
            description: "Fusion Studio 插件",
            minAppVersion: "1.0.0",
            entryPoint: "main.py",
            permissions: [.ui, .storage],
            categories: ["自定义"],
            icon: "puzzlepiece.extension",
            homepage: nil
        )

        let manifestPath = pluginDir.appendingPathComponent("manifest.json")
        if let data = try? JSONEncoder().encode(manifest) {
            try? data.write(to: manifestPath)
        }

        // 创建入口文件
        let mainCode = """
        # Fusion Studio Plugin: \(name)
        # \(author)

        def on_load():
            \"\"\"插件加载时调用\"\"\"
            pass

        def on_unload():
            \"\"\"插件卸载时调用\"\"\"
            pass

        def on_register_commands():
            \"\"\"注册命令\"\"\"
            return []

        def on_render_panel():
            \"\"\"渲染 UI 面板（返回 HTML）\"\"\"
            return f\"\"\"<div>
                <h3>\(name)</h3>
                <p>插件已加载</p>
            </div>\"\"\"
        """
        let mainPath = pluginDir.appendingPathComponent("main.py")
        try? mainCode.write(to: mainPath, atomically: true, encoding: .utf8)

        scanInstalledPlugins()
        return pluginDir
    }
}

// MARK: - 插件市场模型

struct PluginMarketItem: Identifiable {
    let id: String
    let name: String
    let author: String
    let description: String
    let version: String
    let downloads: Int
    let rating: Double
    let iconName: String
    let isInstalled: Bool
    let hasUpdate: Bool
}

// MARK: - 插件面板

struct PluginView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @State private var selectedTab: PluginTab = .installed
    @State private var showFilePicker = false
    @State private var showCreateTemplate = false
    @State private var templateName = ""
    @State private var templateAuthor = ""

    enum PluginTab: String, CaseIterable {
        case installed = "已安装"
        case market    = "插件市场"
        case develop   = "开发"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(PluginTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tabIcon(tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            switch selectedTab {
            case .installed:
                InstalledPluginsView()
            case .market:
                PluginMarketView()
            case .develop:
                PluginDeveloperView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { showFilePicker = true }) {
                    Label("安装插件", systemImage: "plus")
                }
                Button(action: { pluginManager.scanInstalledPlugins() }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                Button(action: { pluginManager.openPluginFolder() }) {
                    Label("插件目录", systemImage: "folder")
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.folder, .zip],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                pluginManager.installPlugin(at: url)
            }
        }
        .sheet(isPresented: $showCreateTemplate) {
            createTemplateSheet
        }
    }

    private var createTemplateSheet: some View {
        VStack(spacing: 16) {
            Text("创建插件模板")
                .font(.title2)
                .bold()

            TextField("插件名称", text: $templateName)
                .textFieldStyle(.roundedBorder)

            TextField("作者", text: $templateAuthor)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("取消") { showCreateTemplate = false }
                    .buttonStyle(.bordered)
                Button("创建") {
                    if let url = pluginManager.createPluginTemplate(name: templateName, author: templateAuthor) {
                        NSWorkspace.shared.open(url)
                    }
                    templateName = ""
                    templateAuthor = ""
                    showCreateTemplate = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(templateName.isEmpty || templateAuthor.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func tabIcon(_ tab: PluginTab) -> String {
        switch tab {
        case .installed: return "square.grid.3x2"
        case .market:    return "bag"
        case .develop:   return "hammer"
        }
    }
}

// MARK: - 已安装插件

struct InstalledPluginsView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @State private var selectedPlugin: Plugin?
    @State private var showUninstallAlert = false

    var body: some View {
        HSplitView {
            // 列表
            List(selection: $selectedPlugin) {
                Section("内置插件") {
                    ForEach(pluginManager.plugins.filter { $0.installPath == "builtin" }) { plugin in
                        PluginRow(plugin: plugin)
                            .tag(plugin)
                    }
                }
                Section("用户插件") {
                    let userPlugins = pluginManager.plugins.filter { $0.installPath != "builtin" }
                    if userPlugins.isEmpty {
                        Text("暂无用户插件")
                            .foregroundColor(.secondary)
                    }
                    ForEach(userPlugins) { plugin in
                        PluginRow(plugin: plugin)
                            .tag(plugin)
                            .contextMenu {
                                Button(plugin.state == .active ? "停用" : "启用") {
                                    if plugin.state == .active {
                                        pluginManager.deactivatePlugin(plugin.id)
                                    } else {
                                        pluginManager.activatePlugin(plugin.id)
                                    }
                                }
                                Button("卸载", role: .destructive) {
                                    selectedPlugin = plugin
                                    showUninstallAlert = true
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 280)

            // 详情
            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("选择一个插件查看详情")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .alert("确认卸载", isPresented: $showUninstallAlert) {
            Button("取消", role: .cancel) {}
            Button("卸载", role: .destructive) {
                if let plugin = selectedPlugin {
                    pluginManager.uninstallPlugin(plugin.id)
                }
            }
        } message: {
            Text("确定要卸载此插件吗？此操作不可撤销。")
        }
    }
}

struct PluginRow: View {
    let plugin: Plugin

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: plugin.manifest.icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(plugin.manifest.name)
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(stateColor)
                        .frame(width: 6, height: 6)
                }
                Text(plugin.manifest.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack {
                    Text("v\(plugin.manifest.version)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if plugin.installPath != "builtin" {
                        Text(plugin.installDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var stateColor: Color {
        switch plugin.state {
        case .active:   return .green
        case .inactive: return .gray
        case .error:    return .red
        }
    }
}

// MARK: - 插件详情

struct PluginDetailView: View {
    let plugin: Plugin
    @StateObject private var pluginManager = PluginManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: plugin.manifest.icon)
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(plugin.manifest.name)
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    PluginStateBadge(state: plugin.state)
                }
                .padding(.horizontal)

                Divider()

                GroupBox("基本信息") {
                    VStack(alignment: .leading, spacing: 6) {
                        PluginDetailRow("ID", plugin.manifest.id)
                        PluginDetailRow("版本", plugin.manifest.version)
                        PluginDetailRow("作者", plugin.manifest.author)
                        PluginDetailRow("描述", plugin.manifest.description)
                        PluginDetailRow("最低版本", "Fusion Studio \(plugin.manifest.minAppVersion)")
                        PluginDetailRow("入口", plugin.manifest.entryPoint)
                        PluginDetailRow("安装路径", plugin.installPath)
                        if plugin.installPath != "builtin" {
                            PluginDetailRow("安装时间", plugin.installDate.formatted(date: .numeric, time: .shortened))
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox("权限") {
                    ForEach(plugin.manifest.permissions, id: \.rawValue) { perm in
                        HStack {
                            Image(systemName: permissionIcon(perm))
                                .foregroundColor(.accentColor)
                                .frame(width: 16)
                            Text(perm.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text(perm.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox("分类") {
                    HStack {
                        ForEach(plugin.manifest.categories, id: \.self) { cat in
                            Text(cat)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                Spacer()

                // 操作按钮
                HStack {
                    Spacer()
                    if plugin.installPath != "builtin" {
                        if plugin.state == .active {
                            Button("停用") { pluginManager.deactivatePlugin(plugin.id) }
                                .buttonStyle(.bordered)
                        } else {
                            Button("启用") { pluginManager.activatePlugin(plugin.id) }
                                .buttonStyle(.borderedProminent)
                        }
                        Button("卸载", role: .destructive) { pluginManager.uninstallPlugin(plugin.id) }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .padding()
            }
            .padding(.vertical)
        }
    }

    private func permissionIcon(_ perm: PluginManifest.PluginPermission) -> String {
        switch perm {
        case .files:   return "folder"
        case .network: return "antenna.radiowaves.left.and.right"
        case .mlx:     return "cpu"
        case .shell:   return "terminal"
        case .ui:      return "rectangle.3.group"
        case .storage: return "externaldrive"
        }
    }
}

struct PluginStateBadge: View {
    let state: PluginState

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }

    private var color: Color {
        switch state {
        case .active:   return .green
        case .inactive: return .gray
        case .error:    return .red
        }
    }

    private var text: String {
        switch state {
        case .active:   return "运行中"
        case .inactive: return "已停用"
        case .error(let e): return "错误: \(e)"
        }
    }
}

struct PluginDetailRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
            Spacer()
        }
    }
}

// MARK: - 插件市场

struct PluginMarketView: View {
    let marketItems: [PluginMarketItem] = [
        PluginMarketItem(id: "theme-dark", name: "深色主题增强", author: "Fusion Labs", description: "更多深色主题变体，护眼模式", version: "1.2.0", downloads: 1280, rating: 4.5, iconName: "paintpalette", isInstalled: false, hasUpdate: false),
        PluginMarketItem(id: "code-lint", name: "代码检查器", author: "DevTools", description: "集成 ESLint、SwiftLint 等 linter", version: "0.8.0", downloads: 856, rating: 4.2, iconName: "checkmark.shield", isInstalled: true, hasUpdate: true),
        PluginMarketItem(id: "sim-extra", name: "仿真扩展包", author: "SimLab", description: "额外的物理引擎和机器人模型", version: "1.0.0", downloads: 2340, rating: 4.8, iconName: "gearshape.2.fill", isInstalled: false, hasUpdate: false),
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280))], spacing: 12) {
                ForEach(marketItems) { item in
                    MarketCard(item: item)
                }
            }
            .padding()
        }
    }
}

struct MarketCard: View {
    let item: PluginMarketItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: item.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if item.hasUpdate {
                    Text("可更新")
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            Text(item.name)
                .font(.headline)

            Text(item.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Image(systemName: "person")
                    .font(.caption2)
                Text(item.author)
                    .font(.caption2)
                Spacer()
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundColor(.yellow)
                Text("\(item.rating, specifier: "%.1f")")
                    .font(.caption2)
                Text("· \(item.downloads)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("v\(item.version)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button(item.isInstalled ? (item.hasUpdate ? "更新" : "已安装") : "安装") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(item.isInstalled && !item.hasUpdate)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 插件开发

struct PluginDeveloperView: View {
    @StateObject private var pluginManager = PluginManager.shared
    @State private var showCreateTemplate = false
    @State private var templateName = ""
    @State private var templateAuthor = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("快速开始") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fusion Studio 插件开发指南")
                            .font(.headline)
                        Text("插件是 Python 脚本包，包含 manifest.json 清单文件和入口脚本。将插件文件夹放入以下目录即可安装：")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text(pluginManager.pluginDir.path)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.accentColor)
                            Button("打开") { pluginManager.openPluginFolder() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox("模板生成") {
                    VStack(spacing: 12) {
                        Text("创建一个新的插件模板项目")
                            .font(.subheadline)
                        HStack {
                            TextField("插件名称", text: $templateName)
                                .textFieldStyle(.roundedBorder)
                            TextField("作者", text: $templateAuthor)
                                .textFieldStyle(.roundedBorder)
                            Button("生成") {
                                if let url = pluginManager.createPluginTemplate(name: templateName, author: templateAuthor) {
                                    NSWorkspace.shared.open(url)
                                }
                                templateName = ""
                                templateAuthor = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(templateName.isEmpty || templateAuthor.isEmpty)
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                GroupBox("插件结构") {
                    VStack(alignment: .leading, spacing: 4) {
                        CodeLine("my-plugin.plugin/")
                        CodeLine("├── manifest.json    # 插件清单")
                        CodeLine("├── main.py          # 入口脚本")
                        CodeLine("├── assets/          # 资源文件")
                        CodeLine("└── README.md        # 说明文档")
                    }
                    .padding(8)
                    .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal)

                GroupBox("manifest.json 示例") {
                    Text("""
                    {
                      "id": "my-plugin",
                      "name": "我的插件",
                      "version": "0.1.0",
                      "author": "Your Name",
                      "description": "插件描述",
                      "minAppVersion": "1.0.0",
                      "entryPoint": "main.py",
                      "permissions": ["ui", "storage"],
                      "categories": ["自定义"],
                      "icon": "puzzlepiece.extension"
                    }
                    """)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

struct CodeLine: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
    }
}