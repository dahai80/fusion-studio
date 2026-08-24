import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 1: CoWork首页

struct SpaceListView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var spaces: [CoworkSpace] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateDialog = false
    @State private var selectedSpaceId: String?
    @State private var searchText = ""
    @State private var filterStatus: SpaceFilterStatus = .all
    @State private var showOnboarding = true
    @State private var showMarketplace = false

    private enum SpaceFilterStatus: String, CaseIterable {
        case all
        case created
        case joined
        case archived

        var localLabel: String {
            switch self {
            case .all: return I18nManager.shared.t(.cw_filter_all)
            case .created: return I18nManager.shared.t(.cw_filter_created)
            case .joined: return I18nManager.shared.t(.cw_filter_joined)
            case .archived: return I18nManager.shared.t(.cw_filter_archived)
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            spaceListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            if let sid = selectedSpaceId {
                SpaceMainView(spaceId: sid)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSpaces() }
    }

    private var spaceListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "CoWork", subtitle: i18n.t(.cw_list_subtitle))
                .padding(.bottom, theme.spacingS)

            HStack(spacing: theme.spacingS) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                    TextField(i18n.t(.cw_list_searchPh), text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.textSize))
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
                .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.inputBorder, lineWidth: 1))
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.cw_list_newHelp))
                Button(action: { showMarketplace = true }) {
                    Image(systemName: "bag")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(i18n.t(.cw_list_marketHelp))
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingS)

            HStack(spacing: 0) {
                ForEach(SpaceFilterStatus.allCases, id: \.self) { status in
                    Button(action: { filterStatus = status }) {
                        Text(status.localLabel)
                            .font(.system(size: theme.footnoteSize, weight: filterStatus == status ? .semibold : .regular))
                            .foregroundStyle(filterStatus == status ? theme.accent : theme.textSecondary)
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingXS)
                            .background(
                                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                    .fill(filterStatus == status ? theme.accent.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingM)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        if showOnboarding && spaces.isEmpty {
                            onboardingCard
                        }
                        ForEach(filteredSpaces) { space in
                            spaceCard(space)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .frame(minWidth: 300, maxWidth: 360)
        .sheet(isPresented: $showCreateDialog) {
            SpaceCreateDialog(onCreated: { _ in loadSpaces() })
        }
        .sheet(isPresented: $showMarketplace) {
            SpaceMarketplaceView()
        }
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "sparkles")
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.accent)
                Text(i18n.t(.cw_list_onboardingTitle))
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
            }
            Text(i18n.t(.cw_list_onboardingBody))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            Button(action: { showCreateDialog = true }) {
                Label(i18n.t(.cw_list_createLabel), systemImage: "plus.circle.fill")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accent)
        }
        .padding(theme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var filteredSpaces: [CoworkSpace] {
        var result = spaces
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        switch filterStatus {
        case .all: break
        case .created: result = result.filter { $0.isOwner }
        case .joined: result = result.filter { !$0.isOwner }
        case .archived: result = result.filter { $0.isArchived }
        }
        return result
    }

    private func spaceCard(_ space: CoworkSpace) -> some View {
        let isActive = selectedSpaceId == space.id
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: collabModeIcon(space.collabMode))
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: theme.spacingXS) {
                        Text(space.name)
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(isActive ? theme.accent : theme.text)
                            .lineLimit(1)
                        if space.isArchived {
                            Text(i18n.t(.cw_list_archivedTag))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.accentDestructive)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(theme.accentDestructive.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    if !space.description.isEmpty {
                        Text(space.description)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
            }
            HStack(spacing: theme.spacingM) {
                Label("\(space.memberCount)", systemImage: "person.2")
                Label("\(space.agentCount)", systemImage: "brain.head.profile")
                Label("\(space.artifactCount)", systemImage: "shippingbox")
                if space.config.enableDeepResearch {
                    Image(systemName: "telescope")
                }
                if space.config.enableComputerUse {
                    Image(systemName: "desktopcomputer")
                }
                Spacer()
                if let last = space.lastActivityAt {
                    Text(last, style: .relative)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(theme.textTertiary)
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(isActive ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(isActive ? theme.accent.opacity(0.3) : theme.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedSpaceId = space.id }
    }

    private func collabModeIcon(_ mode: CollabMode) -> String {
        switch mode {
        case .local: return "person.2.square.stack"
        case .p2p: return "antenna.radiowaves.left.and.right"
        case .gateway: return "globe"
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "person.2.square.stack")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.cw_list_emptyTitle))
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.cw_list_emptyHint))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSpaces() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipc.spaceList()
                if let items = result["items"] as? [[String: Any]] {
                    let loaded = items.map { CoworkSpace.fromDict($0) }
                    await MainActor.run { spaces = loaded; isLoading = false }
                } else if let single = result["spaces"] as? [[String: Any]] {
                    let loaded = single.map { CoworkSpace.fromDict($0) }
                    await MainActor.run { spaces = loaded; isLoading = false }
                } else {
                    await MainActor.run { spaces = []; isLoading = false }
                }
            } catch {
                spaceLog.error("space.list failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = String(format: i18n.t(.cw_list_loadFail), error.localizedDescription)
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Page 2: 新建协作空间

struct SpaceCreateDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var name = ""
    @State private var description = ""
    @State private var collabMode = CollabMode.local
    @State private var config = SpaceConfig()
    @State private var isCreating = false
    @State private var kbPath = ""
    @State private var preAddAgentSearch = ""

    let onCreated: ([String: Any]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.cw_create_title))
                    .font(.system(size: theme.headlineSize, weight: .bold))

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.cw_create_basic))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.cw_create_namePh), text: $name)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t(.cw_create_descPh), text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.cw_create_mode))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    HStack(spacing: theme.spacingM) {
                        ForEach(CollabMode.allCases, id: \.self) { mode in
                            Button(action: { collabMode = mode }) {
                                VStack(spacing: theme.spacingXS) {
                                    Image(systemName: collabModeIcon(mode))
                                        .font(.system(size: theme.iconL))
                                        .foregroundStyle(collabMode == mode ? theme.accent : theme.textTertiary)
                                    Text(collabModeLabel(mode))
                                        .font(.system(size: theme.captionSize, weight: collabMode == mode ? .semibold : .regular))
                                        .foregroundStyle(collabMode == mode ? theme.accent : theme.textSecondary)
                                    Text(collabModeDesc(mode))
                                        .font(.system(size: 9))
                                        .foregroundStyle(theme.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(theme.spacingM)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                        .fill(collabMode == mode ? theme.accent.opacity(0.1) : theme.surfaceSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                                        .stroke(collabMode == mode ? theme.accent.opacity(0.4) : theme.separator, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.cw_create_kb))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    TextField(i18n.t(.cw_create_kbPh), text: $kbPath)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.cw_create_ability))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)

                    VStack(spacing: theme.spacingXS) {
                        toolToggle(i18n.t(.cw_create_webSearch), icon: "globe", isOn: $config.enableWebSearch)
                        toolToggle(i18n.t(.cw_create_deepResearch), icon: "telescope", isOn: $config.enableDeepResearch)
                        toolToggle(i18n.t(.cw_create_computerUse), icon: "desktopcomputer", isOn: $config.enableComputerUse)
                        toolToggle(i18n.t(.cw_create_memberUpload), icon: "arrow.up.doc", isOn: $config.allowMemberUpload)
                        toolToggle(i18n.t(.cw_create_memberAgent), icon: "brain.head.profile", isOn: $config.allowMemberAgent)
                        toolToggle(i18n.t(.cw_create_memberWorkflow), icon: "arrow.triangle.branch", isOn: $config.allowMemberWorkflow)
                    }
                }

                VStack(alignment: .leading, spacing: theme.spacingS) {
                    Text(i18n.t(.cw_create_advanced))
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                    HStack {
                        Text(i18n.t(.cw_create_maxMembers))
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        Stepper(value: $config.maxMembers, in: 2...50) {
                            Text("\(config.maxMembers)")
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .frame(width: 30)
                        }
                    }
                }

                HStack {
                    Button(i18n.t(.cancel)) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(i18n.t(.cw_create_btn)) { createSpace() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(name.isEmpty || isCreating)
                }
            }
            .padding(theme.spacingL)
        }
        .frame(width: 520, height: 620)
    }

    private func toolToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: theme.iconS))
                .foregroundStyle(isOn.wrappedValue ? theme.accent : theme.textTertiary)
                .frame(width: 20)
            Text(label)
                .font(.system(size: theme.captionSize))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(isOn.wrappedValue ? theme.accent.opacity(0.06) : Color.clear)
        )
    }

    private func collabModeIcon(_ mode: CollabMode) -> String {
        switch mode {
        case .local: return "person.2.square.stack"
        case .p2p: return "antenna.radiowaves.left.and.right"
        case .gateway: return "globe"
        }
    }

    private func collabModeLabel(_ mode: CollabMode) -> String {
        switch mode {
        case .local: return i18n.t(.cw_create_modeLocal)
        case .p2p: return i18n.t(.cw_create_modeP2p)
        case .gateway: return i18n.t(.cw_create_modeGateway)
        }
    }

    private func collabModeDesc(_ mode: CollabMode) -> String {
        switch mode {
        case .local: return i18n.t(.cw_create_modeLocalDesc)
        case .p2p: return i18n.t(.cw_create_modeP2pDesc)
        case .gateway: return i18n.t(.cw_create_modeGatewayDesc)
        }
    }

    private func createSpace() {
        isCreating = true
        Task {
            do {
                var params: [String: Any] = [
                    "name": name,
                    "owner_id": "local_user",
                    "collab_mode": collabMode.rawValue,
                    "config": config.toDict(),
                ]
                if !description.isEmpty { params["description"] = description }
                if !kbPath.isEmpty { params["kb_path"] = kbPath }
                let result = try await ipc.spaceCall(method: "desk.space.create", params: params)
                spaceLog.info("space.created: \(name)")
                await MainActor.run { onCreated(result); dismiss() }
            } catch {
                spaceLog.error("space.create failed: \(error.localizedDescription)")
                await MainActor.run { isCreating = false }
            }
        }
    }
}

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

