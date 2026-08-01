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
                    Text("离线")
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
        .help(isOffline ? "离线模式 — 点击查看详情" : "在线模式")
        .popover(isPresented: $showPopover) {
            offlinePopover
        }
        .onAppear { checkOfflineStatus() }
    }

    private var offlinePopover: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Label("网络状态", systemImage: isOffline ? "wifi.slash" : "wifi")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            HStack {
                Text(isOffline ? "离线模式" : "在线模式")
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
                Text("原因: \(reason)")
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textSecondary)
            }
            if isOffline {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("离线模式下不可用的功能:")
                        .font(.system(size: theme.smallTextSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                    disabledFeatureRow("模型推理")
                    disabledFeatureRow("知识库查询")
                    disabledFeatureRow("代码生成")
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
                    offlineReason = enabled ? "用户手动切换" : nil
                    offlineLog.info("Offline toggled: \(enabled)")
                }
            } catch {
                offlineLog.error("Offline toggle failed: \(error.localizedDescription)")
            }
        }
    }
}
