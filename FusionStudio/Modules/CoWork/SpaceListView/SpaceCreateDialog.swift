import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

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