struct SpaceSharedChat: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    let space: CoworkSpace

    @State private var messages: [SpaceMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var selectedAgentId: String?
    @State private var availableAgents: [SpaceAgent] = []
    @State private var showCommentMessageId: String?
    @State private var showPlusMenu = false
    @State private var showDeepResearch = false
    @State private var researchQuery = ""
    @State private var streamingContent: String = ""
    @State private var isStreaming = false
    @State private var streamingAgentName: String = ""
    @State private var hoveredMsgId: String?
    @State private var showRelayPicker = false
    @State private var relayAgentIds: [String] = []
    @State private var isRelaying = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading && messages.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messages.isEmpty && !isStreaming {
                chatEmptyState
            } else {
                messageList
            }
            chatInputBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadMessages(); loadAgents() }
        .sheet(item: Binding(
            get: { showCommentMessageId.map { IdentifiableString(id: $0) } },
            set: { showCommentMessageId = $0?.id }
        )) { item in
            SpaceCommentThread(spaceId: spaceId, messageId: item.id)
        }
        .sheet(isPresented: $showDeepResearch) {
            SpaceDeepResearchView(spaceId: spaceId)
        }
    }

    private var chatEmptyState: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.cw_chat_emptyTitle))
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.cw_chat_emptyHint))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: theme.spacingS) {
                    ForEach(messages) { msg in
                        messageBubble(msg)
                            .id(msg.id)
                    }
                    if isStreaming {
                        streamingBubble
                            .id("streaming-bubble")
                    }
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingS)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: streamingContent) { _ in
                if isStreaming {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("streaming-bubble", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var streamingBubble: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(theme.accent)
                Text(streamingAgentName.isEmpty ? "Agent" : streamingAgentName)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(theme.accent)
                Text("Agent")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Spacer()
                if streamingContent.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.mini)
                        Text(i18n.t(.cw_chat_thinking))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            if !streamingContent.isEmpty {
                MarkdownContentView(content: streamingContent)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.accent.opacity(0.04))
        )
    }

    private func messageBubble(_ msg: SpaceMessage) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: msg.isFromAgent ? "brain.head.profile" : "person.circle")
                    .font(.system(size: theme.iconXS))
                    .foregroundStyle(msg.isFromAgent ? theme.accent : theme.textSecondary)
                Text(msg.senderName.isEmpty ? msg.senderId : msg.senderName)
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .foregroundStyle(msg.isFromAgent ? theme.accent : theme.text)
                if msg.isFromAgent {
                    Text("Agent")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(theme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Spacer()
                Text(msg.createdAt, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            MarkdownContentView(content: msg.content)

            if !msg.mentionedAgents.isEmpty {
                HStack(spacing: theme.spacingXS) {
                    ForEach(msg.mentionedAgents, id: \.self) { aid in
                        Text("@\(aid)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(theme.accent)
                    }
                }
            }

            if msg.hasAttachments {
                HStack(spacing: theme.spacingXS) {
                    ForEach(msg.attachments) { att in
                        HStack(spacing: 4) {
                            Image(systemName: attachmentIcon(att.fileType))
                                .font(.system(size: 9))
                            Text(att.fileName)
                                .font(.system(size: 9))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 3)
                        .background(theme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            }

            HStack(spacing: theme.spacingM) {
                Button(action: { copyMessageContent(msg) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text(i18n.t(.cw_chat_copy))
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                if msg.isFromAgent {
                    Button(action: { retryAgentMessage(msg) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                            Text(i18n.t(.cw_chat_retry))
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                Button(action: { showCommentMessageId = msg.id }) {
                    HStack(spacing: 3) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 9))
                        if msg.commentCount > 0 {
                            Text("\(msg.commentCount)")
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(msg.isFromAgent ? theme.accent.opacity(0.04) : theme.surfaceSecondary)
        )
        .onHover { hovering in
            hoveredMsgId = hovering ? msg.id : nil
        }
    }

    private func copyMessageContent(_ msg: SpaceMessage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(msg.content, forType: .string)
        spaceLog.info("Message content copied id=\(msg.id)")
    }

    private func retryAgentMessage(_ msg: SpaceMessage) {
        guard !isStreaming else { return }
        let prevUserMsg = messages.last(where: { !$0.isFromAgent && $0.createdAt < msg.createdAt })
        let retryContent = prevUserMsg?.content ?? msg.content
        startStreaming(content: retryContent)
    }

    private func attachmentIcon(_ type: String) -> String {
        switch type {
        case "image": return "photo"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "file": return "doc"
        default: return "paperclip"
        }
    }

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: theme.spacingS) {
                Menu {
                    Button(action: { }) {
                        Label(i18n.t(.cw_chat_attach), systemImage: "paperclip")
                    }
                    if space.config.enableDeepResearch {
                        Button(action: { showDeepResearch = true }) {
                            Label(i18n.t(.cw_create_deepResearch), systemImage: "telescope")
                        }
                    }
                    if space.config.enableWebSearch {
                        Button(action: { inputText += " /web " }) {
                            Label(i18n.t(.cw_create_webSearch), systemImage: "globe")
                        }
                    }
                    Button(action: { }) {
                        Label(i18n.t(.cw_chat_screenshot), systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: theme.iconM))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)

                if !availableAgents.isEmpty {
                    Menu {
                        Button(i18n.t(.cw_chat_noAgent)) { selectedAgentId = nil }
                        Divider()
                        ForEach(availableAgents) { agent in
                            Button(action: { selectedAgentId = agent.id }) {
                                HStack {
                                    Text(agent.name)
                                    if agent.id == selectedAgentId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: theme.iconXS))
                            if let aid = selectedAgentId,
                               let agent = availableAgents.first(where: { $0.id == aid }) {
                                Text(agent.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(theme.accent)
                    }
                    .menuStyle(.borderlessButton)
                }

                if availableAgents.count >= 2 {
                    Button(action: { showRelayPicker = true }) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: theme.iconXS))
                            if !relayAgentIds.isEmpty {
                                Text("\(relayAgentIds.count)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isRelaying ? theme.accentDestructive.opacity(0.15) : theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(isRelaying ? theme.accentDestructive : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showRelayPicker) {
                        relayPickerView
                    }
                }

                TextField(i18n.t(.cw_chat_inputPh), text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(isStreaming ? theme.accentDestructive : (inputText.trimmingCharacters(in: .whitespaces).isEmpty ? theme.textQuaternary : theme.accent))
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isStreaming)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)
            .background(theme.toolbarBg)
        }
    }

    private func sendMessage() {
        if isStreaming || isRelaying { return }
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        if !relayAgentIds.isEmpty {
            sendRelayMessage(content: text)
            return
        }
        let userMsg = SpaceMessage(
            spaceId: spaceId, senderId: "local_user",
            senderName: "", senderType: "user", content: text
        )
        messages.append(userMsg)
        startStreaming(content: text)
    }

    private func startStreaming(content: String) {
        let mentionedAgents = extractMentionedAgents(from: content)
        streamingContent = ""
        isStreaming = true
        streamingAgentName = ""
        if let aid = selectedAgentId,
           let agent = availableAgents.first(where: { $0.id == aid }) {
            streamingAgentName = agent.name
        }
        Task {
            do {
                let stream = ipc.spaceChatStreamEvents(
                    spaceId: spaceId, content: content,
                    senderId: "local_user", mentionedAgents: mentionedAgents
                )
                for try await event in stream {
                    await MainActor.run {
                        if event.isToken {
                            streamingContent += event.content
                        } else if event.isDone {
                            finalizeStreaming()
                        } else if event.isError {
                            spaceLog.error("stream error: \(event.content)")
                            if streamingContent.isEmpty {
                                streamingContent = String(format: i18n.t(.cw_chat_streamErr), event.content)
                            }
                            finalizeStreaming()
                        } else if event.isThinking {
                            if streamingAgentName.isEmpty && !event.name.isEmpty {
                                streamingAgentName = event.name
                            }
                        }
                    }
                }
                if isStreaming {
                    await MainActor.run { finalizeStreaming() }
                }
            } catch {
                spaceLog.error("spaceChatStreamEvents failed: \(error.localizedDescription)")
                await MainActor.run {
                    streamingContent = String(format: i18n.t(.cw_chat_sendFail), error.localizedDescription)
                    finalizeStreaming()
                }
            }
        }
    }

    private func finalizeStreaming() {
        if !streamingContent.isEmpty {
            let agentMsg = SpaceMessage(
                spaceId: spaceId,
                senderId: selectedAgentId ?? "agent",
                senderName: streamingAgentName.isEmpty ? "Agent" : streamingAgentName,
                senderType: "agent",
                content: streamingContent
            )
            messages.append(agentMsg)
        }
        streamingContent = ""
        isStreaming = false
        streamingAgentName = ""
    }

    private func extractMentionedAgents(from text: String) -> [String] {
        var agents: [String] = []
        let pattern = "@(\\w+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    agents.append(String(text[range]))
                }
            }
        }
        if let aid = selectedAgentId { agents.append(aid) }
        return agents
    }

    private func loadMessages() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceChatHistory(spaceId: spaceId)
                let items = result["messages"] as? [[String: Any]] ?? []
                let msgs = items.map { SpaceMessage.fromDict($0) }
                await MainActor.run { messages = msgs; isLoading = false }
            } catch {
                spaceLog.error("chat.history failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { availableAgents = items.map { SpaceAgent.fromDict($0) } }
            } catch {
                spaceLog.error("agent.list for chat failed: \(error.localizedDescription)")
            }
        }
    }

    private var relayPickerView: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.cw_chat_relay))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
            Text(i18n.t(.cw_chat_relayHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
            ForEach(availableAgents) { agent in
                Button(action: {
                    if relayAgentIds.contains(agent.id) {
                        relayAgentIds.removeAll { $0 == agent.id }
                    } else {
                        relayAgentIds.append(agent.id)
                    }
                }) {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: relayAgentIds.contains(agent.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(relayAgentIds.contains(agent.id) ? theme.accent : theme.textTertiary)
                        Image(systemName: agent.typeIcon)
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.accent)
                        Text(agent.name)
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        if let idx = relayAgentIds.firstIndex(of: agent.id) {
                            Text("#\(idx + 1)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            if !relayAgentIds.isEmpty {
                HStack {
                    Button(i18n.t(.cw_chat_relayClear)) { relayAgentIds = [] }
                        .buttonStyle(.plain)
                        .font(.system(size: 9))
                    Spacer()
                    Button(i18n.t(.cw_chat_relayDone)) { showRelayPicker = false }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(theme.spacingM)
        .frame(width: 280)
    }

    private func sendRelayMessage(content: String) {
        guard !relayAgentIds.isEmpty else { return }
        isRelaying = true
        let userMsg = SpaceMessage(
            spaceId: spaceId, senderId: "local_user",
            senderName: "", senderType: "user", content: content
        )
        messages.append(userMsg)
        Task {
            do {
                let result = try await ipc.spaceAgentRelay(
                    spaceId: spaceId, agentIds: relayAgentIds,
                    message: content
                )
                let relayMessages = result["messages"] as? [[String: Any]] ?? []
                await MainActor.run {
                    for rm in relayMessages {
                        let msg = SpaceMessage.fromDict(rm)
                        messages.append(msg)
                    }
                    isRelaying = false
                }
                spaceLog.info("Agent relay completed with \(relayAgentIds.count) agents")
            } catch {
                spaceLog.error("Agent relay failed: \(error.localizedDescription)")
                await MainActor.run {
                    let errMsg = SpaceMessage(
                        spaceId: spaceId, senderId: "system",
                        senderName: i18n.t(.cw_system_name), senderType: "system",
                        content: String(format: i18n.t(.cw_chat_relayFail), error.localizedDescription)
                    )
                    messages.append(errMsg)
                    isRelaying = false
                }
            }
        }
    }
}

private struct IdentifiableString: Identifiable {
    let id: String
}

// MARK: - Page 8: 批注子线程

struct SpaceCommentThread: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    let messageId: String

    @State private var comments: [SpaceComment] = []
    @State private var newComment = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_comment_title))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingL)

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(comments) { comment in
                            commentRow(comment)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                }
            }

            Divider()
            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.cw_comment_addPh), text: $newComment)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addComment() }
                Button(i18n.t(.cw_comment_send)) { addComment() }
                    .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(theme.spacingL)
        }
        .frame(width: 400, height: 400)
        .onAppear { loadComments() }
    }

    private func commentRow(_ comment: SpaceComment) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: "person.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(comment.authorName.isEmpty ? comment.authorId : comment.authorName)
                        .font(.system(size: theme.captionSize, weight: .semibold))
                    Text(comment.createdAt, style: .time)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(comment.content)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
            }
        }
        .padding(theme.spacingS)
    }

    private func addComment() {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        newComment = ""
        Task {
            do {
                _ = try await ipc.spaceCommentCreate(
                    spaceId: spaceId, messageId: messageId,
                    authorId: "local_user", content: text
                )
                loadComments()
            } catch {
                spaceLog.error("comment.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadComments() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceCommentList(spaceId: spaceId, messageId: messageId)
                let items = result["comments"] as? [[String: Any]] ?? []
                await MainActor.run { comments = items.map { SpaceComment.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("comment.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 4: 成员管理面板

struct SpaceMemberPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var members: [SpaceMember] = []
    @State private var isLoading = false
    @State private var showInviteDialog = false
    @State private var inviteRole = SpaceRole.member
    @State private var inviteCode = ""
    @State private var inviteMaxUses = 0
    @State private var inviteExpiresHours = 0
    @State private var discoveredPeers: [SpaceDiscoveryPeer] = []
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_member_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showInviteDialog = true }) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadMembers() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)
            .padding(.bottom, theme.spacingXS)

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(members) { member in
                            memberRow(member)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }

            Divider().padding(.vertical, theme.spacingXS)

            HStack {
                Text(i18n.t(.cw_member_lanDiscovery))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { scanPeers() }) {
                    HStack(spacing: 2) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 9))
                        Text(isScanning ? i18n.t(.cw_member_scanning) : i18n.t(.cw_member_scan))
                            .font(.system(size: 9))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)

            if !discoveredPeers.isEmpty {
                ForEach(discoveredPeers) { peer in
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(peer.name)
                                .font(.system(size: theme.captionSize))
                            Text("\(peer.host):\(peer.port)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, 3)
                }
            }
        }
        .onAppear { loadMembers() }
        .alert(i18n.t(.cw_member_inviteTitle), isPresented: $showInviteDialog) {
            Picker(i18n.t(.cw_member_inviteRole), selection: $inviteRole) {
                ForEach(SpaceRole.allCases, id: \.self) { role in
                    Text(roleLabel(role)).tag(role)
                }
            }
            Stepper(String(format: i18n.t(.cw_member_inviteMaxUses), inviteMaxUses), value: $inviteMaxUses, in: 0...100)
            Stepper(String(format: i18n.t(.cw_member_inviteExpires), inviteExpiresHours), value: $inviteExpiresHours, in: 0...168)
            Button(i18n.t(.cw_member_inviteGen)) { generateInvite() }
            Button(i18n.t(.cancel), role: .cancel) { }
        } message: {
            if !inviteCode.isEmpty {
                Text(String(format: i18n.t(.cw_member_inviteCode), inviteCode))
            }
        }
    }

    private func roleLabel(_ role: SpaceRole) -> String {
        switch role {
        case .owner: return i18n.t(.cw_role_owner)
        case .admin: return i18n.t(.cw_role_admin)
        case .member: return i18n.t(.cw_role_member)
        case .viewer: return i18n.t(.cw_role_viewer)
        }
    }

    private func memberRow(_ member: SpaceMember) -> some View {
        HStack(spacing: theme.spacingS) {
            Circle()
                .fill(member.isOnline ? Color.green : theme.textTertiary)
                .frame(width: 6, height: 6)
            Image(systemName: "person.circle")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(member.displayLabel)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                Text(roleLabel(member.role))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if member.role != .owner {
                Menu {
                    ForEach(SpaceRole.allCases, id: \.self) { role in
                        Button(roleLabel(role)) { updateRole(member, newRole: role) }
                    }
                    Divider()
                    Button(i18n.t(.cw_member_remove), role: .destructive) { removeMember(member) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private func generateInvite() {
        Task {
            do {
                let result = try await ipc.spaceMemberInvite(
                    spaceId: spaceId, role: inviteRole.rawValue,
                    maxUses: inviteMaxUses, expiresHours: inviteExpiresHours
                )
                if let code = result["invite_code"] as? String {
                    await MainActor.run { inviteCode = code }
                    spaceLog.info("Invite generated: \(code)")
                }
            } catch {
                spaceLog.error("invite failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateRole(_ member: SpaceMember, newRole: SpaceRole) {
        Task {
            do {
                _ = try await ipc.spaceMemberUpdateRole(spaceId: spaceId, userId: member.userId, newRole: newRole.rawValue)
                loadMembers()
            } catch {
                spaceLog.error("updateRole failed: \(error.localizedDescription)")
            }
        }
    }

    private func removeMember(_ member: SpaceMember) {
        Task {
            do {
                _ = try await ipc.spaceMemberRemove(spaceId: spaceId, userId: member.userId)
                loadMembers()
            } catch {
                spaceLog.error("removeMember failed: \(error.localizedDescription)")
            }
        }
    }

    private func scanPeers() {
        isScanning = true
        Task {
            do {
                let result = try await ipc.spaceDiscoveryScan()
                let items = result["peers"] as? [[String: Any]] ?? []
                await MainActor.run {
                    discoveredPeers = items.map { SpaceDiscoveryPeer.fromDict($0) }
                    isScanning = false
                }
            } catch {
                spaceLog.error("discovery.scan failed: \(error.localizedDescription)")
                await MainActor.run { isScanning = false }
            }
        }
    }

    private func loadMembers() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceMemberList(spaceId: spaceId)
                let items = result["members"] as? [[String: Any]] ?? []
                await MainActor.run { members = items.map { SpaceMember.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("member.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Files Panel

struct SpaceFilesPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var files: [SpaceAttachment] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_files_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { loadFiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if files.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "folder")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_files_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(files) { file in
                            HStack(spacing: theme.spacingS) {
                                Image(systemName: "doc")
                                    .font(.system(size: theme.iconS))
                                    .foregroundStyle(theme.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.fileName)
                                        .font(.system(size: theme.captionSize))
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .onAppear { loadFiles() }
    }

    private func loadFiles() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceArtifactList(spaceId: spaceId)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                await MainActor.run { files = items.map { SpaceAttachment.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("file.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 5: Agent管理面板

struct SpaceAgentPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var agents: [SpaceAgent] = []
    @State private var isLoading = false
    @State private var showEditor = false
    @State private var editAgentId: String?
    @State private var editName = ""
    @State private var editPrompt = ""
    @State private var editPerm = "all_member"
    @State private var editModel = ""
    @State private var isSaving = false
    @State private var searchPublished = ""
    @State private var publishedAgents: [SpaceAgent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_agent_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showEditor = true; editAgentId = nil; editName = ""; editPrompt = ""; editPerm = "all_member"; editModel = "" }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadAgents() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if agents.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_agent_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Button(i18n.t(.cw_agent_add)) {
                        showEditor = true; editAgentId = nil; editName = ""; editPrompt = ""
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(agents) { agent in
                            agentRow(agent)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadAgents() }
        .sheet(isPresented: $showEditor) {
            agentEditorSheet
        }
    }

    private func agentRow(_ agent: SpaceAgent) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: theme.spacingXS) {
                    Text(permLabel(agent.permission))
                        .font(.system(size: 9))
                    if !agent.model.isEmpty {
                        Text(agent.model)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(agent.source)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Menu {
                Button(i18n.t(.cw_agent_edit)) {
                    editAgentId = agent.id
                    editName = agent.name
                    editPrompt = agent.systemPrompt
                    editPerm = agent.permission
                    editModel = agent.model
                    showEditor = true
                }
                Button(i18n.t(.cw_agent_copyToProject)) { }
                Divider()
                Button(i18n.t(.cw_agent_remove), role: .destructive) { removeAgent(agent) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private var agentEditorSheet: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text(editAgentId == nil ? i18n.t(.cw_agent_addTitle) : i18n.t(.cw_agent_editTitle))
                .font(.system(size: theme.headlineSize, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_name)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.cw_agent_namePh), text: $editName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_model)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextField(i18n.t(.cw_agent_modelPh), text: $editModel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t(.cw_agent_perm)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                Picker("", selection: $editPerm) {
                    Text(i18n.t(.cw_agent_permAll)).tag("all_member")
                    Text(i18n.t(.cw_agent_permAdmin)).tag("admin_only")
                    Text(i18n.t(.cw_agent_permCustom)).tag("custom")
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: theme.captionSize))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt").font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
                TextEditor(text: $editPrompt)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .frame(height: 120)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.textTertiary.opacity(0.2)))
            }

            Spacer(minLength: 0)
            HStack {
                Button(i18n.t(.cancel)) { showEditor = false }
                Spacer()
                Button(i18n.t(.save)) { saveAgent() }
                    .disabled(editName.isEmpty || isSaving)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 440)
    }

    private func permLabel(_ perm: String) -> String {
        switch perm {
        case "all_member": return i18n.t(.cw_agent_permAllLabel)
        case "admin_only": return i18n.t(.cw_agent_permAdmin)
        case "custom": return i18n.t(.cw_agent_permCustomLabel)
        default: return perm
        }
    }

    private func saveAgent() {
        isSaving = true
        Task {
            do {
                if let aid = editAgentId {
                    _ = try await ipc.spaceCall(method: "desk.space.agent.update", params: [
                        "space_id": spaceId, "agent_id": aid,
                        "agent_name": editName, "system_prompt": editPrompt,
                        "permission": editPerm, "model": editModel,
                    ])
                } else {
                    _ = try await ipc.spaceAgentAdd(
                        spaceId: spaceId, agentName: editName,
                        systemPrompt: editPrompt, permission: editPerm, model: editModel
                    )
                }
                spaceLog.info("Agent saved: \(editName)")
                await MainActor.run { showEditor = false; isSaving = false }
                loadAgents()
            } catch {
                spaceLog.error("saveAgent failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }

    private func removeAgent(_ agent: SpaceAgent) {
        Task {
            do {
                _ = try await ipc.spaceAgentRemove(spaceId: spaceId, agentId: agent.id)
                loadAgents()
            } catch {
                spaceLog.error("removeAgent failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadAgents() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { agents = items.map { SpaceAgent.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("agent.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 6: 快照管理

struct SpaceSnapshotPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var snapshots: [SpaceSnapshot] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var snapName = ""
    @State private var showForkDialog = false
    @State private var forkSnapId = ""
    @State private var forkName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_snap2_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadSnapshots() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if snapshots.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_snap2_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(snapshots) { snap in
                            snapRow(snap)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadSnapshots() }
        .alert(i18n.t(.cw_snap2_createTitle), isPresented: $showCreate) {
            TextField(i18n.t(.cw_snap2_namePh), text: $snapName)
            Button(i18n.t(.cw_snap2_createTitle)) { createSnapshot() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
        .alert(i18n.t(.cw_snap2_forkTitle), isPresented: $showForkDialog) {
            TextField(i18n.t(.cw_snap2_forkSpacePh), text: $forkName)
            Button(i18n.t(.cw_snap2_forkTitle)) { forkSnapshot() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
    }

    private func snapRow(_ snap: SpaceSnapshot) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "camera")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                HStack(spacing: theme.spacingXS) {
                    Label("\(snap.messageCount)", systemImage: "bubble.left")
                    Label("\(snap.agentCount)", systemImage: "brain.head.profile")
                    Label("\(snap.artifactCount)", systemImage: "shippingbox")
                }
                .font(.system(size: 8))
                .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Menu {
                Button(i18n.t(.cw_snap2_restore)) { restoreSnapshot(snap.id) }
                Button(i18n.t(.cw_snap2_forkNew)) {
                    forkSnapId = snap.id
                    forkName = snap.name + " (Fork)"
                    showForkDialog = true
                }
                Divider()
                Button(i18n.t(.delete), role: .destructive) { deleteSnapshot(snap.id) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
    }

    private func createSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceSnapshotCreate(spaceId: spaceId, name: snapName.isEmpty ? "snapshot" : snapName)
                snapName = ""
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func restoreSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.space.snapshot.restore", params: [
                    "space_id": spaceId, "snapshot_id": snapId,
                ])
                spaceLog.info("Snapshot restored: \(snapId)")
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.restore failed: \(error.localizedDescription)")
            }
        }
    }

    private func forkSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceSnapshotClone(spaceId: spaceId, snapshotId: forkSnapId, newName: forkName)
                spaceLog.info("Snapshot forked: \(forkSnapId)")
                forkName = ""
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.fork failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSnapshot(_ snapId: String) {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.space.snapshot.delete", params: [
                    "space_id": spaceId, "snapshot_id": snapId,
                ])
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.delete failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadSnapshots() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceSnapshotList(spaceId: spaceId)
                let items = result["snapshots"] as? [[String: Any]] ?? []
                await MainActor.run { snapshots = items.map { SpaceSnapshot.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("snapshot.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 7.6: 产物管理

struct SpaceArtifactPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @Binding var selectedArtifact: SpaceArtifact?
    @State private var artifacts: [SpaceArtifact] = []
    @State private var isLoading = false
    @State private var kindFilter: String = "all"
    @State private var showCreateDialog = false
    @State private var newArtName = ""
    @State private var newArtKind = "code"
    @State private var newArtDesc = ""

    private let kinds = ["all", "code", "doc", "visualization", "data"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_art_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadArtifacts() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(kinds, id: \.self) { kind in
                        Button(action: { kindFilter = kind }) {
                            Text(kindLabel(kind))
                                .font(.system(size: 9, weight: kindFilter == kind ? .semibold : .regular))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(kindFilter == kind ? theme.accent.opacity(0.15) : Color.clear)
                                )
                                .foregroundStyle(kindFilter == kind ? theme.accent : theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, theme.spacingM)
            }

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(filteredArtifacts) { art in
                            artifactRow(art)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .onAppear { loadArtifacts() }
        .alert(i18n.t(.cw_art_createTitle), isPresented: $showCreateDialog) {
            TextField(i18n.t(.cw_snap2_namePh), text: $newArtName)
            Picker(i18n.t(.cw_art_kindPicker), selection: $newArtKind) {
                Text(i18n.t(.cw_art_kindCode)).tag("code")
                Text(i18n.t(.cw_art_kindDoc)).tag("doc")
                Text(i18n.t(.cw_art_kindViz)).tag("visualization")
                Text(i18n.t(.cw_art_kindData)).tag("data")
            }
            TextField(i18n.t(.cw_create_descPh), text: $newArtDesc)
            Button(i18n.t(.cw_create_btn)) { createArtifact() }
            Button(i18n.t(.cancel), role: .cancel) { }
        }
    }

    private var filteredArtifacts: [SpaceArtifact] {
        if kindFilter == "all" { return artifacts }
        return artifacts.filter { $0.kind == kindFilter }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "all": return i18n.t(.cw_art_kindAll)
        case "code": return i18n.t(.cw_art_kindCode)
        case "doc": return i18n.t(.cw_art_kindDoc)
        case "visualization": return i18n.t(.cw_art_kindViz)
        case "data": return i18n.t(.cw_art_kindData)
        default: return kind
        }
    }

    private func artifactIcon(_ kind: String) -> String {
        switch kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "shippingbox"
        }
    }

    private func artifactRow(_ art: SpaceArtifact) -> some View {
        Button(action: { selectedArtifact = art }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: artifactIcon(art.kind))
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(selectedArtifact?.id == art.id ? theme.accent : theme.textTertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(art.name)
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .lineLimit(1)
                    Text(kindLabel(art.kind))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                if selectedArtifact?.id == art.id {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                    .fill(selectedArtifact?.id == art.id ? theme.accent.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func createArtifact() {
        Task {
            do {
                _ = try await ipc.spaceArtifactCreate(
                    spaceId: spaceId, name: newArtName, kind: newArtKind, description: newArtDesc
                )
                newArtName = ""; newArtDesc = ""
                loadArtifacts()
            } catch {
                spaceLog.error("artifact.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadArtifacts() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceArtifactList(spaceId: spaceId, kind: kindFilter == "all" ? nil : kindFilter)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                await MainActor.run { artifacts = items.map { SpaceArtifact.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("artifact.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 7.4: 工作流协作

struct SpaceWorkflowPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var workflows: [SpaceWorkflow] = []
    @State private var isLoading = false
    @State private var selectedWorkflow: SpaceWorkflow?
    @State private var showCreateDialog = false
    @State private var newWorkflowName = ""
    @State private var newWorkflowDesc = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_wf_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadWorkflows() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if workflows.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_wf_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Button(i18n.t(.cw_wf_create)) { showCreateDialog = true }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(workflows) { wf in
                            workflowRow(wf)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }

            Spacer()
            if let wf = selectedWorkflow {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(String(format: i18n.t(.cw_snap2_dagName), wf.name))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                    WorkflowDagCanvas(nodeCount: wf.nodeCount, status: wf.status)
                        .frame(height: 140)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingM)
            }
        }
        .onAppear { loadWorkflows() }
        .sheet(isPresented: $showCreateDialog) {
            workflowCreateSheet
        }
    }

    private var workflowCreateSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.cw_wf_createTitle))
                .font(.system(size: theme.bodySize, weight: .semibold))
            TextField(i18n.t(.cw_wf_namePh), text: $newWorkflowName)
                .textFieldStyle(.roundedBorder)
            TextField(i18n.t(.cw_wf_descPh), text: $newWorkflowDesc)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(i18n.t(.cancel)) { showCreateDialog = false }
                    .buttonStyle(.bordered)
                Button(i18n.t(.cw_create_btn)) {
                    createWorkflow()
                    showCreateDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newWorkflowName.isEmpty)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
    }

    private func workflowRow(_ wf: SpaceWorkflow) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 1) {
                Text(wf.name)
                    .font(.system(size: theme.captionSize, weight: .medium))
                HStack(spacing: theme.spacingXS) {
                    workflowStatusBadge(wf.status)
                    Text(String(format: i18n.t(.cw_wf_nodeCount), wf.nodeCount))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            Spacer()
            Button(action: { selectedWorkflow = wf }) {
                Image(systemName: "eye")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            Button(action: { runWorkflow(wf.id) }) {
                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(selectedWorkflow?.id == wf.id ? theme.accent.opacity(0.06) : Color.clear)
        )
    }

    @ViewBuilder
    private func workflowStatusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "running": .green
        case "completed": .blue
        case "failed": .red
        case "idle": Color(theme.textTertiary)
        default: Color(theme.textTertiary)
        }
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(statusLabel(status))
                .font(.system(size: 9))
                .foregroundStyle(color)
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "running": return i18n.t(.cw_wf_status_running)
        case "completed": return i18n.t(.cw_wf_status_completed)
        case "failed": return i18n.t(.cw_wf_status_failed)
        case "idle": return i18n.t(.cw_wf_status_idle)
        default: return status
        }
    }

    private func createWorkflow() {
        guard !newWorkflowName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.spaceWorkflowCreate(spaceId: spaceId, name: newWorkflowName)
                spaceLog.info("Workflow created: \(newWorkflowName)")
                newWorkflowName = ""
                newWorkflowDesc = ""
                loadWorkflows()
            } catch {
                spaceLog.error("workflow.create failed: \(error.localizedDescription)")
            }
        }
    }

    private func runWorkflow(_ workflowId: String) {
        Task {
            do {
                _ = try await ipc.spaceWorkflowRun(spaceId: spaceId, workflowId: workflowId)
                spaceLog.info("Workflow started: \(workflowId)")
                loadWorkflows()
            } catch {
                spaceLog.error("workflow.run failed: \(error.localizedDescription)")
            }
        }
    }

    private func loadWorkflows() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceWorkflowList(spaceId: spaceId)
                let items = result["workflows"] as? [[String: Any]] ?? []
                await MainActor.run { workflows = items.map { SpaceWorkflow.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("workflow.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Workflow DAG Canvas (D2 可视化)

struct WorkflowDagCanvas: View {
    @Environment(\.studioTheme) private var theme
    let nodeCount: Int
    let status: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.surfaceSecondary)

            let nodes = generateDagNodes()
            let edges = generateDagEdges(nodes: nodes)

            Canvas { context, size in
                for edge in edges {
                    var path = Path()
                    path.move(to: edge.from)
                    let ctrl1 = CGPoint(
                        x: edge.from.x + (edge.to.x - edge.from.x) * 0.4,
                        y: edge.from.y
                    )
                    let ctrl2 = CGPoint(
                        x: edge.from.x + (edge.to.x - edge.from.x) * 0.6,
                        y: edge.to.y
                    )
                    path.addCurve(to: edge.to, control1: ctrl1, control2: ctrl2)
                    context.stroke(
                        path,
                        with: .color(status == "running" ? theme.accent.opacity(0.5) : theme.textTertiary.opacity(0.3)),
                        style: StrokeStyle(lineWidth: 1.5, dash: status == "running" ? [] : [4, 3])
                    )
                }

                for node in nodes {
                    let rect = CGRect(
                        x: node.pos.x - node.size.width / 2,
                        y: node.pos.y - node.size.height / 2,
                        width: node.size.width,
                        height: node.size.height
                    )
                    let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
                    context.fill(
                        shape.path(in: rect),
                        with: .color(node.color.opacity(0.7))
                    )
                    context.stroke(
                        shape.path(in: rect),
                        with: .color(node.color),
                        lineWidth: 1
                    )
                    let text = Text(node.label)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white)
                    context.draw(text, at: node.pos)
                }
            }
        }
    }

    private struct DagNode {
        let pos: CGPoint
        let size: CGSize
        let label: String
        let color: Color
    }

    private struct DagEdge {
        let from: CGPoint
        let to: CGPoint
    }

    private func generateDagNodes() -> [DagNode] {
        let count = max(nodeCount, 3)
        let labels = [I18nManager.shared.t(.spl_step_input)] + (1...(count - 2)).map { "Step \($0)" } + [I18nManager.shared.t(.spl_step_output)]
        let colors: [Color] = [.blue] + (1...(count - 2)).map { _ in theme.accent } + [.green]
        let w: CGFloat = 260
        let h: CGFloat = 120
        let padX: CGFloat = 40
        let padY: CGFloat = 20
        let usableW = w - padX * 2
        let usableH = h - padY * 2

        return (0..<count).map { i in
            let x = count == 1 ? w / 2 : padX + usableW * CGFloat(i) / CGFloat(count - 1)
            let y = h / 2 + sin(Double(i) * 0.8) * usableH * 0.3
            return DagNode(
                pos: CGPoint(x: x, y: y),
                size: CGSize(width: 44, height: 22),
                label: labels[i],
                color: colors[i]
            )
        }
    }

    private func generateDagEdges(nodes: [DagNode]) -> [DagEdge] {
        guard nodes.count >= 2 else { return [] }
        var edges: [DagEdge] = []
        for i in 0..<(nodes.count - 1) {
            edges.append(DagEdge(from: nodes[i].pos, to: nodes[i + 1].pos))
        }
        if nodes.count > 3 {
            edges.append(DagEdge(from: nodes[0].pos, to: nodes[2].pos))
        }
        return edges
    }
}

// MARK: - Page 7.7: 桌面共享

struct SpaceDesktopPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var isSharing = false
    @State private var role = "observer"
    @State private var auditLog: [[String: Any]] = []
    @State private var controlRequests: [[String: Any]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_desk_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Picker(i18n.t(.cw_desk_role), selection: $role) {
                    Text(i18n.t(.cw_desk_roleObserver)).tag("observer")
                    Text(i18n.t(.cw_desk_roleController)).tag("controller")
                    Text(i18n.t(.cw_desk_roleApprover)).tag("approver")
                }
                .frame(width: 100)
                .font(.system(size: 9))
                Button(action: { toggleShare() }) {
                    Image(systemName: isSharing ? "stop.fill" : "play.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(isSharing ? Color.red : Color.green)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isSharing {
                sharedDesktopView
            } else {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_desk_notSharing))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            }

            if !controlRequests.isEmpty {
                Divider().padding(.vertical, theme.spacingXS)
                Text(i18n.t(.cw_desk_controlReq))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                ForEach(controlRequests.indices, id: \.self) { idx in
                    HStack {
                        Text(controlRequests[idx]["user_id"] as? String ?? "")
                            .font(.system(size: 9))
                        Spacer()
                        Button(i18n.t(.cw_desk_approve)) { approveControl(controlRequests[idx]) }
                            .font(.system(size: 9))
                            .foregroundStyle(Color.green)
                            .buttonStyle(.plain)
                        Button(i18n.t(.cw_desk_reject)) { rejectControl(controlRequests[idx]) }
                            .font(.system(size: 9))
                            .foregroundStyle(Color.red)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.vertical, 2)
                }
            }

            if !auditLog.isEmpty {
                Divider().padding(.vertical, theme.spacingXS)
                Text(i18n.t(.cw_desk_auditLog))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, theme.spacingM)
                ScrollView {
                    ForEach(auditLog.indices, id: \.self) { idx in
                        let a = auditLog[idx]
                        HStack {
                            Text(a["operation"] as? String ?? "")
                                .font(.system(size: 8))
                            Spacer()
                            Text(a["timestamp"] as? String ?? "")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.horizontal, theme.spacingM)
                    }
                }
                .frame(maxHeight: 80)
            }
        }
    }

    private var sharedDesktopView: some View {
        VStack(spacing: theme.spacingXS) {
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .fill(theme.surfaceSecondary)
                    .frame(height: 100)
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.textTertiary)
            }
            HStack(spacing: theme.spacingXS) {
                Label(i18n.t(.cw_desk_sharing), systemImage: "circle.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.green)
                Text(deskRoleLabel(role))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.top, theme.spacingS)
    }

    private func deskRoleLabel(_ raw: String) -> String {
        switch raw {
        case "observer": return i18n.t(.cw_desk_roleObserver)
        case "controller": return i18n.t(.cw_desk_roleController)
        case "approver": return i18n.t(.cw_desk_roleApprover)
        default: return raw
        }
    }

    private func toggleShare() {
        let action = isSharing ? "stop" : "start"
        isSharing.toggle()
        Task {
            do {
                _ = try await ipc.spaceDesktopShare(spaceId: spaceId, action: action)
                if isSharing {
                    spaceLog.info("Desktop sharing started")
                } else {
                    spaceLog.info("Desktop sharing stopped")
                }
            } catch {
                spaceLog.error("desktop share failed: \(error.localizedDescription)")
                await MainActor.run { isSharing.toggle() }
            }
        }
    }

    private func approveControl(_ request: [String: Any]) {
        guard let reqId = request["id"] as? String ?? request["request_id"] as? String else { return }
        Task {
            do {
                _ = try await ipc.spaceDesktopControl(spaceId: spaceId, action: "approve_\(reqId)")
                spaceLog.info("Control request approved: \(reqId)")
            } catch {
                spaceLog.error("Control approve failed: \(error.localizedDescription)")
            }
        }
    }

    private func rejectControl(_ request: [String: Any]) {
        guard let reqId = request["id"] as? String ?? request["request_id"] as? String else { return }
        Task {
            do {
                _ = try await ipc.spaceDesktopControl(spaceId: spaceId, action: "reject_\(reqId)")
                spaceLog.info("Control request rejected: \(reqId)")
            } catch {
                spaceLog.error("Control reject failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Space Settings Panel

struct SpaceSettingsPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    let space: CoworkSpace?

    @State private var config = SpaceConfig()
    @State private var isSaving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_set_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(i18n.t(.save)) { saveConfig() }
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .disabled(isSaving)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    toolToggle(i18n.t(.cw_create_webSearch), icon: "globe", isOn: $config.enableWebSearch)
                    toolToggle(i18n.t(.cw_create_deepResearch), icon: "telescope", isOn: $config.enableDeepResearch)
                    toolToggle(i18n.t(.cw_create_computerUse), icon: "desktopcomputer", isOn: $config.enableComputerUse)
                    toolToggle(i18n.t(.cw_create_memberUpload), icon: "arrow.up.doc", isOn: $config.allowMemberUpload)
                    toolToggle(i18n.t(.cw_create_memberAgent), icon: "brain.head.profile", isOn: $config.allowMemberAgent)
                    toolToggle(i18n.t(.cw_create_memberWorkflow), icon: "arrow.triangle.branch", isOn: $config.allowMemberWorkflow)

                    HStack {
                        Text(i18n.t(.cw_create_maxMembers))
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        Stepper(value: $config.maxMembers, in: 2...50) {
                            Text("\(config.maxMembers)")
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .frame(width: 30)
                        }
                    }
                    .padding(.horizontal, theme.spacingM)

                    HStack {
                        Text(i18n.t(.cw_set_streamResp))
                            .font(.system(size: theme.captionSize))
                        Spacer()
                        Toggle("", isOn: $config.streamResponse)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.horizontal, theme.spacingM)
                }
                .padding(.vertical, theme.spacingS)
            }
        }
        .onAppear {
            if let s = space { config = s.config }
        }
    }

    private func toolToggle(_ label: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: theme.iconXS))
                .foregroundStyle(isOn.wrappedValue ? theme.accent : theme.textTertiary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: theme.captionSize))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 2)
    }

    private func saveConfig() {
        isSaving = true
        Task {
            do {
                _ = try await ipc.spaceUpdate(spaceId: spaceId, updates: ["config": config.toDict()])
                spaceLog.info("Space config saved: \(spaceId)")
                await MainActor.run { isSaving = false }
            } catch {
                spaceLog.error("config save failed: \(error.localizedDescription)")
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Page 7.5: 深度研究

struct SpaceDeepResearchView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String

    @State private var query = ""
    @State private var depth = 2
    @State private var isRunning = false
    @State private var result: [String: Any]?
    @State private var resultText = ""
    @State private var agentTracks: [ResearchAgentTrack] = []
    @State private var useMultiAgent = true
    @State private var availableAgents: [SpaceAgent] = []
    @State private var selectedAgentIds: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.cw_main_deepResearch))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                if isRunning {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(i18n.t(.cw_research_running))
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                    }
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.cw_research_queryPh), text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker(i18n.t(.cw_research_depth), selection: $depth) {
                    Text(i18n.t(.cw_research_depthShallow)).tag(1)
                    Text(i18n.t(.cw_research_depthMedium)).tag(2)
                    Text(i18n.t(.cw_research_depthDeep)).tag(3)
                }
                .frame(width: 80)
                Button(i18n.t(.cw_research_start)) { startResearch() }
                    .disabled(query.isEmpty || isRunning)
            }

            HStack(spacing: theme.spacingM) {
                Toggle(isOn: $useMultiAgent) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: theme.iconXS))
                        Text(i18n.t(.cw_research_multiAgent))
                            .font(.system(size: theme.captionSize))
                    }
                }
                .toggleStyle(.checkbox)
                if useMultiAgent && !availableAgents.isEmpty {
                    Menu {
                        ForEach(availableAgents) { agent in
                            Button(action: {
                                if selectedAgentIds.contains(agent.id) {
                                    selectedAgentIds.removeAll { $0 == agent.id }
                                } else {
                                    selectedAgentIds.append(agent.id)
                                }
                            }) {
                                HStack {
                                    Text(agent.name)
                                    if selectedAgentIds.contains(agent.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 9))
                            Text(selectedAgentIds.isEmpty ? i18n.t(.cw_research_autoSelect) : String(format: i18n.t(.cw_research_agentCountFmt), selectedAgentIds.count))
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(theme.accent)
                    }
                }
                Spacer()
                Text(i18n.t(.cw_research_zeroToken))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }

            if isRunning && !agentTracks.isEmpty {
                multiAgentProgressView
            } else if isRunning {
                VStack(spacing: theme.spacingS) {
                    ProgressView()
                    Text(i18n.t(.cw_research_runningProgress))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !resultText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        if !agentTracks.filter({ !$0.result.isEmpty }).isEmpty {
                            researchTrackSummary
                            Divider()
                        }
                        MarkdownContentView(content: resultText)
                    }
                    .padding(theme.spacingM)
                }
            } else {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "telescope")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_research_desc))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Text(i18n.t(.cw_research_vsClaude))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.accent)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 640, height: 560)
        .onAppear { loadAgents() }
    }

    private var researchTrackSummary: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.cw_research_track))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(agentTracks.filter { !$0.result.isEmpty }) { track in
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(.green)
                    Text(track.agentName)
                        .font(.system(size: theme.captionSize, weight: .medium))
                    Text(track.result.prefix(80) + (track.result.count > 80 ? "..." : ""))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var multiAgentProgressView: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.cw_research_agentProgress))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(agentTracks) { track in
                HStack(spacing: theme.spacingS) {
                    if track.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(.green)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Text(track.agentName)
                        .font(.system(size: theme.captionSize, weight: .medium))
                    Text(track.status)
                        .font(.system(size: 9))
                        .foregroundStyle(track.isComplete ? .green : theme.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(theme.spacingM)
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { availableAgents = items.map { SpaceAgent.fromDict($0) } }
            } catch {
                spaceLog.error("agent.list for research failed: \(error.localizedDescription)")
            }
        }
    }

    private func startResearch() {
        isRunning = true
        resultText = ""
        agentTracks = []

        if useMultiAgent && (selectedAgentIds.count >= 2 || (selectedAgentIds.isEmpty && availableAgents.count >= 2)) {
            startMultiAgentResearch()
        } else {
            startSingleResearch()
        }
    }

    private func startSingleResearch() {
        Task {
            do {
                let r = try await ipc.spaceDeepResearch(spaceId: spaceId, query: query, depth: depth)
                await MainActor.run {
                    result = r
                    resultText = r["summary"] as? String ?? r["content"] as? String ?? i18n.t(.cw_research_noResult)
                    isRunning = false
                }
            } catch {
                spaceLog.error("deep.research failed: \(error.localizedDescription)")
                await MainActor.run {
                    resultText = String(format: i18n.t(.cw_research_failFmt), error.localizedDescription)
                    isRunning = false
                }
            }
        }
    }

    private func startMultiAgentResearch() {
        let agents = selectedAgentIds.isEmpty
            ? Array(availableAgents.prefix(3))
            : availableAgents.filter { selectedAgentIds.contains($0.id) }

        agentTracks = agents.map { ResearchAgentTrack(agentId: $0.id, agentName: $0.name) }

        Task {
            var responses: [[String: Any]?] = []
            for agent in agents {
                let resp = try? await ipc.spaceAgentCall(
                    spaceId: spaceId, agentId: agent.id,
                    message: i18n.tf(.spl_deep_research_fmt, depth, query)
                )
                responses.append(resp)
                await MainActor.run {
                    if let idx = agentTracks.firstIndex(where: { $0.agentId == agent.id }) {
                        let content = resp?["content"] as? String ?? resp?["response"] as? String ?? ""
                        agentTracks[idx].result = content
                        agentTracks[idx].isComplete = true
                        agentTracks[idx].status = i18n.t(.cw_research_done)
                    }
                }
            }
            await MainActor.run {
                var combinedText = ""
                for track in agentTracks where !track.result.isEmpty {
                    combinedText += "### \(track.agentName)\n\n\(track.result)\n\n---\n\n"
                }
                resultText = combinedText
                isRunning = false
            }
            spaceLog.info("Multi-agent deep research completed with \(agents.count) agents")
        }
    }
}

