import SwiftUI
import os.log

private let fsbLog = Logger(subsystem: "com.fusion.studio", category: "FSB")

struct FSBWorkspaceView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var appState: AppState
    @Environment(\.studioTheme) private var theme

    @State private var workspaces: [[String: Any]] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var isGridView = true
    @State private var selectedWsId: String? = nil
    @State private var showCreateDialog = false
    @State private var showRenameDialog = false
    @State private var renameWsId = ""
    @State private var renameWsName = ""
    @State private var showExportSheet = false
    @State private var exportData: String = ""
    @State private var fsbAvailable = false
    @State private var showOnboarding = false

    var body: some View {
        HStack(spacing: 0) {
            workspaceListPanel
            if let wsId = selectedWsId {
                FSBWorkbenchView(workspaceId: wsId, onBack: { selectedWsId = nil })
            } else {
                emptyStatePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkFSBHealth()
            loadWorkspaces()
        }
        .sheet(isPresented: $showCreateDialog) {
            FSBCreateWorkspaceDialog(
                ipc: ipc,
                onCreate: { title, desc, projectId in
                    createWorkspace(title: title, desc: desc, projectId: projectId)
                }
            )
        }
        .alert("重命名工作台", isPresented: $showRenameDialog) {
            TextField("名称", text: $renameWsName)
            Button("确认") { renameWorkspace() }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showExportSheet) {
            VStack(spacing: theme.spacingM) {
                Text("导出工作台")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                TextEditor(text: .constant(exportData))
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .frame(minWidth: 500, minHeight: 300)
                HStack {
                    Button("复制到剪贴板") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(exportData, forType: .string)
                    }
                    .buttonStyle(.borderedProminent)
                    Button("关闭") { showExportSheet = false }
                }
            }
            .padding(theme.spacingL)
            .frame(minWidth: 560, minHeight: 400)
        }
        .sheet(isPresented: $showOnboarding) {
            FSBOnboardingDialog()
        }
    }

    private var workspaceListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            searchBar
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if filteredWorkspaces.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "storefront")
                        .font(.system(size: 32))
                        .foregroundStyle(theme.textTertiary)
                    Text(searchText.isEmpty ? "暂无工作台" : "没有匹配的工作台")
                        .foregroundStyle(theme.textSecondary)
                        .font(.system(size: theme.textSize))
                    if searchText.isEmpty {
                        Button(action: { showCreateDialog = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("创建工作台")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                Spacer()
            } else {
                if isGridView {
                    gridView
                } else {
                    listView
                }
            }
        }
        .frame(width: 300)
        .background(theme.contentBg)
    }

    private var headerBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "storefront")
                .foregroundStyle(theme.accent)
            Text("FSB 工作台")
                .font(.system(size: theme.textSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { showCreateDialog = true }) {
                Image(systemName: "plus")
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
            .help("新建工作台")
            Button(action: { isGridView.toggle() }) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(isGridView ? "列表视图" : "网格视图")
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
    }

    private var searchBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.textTertiary)
            TextField("搜索工作台...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(theme.surfaceElevated)
        )
        .padding(.horizontal, theme.spacingM)
        .padding(.bottom, theme.spacingS)
    }

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: theme.spacingS),
                GridItem(.flexible(), spacing: theme.spacingS)
            ], spacing: theme.spacingS) {
                ForEach(filteredWorkspaces.indices, id: \.self) { idx in
                    let ws = filteredWorkspaces[idx]
                    workspaceGridCard(ws: ws)
                }
            }
            .padding(theme.spacingM)
        }
    }

    private var listView: some View {
        List {
            ForEach(filteredWorkspaces.indices, id: \.self) { idx in
                let ws = filteredWorkspaces[idx]
                workspaceListRow(ws: ws)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func workspaceGridCard(ws: [String: Any]) -> some View {
        let wsId = ws["wsId"] as? String ?? ws["id"] as? String ?? ""
        let title = ws["title"] as? String ?? ws["name"] as? String ?? "未命名"
        let desc = ws["description"] as? String ?? ""
        let connectorCount = (ws["connectorIds"] as? [String])?.count ?? 0
        let skillCount = (ws["skillIds"] as? [String])?.count ?? 0
        let wfCount = (ws["workflowIds"] as? [String])?.count ?? 0

        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "storefront")
                    .foregroundStyle(theme.accent)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                wsContextMenu(wsId: wsId, ws: ws)
            }
            if !desc.isEmpty {
                Text(desc)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }
            HStack(spacing: theme.spacingM) {
                Label("\(connectorCount)", systemImage: "plug")
                Label("\(skillCount)", systemImage: "star")
                Label("\(wfCount)", systemImage: "flowchart")
            }
            .font(.system(size: theme.captionSize))
            .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(selectedWsId == wsId ? theme.accentSoft : theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(selectedWsId == wsId ? theme.accent : Color.clear, lineWidth: 1.5)
        )
        .onTapGesture { selectedWsId = wsId }
    }

    @ViewBuilder
    private func workspaceListRow(ws: [String: Any]) -> some View {
        let wsId = ws["wsId"] as? String ?? ws["id"] as? String ?? ""
        let title = ws["title"] as? String ?? ws["name"] as? String ?? "未命名"
        let desc = ws["description"] as? String ?? ""
        let connectorCount = (ws["connectorIds"] as? [String])?.count ?? 0
        let wfCount = (ws["workflowIds"] as? [String])?.count ?? 0

        HStack(spacing: theme.spacingS) {
            Image(systemName: "storefront")
                .foregroundStyle(selectedWsId == wsId ? theme.accent : theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(selectedWsId == wsId ? theme.accent : theme.text)
                    .lineLimit(1)
                HStack(spacing: theme.spacingS) {
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                    Text("\(connectorCount)连·\(wfCount)流")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            wsContextMenu(wsId: wsId, ws: ws)
        }
        .padding(.vertical, theme.spacingXS)
        .contentShape(Rectangle())
        .onTapGesture { selectedWsId = wsId }
    }

    @ViewBuilder
    private func wsContextMenu(wsId: String, ws: [String: Any]) -> some View {
        Menu {
            Button(action: { selectedWsId = wsId }) {
                Label("打开", systemImage: "arrow.right.circle")
            }
            Button(action: {
                renameWsId = wsId
                renameWsName = ws["title"] as? String ?? ws["name"] as? String ?? ""
                showRenameDialog = true
            }) {
                Label("重命名", systemImage: "pencil")
            }
            Button(action: { duplicateWorkspace(wsId) }) {
                Label("复制", systemImage: "doc.on.doc")
            }
            Divider()
            Button(action: { exportWorkspace(wsId) }) {
                Label("导出", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button(role: .destructive, action: { deleteWorkspace(wsId) }) {
                Label("删除", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: 12))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 20, height: 20)
    }

    private var emptyStatePanel: some View {
        VStack(spacing: theme.spacingL) {
            Image(systemName: "storefront")
                .font(.system(size: 56))
                .foregroundStyle(theme.textTertiary)
            VStack(spacing: theme.spacingXS) {
                Text("Fusion Small Business")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("跨 SaaS 智能业务工作台")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
            }
            if !fsbAvailable {
                Label("FSB 服务未启动", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.system(size: theme.footnoteSize))
            }
            HStack(spacing: theme.spacingM) {
                Button(action: { showCreateDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("创建工作台")
                    }
                }
                .buttonStyle(.borderedProminent)
                Button(action: { showOnboarding = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book")
                        Text("使用指南")
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.contentBg)
    }

    private var filteredWorkspaces: [[String: Any]] {
        if searchText.isEmpty { return workspaces }
        return workspaces.filter { ws in
            let title = (ws["title"] as? String ?? ws["name"] as? String ?? "").lowercased()
            let desc = (ws["description"] as? String ?? "").lowercased()
            let q = searchText.lowercased()
            return title.contains(q) || desc.contains(q)
        }
    }

    private func checkFSBHealth() {
        Task {
            do {
                _ = try await ipc.fsbHealth()
                await MainActor.run { fsbAvailable = true }
                fsbLog.info("FSB service is available")
            } catch {
                await MainActor.run { fsbAvailable = false }
                fsbLog.warning("FSB service unavailable: \(error.localizedDescription)")
            }
        }
    }

    private func loadWorkspaces() {
        isLoading = true
        Task {
            do {
                let items = try await ipc.fsbListWorkspaces(search: searchText)
                await MainActor.run { workspaces = items }
            } catch {
                fsbLog.error("workspace list failed: \(error.localizedDescription)")
            }
            await MainActor.run { isLoading = false }
        }
    }

    private func createWorkspace(title: String, desc: String, projectId: String?) {
        Task {
            do {
                _ = try await ipc.fsbCreateWorkspace(
                    title: title,
                    description: desc,
                    projectId: projectId?.isEmpty == true ? nil : projectId
                )
                fsbLog.info("workspace created: \(title)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace create failed: \(error.localizedDescription)")
            }
        }
    }

    private func renameWorkspace() {
        guard !renameWsName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.fsbUpdateWorkspace(wsId: renameWsId, title: renameWsName)
                fsbLog.info("workspace renamed: \(renameWsId)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace rename failed: \(error.localizedDescription)")
            }
        }
    }

    private func duplicateWorkspace(_ wsId: String) {
        Task {
            do {
                _ = try await ipc.fsbDuplicateWorkspace(wsId: wsId)
                fsbLog.info("workspace duplicated: \(wsId)")
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace duplicate failed: \(error.localizedDescription)")
            }
        }
    }

    private func exportWorkspace(_ wsId: String) {
        Task {
            do {
                let result = try await ipc.fsbExportWorkspace(wsId: wsId)
                let jsonData = try JSONSerialization.data(
                    withJSONObject: result,
                    options: [.prettyPrinted, .sortedKeys]
                )
                let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
                await MainActor.run {
                    exportData = jsonString
                    showExportSheet = true
                }
            } catch {
                fsbLog.error("workspace export failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteWorkspace(_ wsId: String) {
        Task {
            do {
                _ = try await ipc.fsbDeleteWorkspace(wsId: wsId)
                fsbLog.info("workspace deleted: \(wsId)")
                if selectedWsId == wsId { selectedWsId = nil }
                loadWorkspaces()
            } catch {
                fsbLog.error("workspace delete failed: \(error.localizedDescription)")
            }
        }
    }
}

struct FSBCreateWorkspaceDialog: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let ipc: IPCClient
    let onCreate: (String, String, String?) -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var projectId = ""
    @State private var bindAgentId = ""
    @State private var showTemplateImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("新建工作台")
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("名称")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("例如：客户管理系统", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("描述（可选）")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("工作台用途说明", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("绑定项目（可选）")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("项目 ID", text: $projectId)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: theme.spacingS) {
                Text("绑定 Agent（可选）")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("Agent ID", text: $bindAgentId)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button(action: { showTemplateImport = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                        Text("从模板导入")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
                Button("取消") { dismiss() }
                    .controlSize(.small)
                Button("创建") {
                    onCreate(title, description, projectId.isEmpty ? nil : projectId)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(title.isEmpty)
            }

            if showTemplateImport {
                Divider()
                Text("内置模板")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                FSBTemplateGallery { templateName in
                    title = templateName
                    showTemplateImport = false
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 420)
    }
}

struct FSBTemplateGallery: View {
    @Environment(\.studioTheme) private var theme

    let onSelect: (String) -> Void

    private let templates = [
        ("客户关系管理", "CRM", "管理客户信息、跟进记录、销售漏斗", "person.2"),
        ("库存管理", "库存", "商品库存跟踪、补货提醒、出入库记录", "archivebox"),
        ("财务记账", "财务", "收支记录、发票管理、财务报表生成", "chart.bar"),
        ("邮件营销", "营销", "邮件模板、受众分组、发送排期、效果分析", "envelope"),
        ("社交媒体管理", "社媒", "多平台发布、排期、互动监控、数据分析", "shareplay"),
        ("工单系统", "工单", "客户工单、分配、SLA 跟踪、满意度调查", "ticket"),
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: theme.spacingS) {
            ForEach(templates, id: \.0) { tpl in
                Button(action: { onSelect(tpl.0) }) {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        HStack {
                            Image(systemName: tpl.3)
                                .foregroundStyle(theme.accent)
                            Text(tpl.1)
                                .font(.system(size: theme.captionSize, weight: .semibold))
                                .foregroundStyle(theme.text)
                        }
                        Text(tpl.2)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(theme.spacingS)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(theme.surfaceElevated)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct FSBOnboardingDialog: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0

    private let steps = [
        ("欢迎使用 FSB", "Fusion Small Business 是一个跨 SaaS 的智能业务自动化工作台。\n无需编程，通过可视化工作流连接你的业务工具。", "storefront"),
        ("连接器", "连接你已有的 SaaS 工具：\nGoogle Workspace、Shopify、QuickBooks、Stripe 等。\n读操作自动执行，写操作需审批。", "plug"),
        ("技能", "内置 15+ 智能技能：\n邮件摘要、数据提取、报表生成、翻译等。\n可自定义 Prompt 技能和 API 调用技能。", "star"),
        ("工作流", "可视化编排工作流：\n拖拽节点构建 DAG，条件分支，审批关卡。\n支持定时触发、事件触发、外部 API 触发。", "flowchart"),
        ("开始使用", "创建一个工作台，选择模板或从零开始。\n所有数据本地运行，隐私安全。", "rocket"),
    ]

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Spacer()
            Image(systemName: steps[step].2)
                .font(.system(size: 48))
                .foregroundStyle(theme.accent)
            Text(steps[step].0)
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Text(steps[step].1)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Spacer()
            HStack {
                if step > 0 {
                    Button("上一步") { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == step ? theme.accent : theme.separator)
                            .frame(width: 8, height: 8)
                    }
                }
                Spacer()
                if step < steps.count - 1 {
                    Button("下一步") { step += 1 }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("开始使用") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 500, height: 420)
    }
}
