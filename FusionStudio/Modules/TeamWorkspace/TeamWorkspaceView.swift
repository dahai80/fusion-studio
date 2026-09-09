import SwiftUI
import os.log

private let teamWorkspaceLog = Logger(subsystem: "com.fusion.studio", category: "TeamWorkspaceView")

// M2-1: TeamWorkspace shell. Replaces mock TeamCollabView. Read-only Kanban/Members (M2-2 fills panels).
// Backed by TeamBridge (daemon RPC snapshot + team.events WS stream). GUI 不做本地状态 — daemon SSOT.
struct TeamWorkspaceView: View {
    @EnvironmentObject var teamBridge: TeamBridge
    @State private var selectedTab: TeamWorkspaceTab = .kanban
    @State private var teamInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            TeamWorkspaceHeader(
                teamBridge: teamBridge,
                teamInput: $teamInput,
                onSubmitTeam: { teamBridge.selectTeam(teamInput) }
            )
            Divider()
            HStack(spacing: 0) {
                ForEach(TeamWorkspaceTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                            Text(tab.displayName)
                        }
                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            Divider()
            Group {
                switch selectedTab {
                case .kanban:
                    KanbanPlaceholderView(teamBridge: teamBridge)
                case .members:
                    MembersPlaceholderView(teamBridge: teamBridge)
                case .messages:
                    MessageStreamView()
                case .evidence:
                    EvidenceDiagnosticsView()
                case .budget:
                    BudgetView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            teamInput = teamBridge.selectedTeam
            Task { await teamBridge.refreshAll() }
            teamWorkspaceLog.info("TeamWorkspaceView appeared team=\(teamBridge.selectedTeam, privacy: .public)")
        }
    }
}

// MARK: - Header

private struct TeamWorkspaceHeader: View {
    @ObservedObject var teamBridge: TeamBridge
    @Binding var teamInput: String
    let onSubmitTeam: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.secondary)
                Text("Team Workspace")
                    .font(.system(size: 15, weight: .semibold))
            }
            Divider()
                .frame(height: 16)
            HStack(spacing: 4) {
                Image(systemName: "rectangle.stack")
                    .foregroundColor(.secondary)
                TextField("team name", text: $teamInput, onCommit: onSubmitTeam)
                    .font(.system(size: 13))
                    .frame(width: 120)
            }
            // WS connection indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(teamBridge.eventStream.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(teamBridge.eventStream.isConnected ? "WS" : "poll")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            if teamBridge.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Placeholders (M2-2 replaces with full KanbanBoardView + MembersView)

private struct KanbanPlaceholderView: View {
    @ObservedObject var teamBridge: TeamBridge

    var body: some View {
        HStack(spacing: 8) {
            ForEach(KanbanColumn.allCases, id: \.self) { col in
                let colTasks = teamBridge.tasks.filter { $0.deriveColumn() == col }
                KanbanColumnPlaceholder(column: col, count: colTasks.count, tasks: colTasks)
            }
        }
        .padding(8)
    }
}

private struct KanbanColumnPlaceholder: View {
    let column: KanbanColumn
    let count: Int
    let tasks: [TeamTask]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(column.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(tasks) { task in
                        TaskCardView(task: task)
                    }
                }
                .padding(6)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        .cornerRadius(8)
    }
}

private struct TaskCardView: View {
    let task: TeamTask

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title.isEmpty ? task.id : task.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
            HStack(spacing: 4) {
                if task.priority > 5 {
                    Text("P\(task.priority)")
                        .font(.system(size: 10))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(3)
                }
                if !task.ownerAgent.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text(task.ownerAgent)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if task.hasEvidence {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 9))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

private struct MembersPlaceholderView: View {
    @ObservedObject var teamBridge: TeamBridge

    var body: some View {
        List {
            ForEach(teamBridge.members) { member in
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name)
                            .font(.system(size: 13, weight: .medium))
                        if !member.capabilities.isEmpty {
                            Text(member.capabilities.joined(separator: ", "))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if let task = member.currentTask, !task.isEmpty {
                        Text(task)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.sidebar)
    }
}