private struct ResearchAgentTrack: Identifiable {
    let id = UUID().uuidString
    let agentId: String
    let agentName: String
    var status: String = I18nManager.shared.t(.cw_research_runningStatus)
    var result: String = ""
    var isComplete: Bool = false
}

// MARK: - Markdown Content View

struct MarkdownContentView: View {
    @Environment(\.studioTheme) private var theme

    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            ForEach(parsedBlocks, id: \.id) { block in
                switch block.type {
                case .code:
                    codeBlock(block)
                case .text:
                    inlineText(block.content)
                }
            }
        }
    }

    private enum BlockType { case code, text }
    private struct ContentBlock: Identifiable {
        let id: Int
        let type: BlockType
        let content: String
        let language: String
    }

    private var parsedBlocks: [ContentBlock] {
        var blocks: [ContentBlock] = []
        var idx = 0
        let lines = content.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(ContentBlock(id: idx, type: .code, content: codeLines.joined(separator: "\n"), language: lang))
                idx += 1
                i += 1
            } else {
                var textLines: [String] = [line]
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    textLines.append(lines[i])
                    i += 1
                }
                let text = textLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    blocks.append(ContentBlock(id: idx, type: .text, content: text, language: ""))
                    idx += 1
                }
            }
        }
        return blocks
    }

    private func inlineText(_ text: String) -> some View {
        if let attr = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
                .textSelection(.enabled)
        }
        return Text(text)
            .font(.system(size: theme.textSize))
            .foregroundStyle(theme.text)
            .textSelection(.enabled)
    }

    private func codeBlock(_ block: ContentBlock) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if !block.language.isEmpty {
                    Text(block.language)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(block.content, forType: .string)
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(theme.surfaceSecondary.opacity(0.6))

            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
                    .padding(theme.spacingS)
            }
        }
        .background(theme.surfaceSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .stroke(theme.separator, lineWidth: 0.5)
        )
    }
}

