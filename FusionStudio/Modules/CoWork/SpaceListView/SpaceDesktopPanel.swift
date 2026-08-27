import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")


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

