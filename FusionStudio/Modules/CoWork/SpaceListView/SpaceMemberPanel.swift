import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

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
