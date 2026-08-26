import SwiftUI
import os.log

private let agentDDLog = Logger(subsystem: "com.fusion.studio", category: "Agent.Dropdown")

struct AgentDropdown: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @Binding var selectedAgentId: String?
    @State private var agents: [[String: Any]] = []
    @State private var isExpanded = false
    @State private var isLoading = false
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            triggerButton
            if isExpanded {
                dropdownList
            }
        }
        .onAppear { loadAgents() }
    }

    private var triggerButton: some View {
        Button(action: { isExpanded.toggle() }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.accent)
                if let sid = selectedAgentId,
                   let agent = agents.first(where: { ($0["agent_id"] as? String ?? $0["id"] as? String) == sid }) {
                    Text(agent["name"] as? String ?? "Unknown")
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                } else {
                    Text("选择 Agent")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var dropdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("搜索 Agent…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: theme.footnoteSize))
                .padding(theme.spacingS)

            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                ProgressView().padding()
            } else {
                let filtered = agents.filter { a in
                    if searchText.isEmpty { return true }
                    let name = (a["name"] as? String ?? "").lowercased()
                    return name.contains(searchText.lowercased())
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered.indices, id: \.self) { idx in
                            agentRow(filtered[idx])
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceElevated))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.separator, lineWidth: 1))
    }

    private func agentRow(_ a: [String: Any]) -> some View {
        let aid = a["agent_id"] as? String ?? a["id"] as? String ?? ""
        let name = a["name"] as? String ?? "?"
        let role = a["role"] as? String ?? ""
        let isSelected = selectedAgentId == aid

        return HStack(spacing: theme.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: theme.iconM))
                .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accent : theme.text)
                if !role.isEmpty {
                    Text(role)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedAgentId = aid
            isExpanded = false
        }
    }

    private func loadAgents() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.call(method: RPCMethod.agentList, params: [:])
                let items = r["agents"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                await MainActor.run { agents = items; isLoading = false }
            } catch {
                agentDDLog.error("agent.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct AgentPreviewCard: View {
    @Environment(\.studioTheme) private var theme

    let agent: [String: Any]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent["name"] as? String ?? "Unknown")
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(agent["role"] as? String ?? "")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
            }

            if let desc = agent["description"] as? String, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(3)
            }

            if let tools = agent["tools"] as? [String], !tools.isEmpty {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("工具")
                        .font(.system(size: theme.captionSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    FlowLayout(spacing: theme.spacingXS) {
                        ForEach(tools, id: \.self) { tool in
                            Text(tool)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 4).fill(theme.accent.opacity(0.1)))
                        }
                    }
                }
            }
        }
        .padding(theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surfaceSecondary))
        .overlay(RoundedRectangle(cornerRadius: theme.cornerRadius).stroke(theme.separator, lineWidth: 1))
    }
}
