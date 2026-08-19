import SwiftUI
import os.log

private let listLog = Logger(subsystem: "com.fusion.studio", category: "AIAgent.List")

enum AgentFilterScope: String, CaseIterable {
    case all = "all"
    case draft = "draft"
    case published = "published"

    var predicate: (AgentModel) -> Bool {
        switch self {
        case .all: return { _ in true }
        case .draft: return { ($0.status ?? "draft") == "draft" }
        case .published: return { $0.status == "published" }
        }
    }

    var localLabel: String {
        switch self {
        case .all: return I18nManager.shared.t(.ai_list_scopeAll)
        case .draft: return I18nManager.shared.t(.ai_list_scopeDraft)
        case .published: return I18nManager.shared.t(.ai_list_scopePublished)
        }
    }
}

enum AgentSortField: String, CaseIterable {
    case updatedAt = "updatedAt"
    case createdAt = "createdAt"
    case name = "name"

    var localLabel: String {
        switch self {
        case .updatedAt: return I18nManager.shared.t(.ai_list_sortUpdated)
        case .createdAt: return I18nManager.shared.t(.ai_list_sortCreated)
        case .name: return I18nManager.shared.t(.ai_list_sortName)
        }
    }
}

struct AIAgentListView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var searchText = ""
    @State private var filterScope: AgentFilterScope = .all
    @State private var sortField: AgentSortField = .updatedAt
    @State private var selectedAgentId: String?
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm = false
    @State private var agentToDelete: AgentModel?
    @State private var debugAgent: AgentModel?
    @State private var editAgent: AgentModel?

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
        .sheet(item: $debugAgent) { agent in
            AIAgentDebugView(agentId: agent.id)
        }
        .sheet(item: $editAgent) { agent in
            AIAgentConfigView(mode: .edit(agent))
        }
        .alert(i18n.t(.ai_list_delTitle), isPresented: $showDeleteConfirm) {
            Button(i18n.t(.cancel), role: .cancel) {}
            Button(i18n.t(.delete), role: .destructive) {
                if let agent = agentToDelete { deleteAgent(agent) }
            }
        } message: {
            Text(String(format: i18n.t(.ai_list_delMsgFmt), agentToDelete?.name ?? ""))
        }
    }

    private var toolbarBar: some View {
        HStack(spacing: theme.spacingM) {
            Button(action: { showCreateSheet = true }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "plus.circle.fill")
                    Text(i18n.t(.ai_list_create))
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
                TextField(i18n.t(.ai_list_searchPh), text: $searchText)
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
                        Text(scope.localLabel)
                        if filterScope == scope { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Text(String(format: i18n.t(.ai_list_filterFmt), filterScope.localLabel))
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
                        Text(field.localLabel)
                        if sortField == field { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: theme.iconS))
                Text(sortField.localLabel)
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
            headerCell(i18n.t(.ai_list_hName), width: 200)
            headerCell(i18n.t(.ai_list_hStatus), width: 80)
            headerCell(i18n.t(.ai_list_hModel), width: 160)
            headerCell(i18n.t(.ai_list_hKb), width: 150)
            headerCell(i18n.t(.ai_list_hUpdated), width: 120)
            headerCell(i18n.t(.ai_list_hAction), width: 200)
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
                actionButton(i18n.t(.ai_list_actDebug), icon: "ladybug") { debugAgent = agent }
                actionButton(i18n.t(.ai_list_actEdit), icon: "pencil") { editAgent = agent }
                actionButton(i18n.t(.ai_list_actClone), icon: "doc.on.doc") { cloneAgent(agent) }
                actionButton(i18n.t(.ai_list_actArchive), icon: "archivebox") { archiveAgent(agent) }
                actionButton(i18n.t(.ai_list_actDelete), icon: "trash", color: theme.accentDestructive) {
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
            Text(i18n.t(.ai_list_empty))
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.ai_list_emptyHint))
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

    private func archiveAgent(_ agent: AgentModel) {
        Task {
            do {
                let _ = try await ipc.agentArchive(agentId: agent.id)
                listLog.info("Agent archived: \(agent.id)")
                try await bridge.fetchAgents()
            } catch {
                listLog.error("Archive agent failed: \(error.localizedDescription)")
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
