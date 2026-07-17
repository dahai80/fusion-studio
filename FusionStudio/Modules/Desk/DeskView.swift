import SwiftUI

/// 自动化模板
struct DeskTemplate: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var category: DeskCategory
    var icon: String
    var lastRun: Date?
    var runCount: Int
    var isFavorite: Bool
    var steps: [DeskStep]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: DeskTemplate, rhs: DeskTemplate) -> Bool { lhs.id == rhs.id }

    enum DeskCategory: String, CaseIterable {
        case file    = "文件管理"
        case system  = "系统操作"
        case network = "网络"
        case ai      = "AI 处理"
        case custom  = "自定义"

        var icon: String {
            switch self {
            case .file:   return "folder"
            case .system: return "gearshape"
            case .network: return "antenna.radiowaves.left.and.right"
            case .ai:     return "brain"
            case .custom: return "wrench.and.screwdriver"
            }
        }
    }
}

/// 自动化步骤
struct DeskStep: Identifiable, Hashable {
    let id: String
    var action: String
    var target: String
    var parameters: [String: String]
    var order: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: DeskStep, rhs: DeskStep) -> Bool { lhs.id == rhs.id }
}

/// 自动化任务
struct DeskTask: Identifiable, Hashable {
    let id: String
    let templateId: String
    var name: String
    var status: TaskStatus
    var progress: Double
    var startedAt: Date?
    var completedAt: Date?
    var log: [String]

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    static func == (lhs: DeskTask, rhs: DeskTask) -> Bool { lhs.id == rhs.id }
}

// MARK: - 预设模板

let deskPresets: [DeskTemplate] = [
    DeskTemplate(id: "t1", name: "整理下载文件夹", description: "按文件类型自动分类整理 Downloads 目录", category: .file, icon: "tray.and.arrow.down", lastRun: nil, runCount: 0, isFavorite: true, steps: [
        DeskStep(id: "s1", action: "list_files", target: "~/Downloads", parameters: ["recursive": "false"], order: 1),
        DeskStep(id: "s2", action: "categorize", target: "~/Downloads", parameters: ["by": "extension"], order: 2),
        DeskStep(id: "s3", action: "move_files", target: "~/Downloads/Organized", parameters: ["create_dirs": "true"], order: 3),
    ]),
    DeskTemplate(id: "t2", name: "清理缓存", description: "清理系统缓存和临时文件释放空间", category: .system, icon: "trash", lastRun: nil, runCount: 0, isFavorite: true, steps: [
        DeskStep(id: "s4", action: "clean_cache", target: "~/Library/Caches", parameters: ["dry_run": "true"], order: 1),
        DeskStep(id: "s5", action: "clean_temp", target: "/tmp", parameters: ["older_than": "7d"], order: 2),
        DeskStep(id: "s6", action: "report", target: "", parameters: ["format": "size"], order: 3),
    ]),
    DeskTemplate(id: "t3", name: "批量重命名", description: "按规则批量重命名文件（序列号/日期/前缀）", category: .file, icon: "character.cursor.ibeam", lastRun: nil, runCount: 0, isFavorite: false, steps: [
        DeskStep(id: "s7", action: "select_files", target: "", parameters: ["pattern": "*.*"], order: 1),
        DeskStep(id: "s8", action: "rename", target: "", parameters: ["rule": "prefix_001", "start": "1"], order: 2),
    ]),
    DeskTemplate(id: "t4", name: "AI 批量处理图片", description: "使用 fusion-mlx 批量处理图片（压缩/格式转换）", category: .ai, icon: "photo.on.rectangle", lastRun: nil, runCount: 0, isFavorite: false, steps: [
        DeskStep(id: "s9", action: "scan_images", target: "~/Pictures", parameters: ["formats": "png,jpg"], order: 1),
        DeskStep(id: "s10", action: "ai_process", target: "", parameters: ["task": "compress", "quality": "85"], order: 2),
        DeskStep(id: "s11", action: "save_output", target: "~/Pictures/Processed", parameters: ["overwrite": "false"], order: 3),
    ]),
    DeskTemplate(id: "t5", name: "定时备份", description: "将指定目录备份到备份位置，支持增量", category: .system, icon: "clock.arrow.circlepath", lastRun: nil, runCount: 0, isFavorite: true, steps: [
        DeskStep(id: "s12", action: "select_source", target: "~/Documents", parameters: ["include": "*.pdf,*.docx"], order: 1),
        DeskStep(id: "s13", action: "backup", target: "~/Backups", parameters: ["type": "incremental", "compress": "true"], order: 2),
        DeskStep(id: "s14", action: "verify", target: "", parameters: ["checksum": "sha256"], order: 3),
    ]),
    DeskTemplate(id: "t6", name: "网络监控", description: "监控网络状态并记录异常", category: .network, icon: "network", lastRun: nil, runCount: 0, isFavorite: false, steps: [
        DeskStep(id: "s15", action: "ping_test", target: "8.8.8.8", parameters: ["count": "5", "interval": "1s"], order: 1),
        DeskStep(id: "s16", action: "speed_test", target: "", parameters: ["server": "auto"], order: 2),
        DeskStep(id: "s17", action: "log_result", target: "", parameters: ["output": "csv"], order: 3),
    ]),
]

