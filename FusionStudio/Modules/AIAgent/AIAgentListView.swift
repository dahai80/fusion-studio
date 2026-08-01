import SwiftUI
import os.log

private let listLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.List")

enum AgentFilterScope: String, CaseIterable {
    case all = "全部"
    case draft = "草稿"
    case published = "已发布"

    var predicate: (AgentModel) -> Bool {
        switch self {
        case .all: return { _ in true }
        case .draft: return { ($0.status ?? "draft") == "draft" }
        case .published: return { $0.status == "published" }
        }
    }
}

enum AgentSortField: String, CaseIterable {
    case updatedAt = "最近更新"
    case createdAt = "创建时间"
    case name = "名称"
}

struct AIAgentListView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme

    @State private var searchText = ""
    @State private var filterScope: AgentFilterScope = .all
    @State private var sortField: AgentSortField = .updatedAt
    @State private var selectedAgentId: String?
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var agentToDelete: AgentModel?

    var body: some View {
        VStack(spacing: 0) {
            toolbarBar
            Rectangle().fill(theme.separator).frame(height: 1)
            agentTable
        }
        .background(theme.contentBg)
        .onAppear { loadAgents() }
        .sheet(isPresented: $showCreateSheet) {
            AIAgentConfigView(mode: .create)
        }
        .alert("确认删除", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let agent = agentToDelete { deleteAgent(agent) }
            }
        } message: {
            Text("确定要删除 Agent「\(agentToDelete?.name ?? "")」吗？此操作不可撤销。")
        }
    }

    private var toolbarBar: some View {
        HStack(spacing: theme.spacingM) {
            Button(action: { showCreateSheet = true }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus.circle.fill")
                    Text("创建 Agent")
                }
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentText)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .fill(theme.accent)
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: theme.spacingXS) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
                TextField("搜索 Agent 名称...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(theme.surfaceElevated)
            )
            .frame(width: 220)

            Spacer()

            filterPicker
            sortPicker
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var filterPicker: some View {
        Menu {
            ForEach(AgentFilterScope.allCases, id: \.self) { scope in
                Button(action: { filterScope = scope }) {
                    HStack {
                        Text(scope.rawValue)
                        if filterScope == scope { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Text("筛选: \(filterScope.rawValue)")
                    .font(.system(size: theme.captionSize))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundStyle(theme.textSecondary)
        }
    }

    private var sortPicker: some View {
        Menu {
            ForEach(AgentSortField.allCases, id: \.self) { field in
                Button(action: { sortField = field }) {
                    HStack {
                        Text(field.rawValue)
                        if sortField == field { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: theme.iconS))
                Text(sortField.rawValue)
                    .font(.system(size: theme.captionSize))
            }
            .foregroundStyle(theme.textSecondary)
        }
    }

    private var agentTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                tableHeader
                Rectangle().fill(theme.separator).frame(height: 1)

                if filteredAgents.isEmpty {
                    emptyState
                } else {
                    ForEach(filteredAgents, id: \.id) { agent in
                        agentRow(agent)
                        Rectangle().fill(theme.separator.opacity(0.5)).frame(height: 0.5)
                    }
                }
            }
            .padding(.horizontal, theme.spacingL)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            headerCell("Agent 名称", width: 200)
            headerCell("状态", width: 80)
            headerCell("模型", width: 160)
            headerCell("关联知识库", width: 150)
            headerCell("最后更新", width: 120)
            headerCell("操作", width: 200)
        }
        .padding(.vertical, theme.spacingS)
    }

    private func headerCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: theme.captionSize, weight: .semibold))
            .foregroundStyle(theme.textTertiary)
            .frame(width: width, alignment: .leading)
    }

    private func agentRow(_ agent: AgentModel) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Circle()
                    .fill(statusColor(agent))
                    .frame(width: 8, height: 8)
                Text(agent.name)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
            }
            .frame(width: 200, alignment: .leading)

            Text(agent.statusLabel)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(statusColor(agent))
                .frame(width: 80, alignment: .leading)

            Text(agent.model)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)

            Text(agent.knowledge_base_ids?.joined(separator: ", ") ?? "-")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 150, alignment: .leading)
                .lineLimit(1)

            Text(formatDate(agent.created_at))
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 120, alignment: .leading)

            HStack(spacing: theme.spacingS) {
                actionButton("调试", icon: "ladybug") { selectedAgentId = agent.id }
                actionButton("编辑", icon: "pencil") { selectedAgentId = agent.id }
                actionButton("复制", icon: "doc.on.doc") { cloneAgent(agent) }
                actionButton("删除", icon: "trash", color: theme.accentDestructive) {
                    agentToDelete = agent
                    showDeleteConfirm = true
                }
            }
            .frame(width: 200, alignment: .leading)
        }
        .padding(.vertical, theme.spacingS)
        .contentShape(Rectangle())
        .onTapGesture { selectedAgentId = agent.id }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("暂无 Agent")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text("点击「创建 Agent」开始构建智能体")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing2XL)
    }

    private func actionButton(_ label: String, icon: String, color: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: theme.captionSize))
            }
            .foregroundStyle(color ?? theme.accent)
        }
        .buttonStyle(.plain)
    }

    private var filteredAgents: [AgentModel] {
        var result = bridge.agents
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        result = result.filter(filterScope.predicate)
        switch sortField {
        case .updatedAt: result.sort { $0.created_at > $1.created_at }
        case .createdAt: result.sort { $0.created_at > $1.created_at }
        case .name: result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return result
    }

    private func statusColor(_ agent: AgentModel) -> Color {
        switch agent.status ?? "draft" {
        case "published", "active": return theme.accent
        case "draft", "idle": return theme.textTertiary
        case "archived": return theme.textQuaternary
        default: return theme.auxiliary
        }
    }

    private func formatDate(_ iso: String) -> String {
        if iso.count >= 10 { return String(iso.prefix(10)) }
        return iso
    }

    private func loadAgents() {
        Task {
            do {
                try await bridge.fetchAgents()
                listLog.info("Agents loaded: \(bridge.agents.count)")
            } catch {
                listLog.error("Load agents failed: \(error.localizedDescription)")
            }
        }
    }

    private func cloneAgent(_ agent: AgentModel) {
        Task {
            do {
                let _ = try await ipc.agentClone(agentId: agent.id)
                listLog.info("Agent cloned: \(agent.id)")
                try await bridge.fetchAgents()
            } catch {
                listLog.error("Clone agent failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteAgent(_ agent: AgentModel) {
        Task {
            do {
                let _ = try await ipc.agentDelete(agentId: agent.id)
                listLog.info("Agent deleted: \(agent.id)")
                try await bridge.fetchAgents()
            } catch {
                listLog.error("Delete agent failed: \(error.localizedDescription)")
            }
        }
    }
}
