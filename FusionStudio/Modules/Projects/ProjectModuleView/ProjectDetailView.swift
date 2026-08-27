import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct ProjectDetailView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let project: FusionProject
    @State private var activeTab: ProjectDetailTab = .instructions
    @State private var showSettings = false
    @State private var showCoWorkDialog = false
    @State private var showAgentPreview = false

    private enum ProjectDetailTab: Int, CaseIterable {
        case instructions = 0
        case knowledge = 1
        case chats = 2

        var item: FusionTabItem {
            switch self {
            case .instructions: return FusionTabItem(title: I18nManager.shared.t(.proj_tabInstructions), icon: "text.alignleft")
            case .knowledge:    return FusionTabItem(title: I18nManager.shared.t(.proj_tabKnowledge), icon: "folder.badge.gearshape")
            case .chats:        return FusionTabItem(title: I18nManager.shared.t(.proj_tabChats), icon: "bubble.left.and.bubble.right")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // GUI-4 Header bar
            projectHeaderBar

            // Tab bar
            FusionTabBar(
                selected: Binding(
                    get: { activeTab.rawValue },
                    set: { if let t = ProjectDetailTab(rawValue: $0) { activeTab = t } }
                ),
                tabs: ProjectDetailTab.allCases.map { $0.item }
            )
            .padding(.horizontal, theme.spacingM)

            // Tab content
            Group {
                switch activeTab {
                case .instructions:
                    ProjectInstructionsPanel(projectId: project.id)
                case .knowledge:
                    KnowledgeBaseTreeView(projectId: project.id)
                case .chats:
                    ProjectChatsPanel(projectId: project.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showSettings) {
            ProjectSettingsPanel(project: project)
        }
        .sheet(isPresented: $showCoWorkDialog) {
            CoWorkImportDialog(project: project)
        }
        .sheet(isPresented: $showAgentPreview) {
            ProjectAgentPreview(project: project)
        }
    }

    // GUI-4: Header — back / name / star / menu / agent / CoWork

    private var projectHeaderBar: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: project.isStarred ? "star.fill" : "folder.fill")
                .font(.system(size: theme.iconM))
                .foregroundStyle(project.isStarred ? .yellow : theme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                if project.isArchived {
                    Text(i18n.t(.proj_detailArchived))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.orange)
                }
            }

            // Star toggle
            Button(action: { toggleStar() }) {
                Image(systemName: project.isStarred ? "star.fill" : "star")
                    .foregroundStyle(project.isStarred ? .yellow : theme.textTertiary)
            }
            .buttonStyle(.plain)

            // GUI-5: Global 3-dot menu
            ProjectGlobalMenu(project: project)

            Spacer()

            // Agent selector
            if let agentName = project.agentName {
                Button(action: { showAgentPreview = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "robot")
                            .font(.system(size: theme.iconXS))
                        Text(agentName)
                            .font(.system(size: theme.footnoteSize))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.accent.opacity(0.3)))
                }
                .buttonStyle(.plain)
            }

            // CoWork import
            Button(action: { showCoWorkDialog = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: theme.iconXS))
                    Text(i18n.t(.proj_detailImportCowork))
                        .font(.system(size: theme.footnoteSize))
                }
                .foregroundStyle(theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(project.isArchived)

            // Settings
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape")
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
    }

    private func toggleStar() {
        Task {
            do {
                _ = try await ipc.projectStar(projectId: project.id, starred: !project.isStarred)
            } catch {
                projLog.error("toggleStar failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - GUI-5: Global Three-dot Menu (in detail header)

