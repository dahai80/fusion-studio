// Callers: ContentView.workspaceToolbar embeds this view inline.
// Affected API: IPCClient.offlineCheck(), offlineSet(), AppState.isMLXRunning.
// Data schemas: system.offline_status {offline: Bool, reason: String?}, FUSION_CODE_OFFLINE env var.
// User instruction: #52 离线模式状态指示器 — Top bar online/offline icon, toggle switch, disabled tool grayed out

import SwiftUI
import os.log

private let offlineLog = Logger(subsystem: "com.fusion.studio", category: "OfflineModeIndicator")

struct OfflineModeIndicator: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var isOffline = false
    @State private var offlineReason: String?
    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: isOffline ? "wifi.slash" : "wifi")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isOffline ? theme.redDot : theme.greenDot)
                if isOffline {
                    Text(i18n.t(.ai_offline_badge))
                        .font(.system(size: theme.captionSize, weight: .medium))
                        .foregroundStyle(theme.redDot)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isOffline ? theme.redDot.opacity(0.1) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help(isOffline ? i18n.t(.ai_offline_helpOff) : i18n.t(.ai_offline_helpOn))
        .popover(isPresented: $showPopover) {
            offlinePopover
        }
        .onAppear { checkOfflineStatus() }
    }

    private var offlinePopover: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Label(i18n.t(.ai_offline_netStatus), systemImage: isOffline ? "wifi.slash" : "wifi")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            HStack {
                Text(isOffline ? i18n.t(.ai_offline_offMode) : i18n.t(.ai_offline_onMode))
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(isOffline ? theme.redDot : theme.greenDot)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { isOffline },
                    set: { toggleOffline($0) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.8)
            }
            if let reason = offlineReason {
                Text(String(format: i18n.t(.ai_offline_reasonFmt), reason))
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textSecondary)
            }
            if isOffline {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.ai_offline_disabledTitle))
                        .font(.system(size: theme.smallTextSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    disabledFeatureRow(i18n.t(.ai_offline_featInfer))
                    disabledFeatureRow(i18n.t(.ai_offline_featKb))
                    disabledFeatureRow(i18n.t(.ai_offline_featCode))
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 260)
    }

    private func disabledFeatureRow(_ name: String) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: "xmark.circle")
                .foregroundStyle(theme.textTertiary)
                .font(.system(size: 10))
            Text(name)
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textTertiary)
                .strikethrough()
        }
    }

    private func checkOfflineStatus() {
        Task {
            do {
                let result = try await ipc.offlineCheck()
                await MainActor.run {
                    isOffline = result["offline"] as? Bool ?? !appState.isMLXRunning
                    offlineReason = result["reason"] as? String
                    offlineLog.info("Offline status: \(self.isOffline)")
                }
            } catch {
                await MainActor.run {
                    isOffline = !appState.isMLXRunning
                    offlineLog.error("Offline check failed, using MLX status fallback")
                }
            }
        }
    }

    private func toggleOffline(_ enabled: Bool) {
        Task {
            do {
                _ = try await ipc.offlineSet(enabled: enabled)
                await MainActor.run {
                    isOffline = enabled
                    offlineReason = enabled ? i18n.t(.ai_offline_manual) : nil
                    offlineLog.info("Offline toggled: \(enabled)")
                }
            } catch {
                offlineLog.error("Offline toggle failed: \(error.localizedDescription)")
            }
        }
    }
}