// MARK: - Artifact Preview View

struct ArtifactPreviewView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let artifact: SpaceArtifact
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: kindIcon(artifact.kind))
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(artifact.name)
                        .font(.system(size: theme.footnoteSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    Text(kindLabel(artifact.kind))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)

            Divider()

            if artifact.content.isEmpty && artifact.filePath.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_preview_empty))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if artifact.kind == "code" || artifact.kind == "visualization" {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        MarkdownContentView(content: "```\(languageTag)\n\(artifact.content)\n```")
                    }
                    .padding(theme.spacingM)
                }
            } else {
                ScrollView {
                    MarkdownContentView(content: artifact.content)
                        .padding(theme.spacingM)
                }
            }

            if !artifact.filePath.isEmpty {
                Divider()
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                    Text(artifact.filePath)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(artifact.filePath, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.surfaceSecondary.opacity(0.3))
            }
        }
        .frame(minWidth: 280, maxWidth: 400)
        .background(theme.surfacePrimary)
    }

    private var languageTag: String {
        switch artifact.kind {
        case "code": return ""
        default: return ""
        }
    }

    private func kindIcon(_ kind: String) -> String {
        switch kind {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "shippingbox"
        }
    }

    private func kindLabel(_ kind: String) -> String {
        switch kind {
        case "code": return i18n.t(.cw_art_kindCode)
        case "doc": return i18n.t(.cw_art_kindDoc)
        case "visualization": return i18n.t(.cw_art_kindViz)
        case "data": return i18n.t(.cw_art_kindData)
        default: return kind
        }
    }
}