// MARK: - 主视图

struct DeskView: View {
    @State private var templates: [DeskTemplate] = deskPresets
    @State private var selectedTemplate: DeskTemplate?
    @State private var tasks: [DeskTask] = []
    @State private var searchText = ""
    @State private var selectedCategory: DeskTemplate.DeskCategory?
    @State private var showTemplateEditor = false
    @State private var viewMode: ViewMode = .grid

    enum ViewMode: String, CaseIterable {
        case grid  = "网格"
        case list  = "列表"
        case run   = "运行历史"
    }

    var filteredTemplates: [DeskTemplate] {
        var result = templates
        if let cat = selectedCategory {
            result = result.filter { $0.category == cat }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索自动化模板...", text: $searchText)
                    .textFieldStyle(.plain)

                Spacer()

                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Button(action: { showTemplateEditor = true }) {
                    Label("新建模板", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 分类筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DeskTemplate.DeskCategory.allCases, id: \.self) { cat in
                        let isSelected = selectedCategory == cat
                        Button(action: {
                            withAnimation { selectedCategory = selectedCategory == cat ? nil : cat }
                        }) {
                            Label(cat.rawValue, systemImage: cat.icon)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isSelected ? Color.accentColor : nil)
                    }
                }
                .padding(8)
            }

            Divider()

            // 内容
            switch viewMode {
            case .grid:
                TemplateGridView(templates: filteredTemplates, selectedTemplate: $selectedTemplate, onRun: runTemplate)
            case .list:
                TemplateListView(templates: filteredTemplates, selectedTemplate: $selectedTemplate, onRun: runTemplate)
            case .run:
                TaskHistoryView(tasks: tasks)
            }
        }
        .sheet(isPresented: $showTemplateEditor) {
            TemplateEditorView { template in
                templates.append(template)
            }
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateDetailView(template: template, onRun: runTemplate)
        }
    }

    private func runTemplate(_ template: DeskTemplate) {
        let task = DeskTask(
            id: UUID().uuidString.prefix(8).lowercased(),
            templateId: template.id,
            name: template.name,
            status: .running,
            progress: 0,
            startedAt: Date(),
            log: ["开始执行: \(template.name)"]
        )
        tasks.append(task)

        // 模拟执行
        Task { [self] in
            
            for i in 0..<template.steps.count {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                        self.tasks[idx].progress = Double(i + 1) / Double(template.steps.count)
                        self.tasks[idx].log.append("步骤 \(i+1)/\(template.steps.count): \(template.steps[i].action) → \(template.steps[i].target)")
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                    tasks[idx].status = .completed
                    tasks[idx].progress = 1.0
                    tasks[idx].completedAt = Date()
                    tasks[idx].log.append("✅ 完成: \(template.name)")
                }
                if let tIdx = templates.firstIndex(where: { $0.id == template.id }) {
                    templates[tIdx].lastRun = Date()
                    templates[tIdx].runCount += 1
                }
            }
        }
    }
}

// MARK: - 网格视图

struct TemplateGridView: View {
    let templates: [DeskTemplate]
    @Binding var selectedTemplate: DeskTemplate?
    let onRun: (DeskTemplate) -> Void

    let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]

    var body: some View {
        if templates.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("暂无匹配模板")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(templates) { template in
                        TemplateCard(template: template, onRun: onRun)
                            .onTapGesture { selectedTemplate = template }
                    }
                }
                .padding()
            }
        }
    }
}

struct TemplateCard: View {
    let template: DeskTemplate
    let onRun: (DeskTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Spacer()
                if template.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }

            Text(template.name)
                .font(.headline)
                .lineLimit(1)

