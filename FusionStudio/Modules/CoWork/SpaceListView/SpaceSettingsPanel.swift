import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

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