// MARK: - Legacy compatibility aliases

typealias SpaceMemberView = SpaceMemberPanel
typealias SpaceAgentView = SpaceAgentPanel
// MARK: - Notification Popover

struct SpaceNotificationPopover: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared
    private let spaceManager = CoworkSpaceManager.shared
    @State private var notifications: [SpaceNotification] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_notif_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                let unread = notifications.filter { !$0.isRead }.count
                if unread > 0 {
                    Text("\(unread)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                Spacer()
                Button(i18n.t(.cw_notif_markAll)) { markAllRead() }
                    .font(.system(size: 9))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)

            Divider()

            if notifications.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_notif_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notif in
                            notificationRow(notif)
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 360)
        .onAppear { loadNotifications() }
    }

    private func notificationRow(_ notif: SpaceNotification) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            Image(systemName: notif.typeIcon)
                .font(.system(size: theme.iconS))
                .foregroundStyle(notif.isRead ? theme.textTertiary : theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(notif.title)
                    .font(.system(size: theme.captionSize, weight: notif.isRead ? .regular : .semibold))
                    .foregroundStyle(notif.isRead ? theme.textSecondary : theme.text)
                if !notif.content.isEmpty {
                    Text(notif.content)
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
                Text(notif.createdAt, style: .relative)
                    .font(.system(size: 8))
                    .foregroundStyle(theme.textQuaternary)
            }
            Spacer()
            if !notif.isRead {
                Button(action: { markRead(notif.id) }) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(notif.isRead ? Color.clear : theme.accent.opacity(0.04))
    }

    private func loadNotifications() {
        Task {
            await spaceManager.loadNotifications()
            await MainActor.run { notifications = spaceManager.activeNotifications }
        }
    }

    private func markRead(_ id: String) {
        Task {
            await spaceManager.markNotificationRead(notificationId: id)
            await MainActor.run {
                notifications = notifications.map { n in
                    var m = n; if n.id == id { m.isRead = true }; return m
                }
            }
        }
    }

    private func markAllRead() {
        for notif in notifications.filter({ !$0.isRead }) {
            Task { await spaceManager.markNotificationRead(notificationId: notif.id) }
        }
        notifications = notifications.map { n in
            var m = n; m.isRead = true; return m
        }
    }
}