            Text(template.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Spacer()

            HStack {
                Text("\(template.steps.count) 步")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if let last = template.lastRun {
                    Text(last, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: { onRun(template) }) {
                Label("运行", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .frame(height: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - 列表视图

struct TemplateListView: View {
    let templates: [DeskTemplate]
    @Binding var selectedTemplate: DeskTemplate?
    let onRun: (DeskTemplate) -> Void

    var body: some View {
        List(templates) { template in
            HStack(spacing: 12) {
                Image(systemName: template.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 12) {
                    Text("\(template.steps.count) 步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(template.category.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(3)

                    Button(action: { onRun(template) }) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture { selectedTemplate = template }
        }
    }
}

// MARK: - 任务历史

struct TaskHistoryView: View {
    let tasks: [DeskTask]

    var body: some View {
        if tasks.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("暂无运行记录")
                    .foregroundColor(.secondary)
                Text("运行自动化模板后，执行记录将显示在这里")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else {
            List(tasks.reversed()) { task in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: task.status.icon)
                            .foregroundColor(task.status.color)
                        Text(task.name)
                            .font(.headline)
                        Spacer()
                        Text(task.status.rawValue)
                            .font(.caption)
                            .foregroundColor(task.status.color)
                    }

                    ProgressView(value: task.progress)
                        .tint(task.status.color)

                    if let start = task.startedAt {
                        HStack {
                            Text("开始: \(start.formatted(date: .numeric, time: .shortened))")
                            if let end = task.completedAt {
                                Text("结束: \(end.formatted(date: .numeric, time: .shortened))")
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }

                    if !task.log.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(task.log.suffix(3), id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(6)
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - 模板详情

struct TemplateDetailView: View {
    let template: DeskTemplate
    let onRun: (DeskTemplate) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: template.icon)
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text(template.name)
                    .font(.title2)
                    .bold()
                Spacer()
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }

            Divider()

            GroupBox("基本信息") {
                VStack(alignment: .leading, spacing: 6) {
                    DetailRow("描述", template.description)
                    DetailRow("分类", template.category.rawValue)
                    DetailRow("步骤数", "\(template.steps.count)")
                    DetailRow("运行次数", "\(template.runCount)")
                    if let last = template.lastRun {
                        DetailRow("上次运行", last.formatted(date: .numeric, time: .shortened))
                    }
                }
                .padding(8)
            }

            GroupBox("执行步骤") {
                ForEach(template.steps.sorted(by: { $0.order < $1.order })) { step in
                    HStack(spacing: 8) {
                        Text("\(step.order)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        Text(step.action)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)
                        Text(step.target)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .padding(8)
            }

            Spacer()

            HStack {
                Spacer()
                Button(action: { showConfirm = true }) {
                    Label("运行此模板", systemImage: "play.fill")
                        .frame(width: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Spacer()
            }
        }
        .padding()
        .frame(width: 460, height: 500)
        .alert("确认运行", isPresented: $showConfirm) {
            Button("取消", role: .cancel) {}
            Button("运行") {
                onRun(template)
                dismiss()
            }
        } message: {
            Text("将执行「\(template.name)」，共 \(template.steps.count) 个步骤")
        }
    }
}

// MARK: - 模板编辑器

struct TemplateEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var category: DeskTemplate.DeskCategory = .custom
    @State private var steps: [DeskStep] = []
    let onSave: (DeskTemplate) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("新建自动化模板")
                .font(.title2)
                .bold()

            TextField("模板名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("描述", text: $description)
                .textFieldStyle(.roundedBorder)

            Picker("分类", selection: $category) {
                ForEach(DeskTemplate.DeskCategory.allCases, id: \.self) { cat in
                    Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                }
            }

            HStack {
                Text("执行步骤")
                    .font(.headline)
                Spacer()
                Button(action: addStep) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            List {
                ForEach(steps.indices, id: \.self) { i in
                    HStack {
                        Text("\(i + 1)")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                        TextField("动作", text: Binding(
                            get: { steps[i].action },
                            set: { steps[i].action = $0 }
                        ))
                        .frame(width: 120)
                        TextField("目标", text: Binding(
                            get: { steps[i].target },
                            set: { steps[i].target = $0 }
                        ))
                    }
                }
                .onDelete { steps.remove(atOffsets: $0) }
            }
            .frame(minHeight: 100)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.bordered)
                Button("保存") {
                    let template = DeskTemplate(
                        id: "custom-\(UUID().uuidString.prefix(6))",
                        name: name.isEmpty ? "新模板" : name,
                        description: description,
                        category: category,
                        icon: "wrench.and.screwdriver",
                        lastRun: nil,
                        runCount: 0,
                        isFavorite: false,
                        steps: steps.enumerated().map { i, s in
                            DeskStep(id: "step-\(i)", action: s.action, target: s.target, parameters: [:], order: i + 1)
                        }
                    )
                    onSave(template)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 420, height: 500)
    }

    private func addStep() {
        steps.append(DeskStep(id: "step-\(steps.count)", action: "", target: "", parameters: [:], order: steps.count + 1))
    }
}