import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 3: 协作空间主界面 (3-column layout)

struct SpaceMainView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var space: CoworkSpace?
    @State private var isLoading = false
    @State private var activeSidebarSection: SpaceSidebarSection = .members
    @State private var selectedArtifact: SpaceArtifact?
    @State private var showNotifications = false
    private let spaceManager = CoworkSpaceManager.shared

    private enum SpaceSidebarSection: String, CaseIterable {
        case members
        case files
        case knowledge
        case agents = "Agent"
        case artifacts
        case workflows
        case snapshots
        case desktop
        case settings

        var localLabel: String {
            switch self {
            case .members: return I18nManager.shared.t(.cw_side_members)
            case .files: return I18nManager.shared.t(.cw_side_files)
            case .knowledge: return I18nManager.shared.t(.cw_side_knowledge)
            case .agents: return I18nManager.shared.t(.cw_side_agents)
            case .artifacts: return I18nManager.shared.t(.cw_side_artifacts)
            case .workflows: return I18nManager.shared.t(.cw_side_workflows)
            case .snapshots: return I18nManager.shared.t(.cw_side_snapshots)
            case .desktop: return I18nManager.shared.t(.cw_side_desktop)
            case .settings: return I18nManager.shared.t(.cw_side_settings)
            }
        }

        var icon: String {
            switch self {
            case .members: return "person.2"
            case .files: return "folder"
            case .knowledge: return "books.vertical"
            case .agents: return "brain.head.profile"
            case .artifacts: return "shippingbox"
            case .workflows: return "arrow.triangle.branch"
            case .snapshots: return "camera.on.rectangle"
            case .desktop: return "desktopcomputer"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let s = space {
                spaceHeader(s)
                if s.isArchived {
                    archivedBanner
                }
                HStack(spacing: 0) {
                    leftSidebar
                    Rectangle().fill(theme.separator).frame(width: 1)
                    SpaceSharedChat(spaceId: spaceId, space: s)
                    if let art = selectedArtifact {
                        Rectangle().fill(theme.separator).frame(width: 1)
                        ArtifactPreviewView(artifact: art, onClose: { selectedArtifact = nil })
                    }
                }
            } else {
                Text(i18n.t(.cw_main_loading))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSpace() }
    }

    private func spaceHeader(_ s: CoworkSpace) -> some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: collabModeIcon(s.collabMode))
                .font(.system(size: theme.iconL))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name)
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                HStack(spacing: theme.spacingS) {
                    Text(s.description)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    if s.config.enableDeepResearch {
                        Label(i18n.t(.cw_main_deepResearch), systemImage: "telescope")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                    }
                    if s.config.enableComputerUse {
                        Label(i18n.t(.cw_main_computerUse), systemImage: "desktopcomputer")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            Spacer()
            Button(action: { showNotifications.toggle() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                    let unread = spaceManager.unreadNotificationCount()
                    if unread > 0 {
                        Text("\(min(unread, 99))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 6, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNotifications) {
                SpaceNotificationPopover()
            }
            Menu {
                Button(i18n.t(.cw_main_createSnap)) { createSnapshot() }
                if s.isOwner || s.ownerId == "local_user" {
                    Divider()
                    Button(i18n.t(.cw_main_archive), role: .destructive) { archiveSpace() }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private var archivedBanner: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "lock.fill")
                .foregroundStyle(theme.accentDestructive)
            Text(i18n.t(.cw_main_archivedBanner))
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.accentDestructive)
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS)
        .background(theme.accentDestructive.opacity(0.08))
    }

    private var leftSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(SpaceSidebarSection.allCases, id: \.self) { section in
                Button(action: { activeSidebarSection = section }) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: section.icon)
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(activeSidebarSection == section ? theme.accent : theme.textTertiary)
                            .frame(width: 20)
                        Text(section.localLabel)
                            .font(.system(size: theme.footnoteSize, weight: activeSidebarSection == section ? .semibold : .regular))
                            .foregroundStyle(activeSidebarSection == section ? theme.accent : theme.textSecondary)
                        Spacer()
                        sectionBadge(section)
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, theme.spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                            .fill(activeSidebarSection == section ? theme.accent.opacity(0.1) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Divider().padding(.vertical, theme.spacingXS)

            switch activeSidebarSection {
            case .members:
                SpaceMemberPanel(spaceId: spaceId)
            case .files:
                SpaceFilesPanel(spaceId: spaceId)
            case .knowledge:
                SpaceKnowledgePanel(spaceId: spaceId)
            case .agents:
                SpaceAgentPanel(spaceId: spaceId)
            case .artifacts:
                SpaceArtifactPanel(spaceId: spaceId, selectedArtifact: $selectedArtifact)
            case .workflows:
                SpaceWorkflowPanel(spaceId: spaceId)
            case .snapshots:
                SpaceSnapshotPanel(spaceId: spaceId)
            case .desktop:
                SpaceDesktopPanel(spaceId: spaceId)
            case .settings:
                SpaceSettingsPanel(spaceId: spaceId, space: space)
            }
        }
        .frame(minWidth: 200, maxWidth: 260)
    }

    @ViewBuilder
    private func sectionBadge(_ section: SpaceSidebarSection) -> some View {
        switch section {
        case .members:
            if let s = space, s.memberCount > 0 {
                Text("\(s.memberCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        case .agents:
            if let s = space, s.agentCount > 0 {
                Text("\(s.agentCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        case .artifacts:
            if let s = space, s.artifactCount > 0 {
                Text("\(s.artifactCount)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        case .knowledge:
            if let kb = spaceManager.activeKnowledge, kb.isBound {
                Circle().fill(Color.green).frame(width: 6, height: 6)
            }
        case .snapshots:
            if let s = space, s.messageCount > 0 {
                Text("\(spaceManager.activeSnapshots.count)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
        default:
            EmptyView()
        }
    }

    private func collabModeIcon(_ mode: CollabMode) -> String {
        switch mode {
        case .local: return "person.2.square.stack"
        case .p2p: return "antenna.radiowaves.left.and.right"
        case .gateway: return "globe"
        }
    }

    private func createSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceSnapshotCreate(spaceId: spaceId, name: "Auto Snapshot")
                spaceLog.info("Snapshot created for \(spaceId)")
            } catch {
                spaceLog.error("snapshot.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func archiveSpace() {
        Task {
            do {
                _ = try await ipc.spaceArchive(spaceId: spaceId)
                spaceLog.info("Space archived: \(spaceId)")
                loadSpace()
            } catch {
                spaceLog.error("archive failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSpace() {
        isLoading = true
        spaceManager.setIPCClient(ipc)
        Task {
            do {
                let result = try await ipc.spaceGet(spaceId: spaceId)
                let s = CoworkSpace.fromDict(result)
                await MainActor.run { space = s; isLoading = false }
                await spaceManager.loadKnowledgeStatus(spaceId: spaceId)
                await spaceManager.loadNotifications()
            } catch {
                spaceLog.error("space.get failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 3 Center: 共享对话