// MARK: - Knowledge Base Panel (D4 知识库)

struct SpaceKnowledgePanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var knowledgeStatus: SpaceKnowledgeStatus?
    @State private var searchQuery = ""
    @State private var searchResults: [[String: Any]] = []
    @State private var answerResult: [String: Any]?
    @State private var isSearching = false
    @State private var isUploading = false
    @State private var showUploadDialog = false
    @State private var uploadPath = ""
    private let spaceManager = CoworkSpaceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_kb_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let ks = knowledgeStatus, ks.isBound {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                }
                Button(action: { loadStatus() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if knowledgeStatus == nil {
                unboundView
            } else if let ks = knowledgeStatus, !ks.isBound {
                unboundView
            } else {
                boundView
            }
        }
        .onAppear { loadStatus() }
    }

    private var unboundView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.cw_kb_unbound))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.cw_kb_bindHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingL)
            Button(action: { bindKB() }) {
                Label(i18n.t(.cw_kb_bind), systemImage: "link")
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, theme.spacingXL)
    }

    private var boundView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if let ks = knowledgeStatus {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "doc.text")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.textTertiary)
                        Text(String(format: i18n.t(.cw_kb_statsFmt), ks.documentCount, ks.chunkCount))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Button(action: { unbindKB() }) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: theme.iconS))
                                .foregroundStyle(theme.accentDestructive)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, theme.spacingM)
                }

                Divider().padding(.horizontal, theme.spacingM)

                HStack(spacing: theme.spacingS) {
                    TextField(i18n.t(.cw_kb_searchPh), text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.captionSize))
                        .onSubmit { searchKB() }
                    Button(action: { searchKB() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: theme.iconS))
                    }
                    .buttonStyle(.plain)
                    .disabled(searchQuery.isEmpty || isSearching)
                }
                .padding(.horizontal, theme.spacingM)

                if isSearching {
                    ProgressView()
                        .padding(.horizontal, theme.spacingM)
                }

                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(i18n.t(.cw_kb_results))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingM)
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { idx, result in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result["title"] as? String ?? String(format: i18n.t(.cw_kb_docFmt), idx + 1))
                                    .font(.system(size: theme.captionSize, weight: .medium))
                                    .lineLimit(1)
                                Text(result["content"] as? String ?? "")
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.textTertiary)
                                    .lineLimit(3)
                            }
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingXS)
                        }
                    }
                }

                if let answer = answerResult {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(i18n.t(.cw_kb_ragAnswer))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingM)
                        Text(answer["answer"] as? String ?? "")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.text)
                            .padding(.horizontal, theme.spacingM)
                    }
                }

                Divider().padding(.horizontal, theme.spacingM)

                Button(action: { showUploadDialog = true }) {
                    Label(i18n.t(.cw_kb_upload), systemImage: "plus.circle")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingM)
            }
            .padding(.top, theme.spacingS)
        }
        .sheet(isPresented: $showUploadDialog) {
            uploadSheet
        }
    }

    private var uploadSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.cw_kb_uploadTitle))
                .font(.system(size: theme.bodySize, weight: .semibold))
            TextField(i18n.t(.cw_kb_pathPh), text: $uploadPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(i18n.t(.cancel)) { showUploadDialog = false }
                    .buttonStyle(.bordered)
                Button(i18n.t(.cw_kb_uploadBtn)) {
                    uploadDocument()
                    showUploadDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(uploadPath.isEmpty)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
    }

    private func loadStatus() {
        Task {
            await spaceManager.loadKnowledgeStatus(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = spaceManager.activeKnowledge }
        }
    }

    private func bindKB() {
        Task {
            await spaceManager.bindKnowledge(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = spaceManager.activeKnowledge }
        }
    }

    private func unbindKB() {
        Task {
            await spaceManager.unbindKnowledge(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = nil }
        }
    }

    private func searchKB() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchResults = []
        answerResult = nil
        Task {
            do {
                let results = try await spaceManager.searchKnowledge(spaceId: spaceId, query: searchQuery)
                let answer = try await spaceManager.queryKnowledge(spaceId: spaceId, question: searchQuery)
                await MainActor.run {
                    searchResults = results
                    answerResult = answer
                    isSearching = false
                }
            } catch {
                spaceLog.error("Knowledge search failed: \(error.localizedDescription)")
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func uploadDocument() {
        guard !uploadPath.isEmpty else { return }
        isUploading = true
        Task {
            do {
                _ = try await spaceManager.uploadKnowledge(spaceId: spaceId, filePath: uploadPath)
                await MainActor.run {
                    isUploading = false
                    uploadPath = ""
                    loadStatus()
                }
            } catch {
                spaceLog.error("Knowledge upload failed: \(error.localizedDescription)")
                await MainActor.run { isUploading = false }
            }
        }
    }
}

// MARK: - Workflow & Artifact Marketplace (D8)

struct SpaceMarketplaceView: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var selectedTab = 0
    @State private var workflows: [MarketplaceItem] = []
    @State private var artifacts: [MarketplaceItem] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_mkt_title))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(theme.spacingM)

            Picker(i18n.t(.cw_mkt_type), selection: $selectedTab) {
                Text(i18n.t(.cw_mkt_typeWorkflow)).tag(0)
                Text(i18n.t(.cw_mkt_typeArtifact)).tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacingM)

            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: theme.spacingS),
                    GridItem(.flexible(), spacing: theme.spacingS)
                ], spacing: theme.spacingS) {
                    ForEach(selectedTab == 0 ? workflows : artifacts) { item in
                        marketplaceCard(item)
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .frame(width: 560, height: 480)
        .onAppear { loadSampleData() }
    }

    private func marketplaceCard(_ item: MarketplaceItem) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: theme.iconM))
                    .foregroundStyle(theme.accent)
                Spacer()
                Text(i18n.t(item.category))
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(theme.accent.opacity(0.1))
                    .clipShape(Capsule())
                    .foregroundStyle(theme.accent)
            }
            Text(i18n.t(item.name))
                .font(.system(size: theme.captionSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(i18n.t(item.description))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
            HStack {
                Label("\(item.useCount)", systemImage: "arrow.down.doc")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                Button(i18n.t(.cw_mkt_install)) { }
                    .font(.system(size: 9, weight: .medium))
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(theme.surfaceSecondary)
        )
    }

    private func loadSampleData() {
        workflows = [
            MarketplaceItem(name: "spl_mkt_name_code_review", description: "spl_mkt_desc_code_review", icon: "arrow.triangle.branch", category: "spl_mkt_cat_dev", useCount: 128),
            MarketplaceItem(name: "spl_mkt_name_doc_gen", description: "spl_mkt_desc_doc_gen", icon: "doc.text", category: "spl_mkt_cat_doc", useCount: 95),
            MarketplaceItem(name: "spl_mkt_name_data_analysis", description: "spl_mkt_desc_data_analysis", icon: "chart.bar", category: "spl_mkt_cat_data", useCount: 73),
            MarketplaceItem(name: "spl_mkt_name_multi_translate", description: "spl_mkt_desc_multi_translate", icon: "globe", category: "spl_mkt_cat_translate", useCount: 61),
        ]
        artifacts = [
            MarketplaceItem(name: "spl_mkt_name_react_dashboard", description: "spl_mkt_desc_react_dashboard", icon: "shippingbox", category: "spl_mkt_cat_frontend", useCount: 256),
            MarketplaceItem(name: "spl_mkt_name_api_doc", description: "spl_mkt_desc_api_doc", icon: "doc.text", category: "spl_mkt_cat_doc", useCount: 189),
            MarketplaceItem(name: "spl_mkt_name_data_viz", description: "spl_mkt_desc_data_viz", icon: "chart.bar", category: "spl_mkt_cat_viz", useCount: 142),
            MarketplaceItem(name: "spl_mkt_name_cli_scaffold", description: "spl_mkt_desc_cli_scaffold", icon: "terminal", category: "spl_mkt_cat_tool", useCount: 98),
        ]
    }
}

private struct MarketplaceItem: Identifiable {
    let id = UUID().uuidString
    let name: String
    let description: String
    let icon: String
    let category: String
    let useCount: Int
}

typealias SpaceSnapshotView = SpaceSnapshotPanel
typealias SpaceArtifactView = SpaceArtifactPanel
typealias SpaceWorkflowView = SpaceWorkflowPanel
typealias SpaceDesktopView = SpaceDesktopPanel
typealias SpaceChatPlaceholder = SpaceSharedChat
