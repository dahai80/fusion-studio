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

