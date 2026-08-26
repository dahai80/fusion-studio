// Callers: AIAgentObserverView permissions tab embeds this view.
// Affected API: IPCClient.permissionList(), permissionUpdate().
// Data schemas: permission.list 无 agent_id → {permissions: [{readKnowledge,writeKnowledge,deleteKnowledge,executeCode,accessNetwork,agent_id}], denied_tools: []}；带 agent_id → {permissions: {5 能力开关}, denied_tools: [String], tools: [String]}.
// User instruction: #47 终端命令权限标签可视化 — Tool permission labels (✅/⏳/🚫), FUSION.rules denied_tools editor, sensitive file highlighting

import SwiftUI
import os.log

private let permLog = Logger(subsystem: "com.fusion.studio", category: "PermissionTags")

private struct CapabilityDef {
    let key: String
    let label: String
    let icon: String
}

private let CAPABILITIES: [CapabilityDef] = [
    .init(key: "readKnowledge", label: "ai_perm_capRead", icon: "books.vertical"),
    .init(key: "writeKnowledge", label: "ai_perm_capWrite", icon: "square.and.pencil"),
    .init(key: "deleteKnowledge", label: "ai_perm_capDelete", icon: "trash"),
    .init(key: "executeCode", label: "ai_perm_capCode", icon: "terminal"),
    .init(key: "accessNetwork", label: "ai_perm_capNet", icon: "network"),
]

struct PermissionTagView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    @State private var permissions: [[String: Any]] = []
    @State private var isLoading = false
    @State private var deniedTools: [String] = []
    @State private var showAddDenied = false
    @State private var newDeniedTool = ""

    private let sensitivePatterns = [
        ".env", ".pem", ".key", ".secret", "credentials",
        "id_rsa", "id_ed25519", ".ssh/", "token",
        "password", "private_key", "aws_access_key",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            headerBar
            if isLoading {
                ProgressView().padding()
            } else {
                permissionList
                deniedToolsSection
                sensitiveFilesSection
            }
        }
        .padding(theme.spacingL)
        .onAppear { loadPermissions() }
    }

    private var headerBar: some View {
        HStack {
            Label(i18n.t(.ai_perm_title), systemImage: "lock.shield")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: loadPermissions) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var permissionList: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.ai_perm_capsTitle))
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            if permissions.isEmpty {
                Text(i18n.t(.ai_perm_empty))
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(permissions.enumerated()), id: \.offset) { idx, perm in
                    permissionRow(perm)
                }
            }
        }
    }

    private func permissionRow(_ perm: [String: Any]) -> some View {
        let agentId = perm["agent_id"] as? String ?? ""
        let agentName = bridge.agentState.agents.first { $0.id == agentId }?.name ?? String(format: I18nManager.shared.t(.ai_perm_agentFmt), String(agentId.prefix(8)))
        return VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.accent)
                Text(agentName)
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.text)
            }
            FlowLayout(spacing: theme.spacingXS) {
                ForEach(CAPABILITIES, id: \.key) { cap in
                    capabilityTag(cap, granted: perm[cap.key] as? Bool ?? false)
                }
            }
        }
        .padding(theme.spacingS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private func capabilityTag(_ cap: CapabilityDef, granted: Bool) -> some View {
        let color = granted ? theme.greenDot : theme.textTertiary
        return HStack(spacing: 4) {
            Image(systemName: cap.icon)
                .font(.system(size: 10))
            Text(I18nManager.shared.t(cap.label))
                .font(.system(size: theme.captionSize))
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(color)
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }

    private var deniedToolsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text(i18n.t(.ai_perm_deniedTitle))
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showAddDenied = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(deniedTools.enumerated()), id: \.offset) { idx, tool in
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.redDot)
                        .font(.system(size: 12))
                    Text(tool)
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Button(action: { removeDeniedTool(tool) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.accentDestructive)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(theme.accentDestructive.opacity(0.06))
                .cornerRadius(theme.cornerRadiusSmall)
            }
            if showAddDenied {
                HStack {
                    TextField(i18n.t(.ai_perm_toolPh), text: $newDeniedTool)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.smallTextSize))
                    Button(i18n.t(.add)) {
                        if !newDeniedTool.isEmpty {
                            deniedTools.append(newDeniedTool)
                            newDeniedTool = ""
                            showAddDenied = false
                            permLog.info("Added denied tool: \(newDeniedTool)")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: theme.smallTextSize))
                    .foregroundStyle(theme.accent)
                }
            }
        }
    }

    private var sensitiveFilesSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.ai_perm_sensitiveTitle))
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            ForEach(Array(sensitivePatterns.enumerated()), id: \.offset) { idx, pattern in
                HStack {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundStyle(theme.amberDot)
                        .font(.system(size: 12))
                    Text(pattern)
                        .font(.system(size: theme.smallTextSize))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text(i18n.t(.ai_perm_sensitiveTag))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.amberDot)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.amberDot.opacity(0.12))
                        .cornerRadius(4)
                }
                .padding(.horizontal, theme.spacingS)
                .padding(.vertical, 4)
                .background(theme.amberDot.opacity(0.04))
                .cornerRadius(theme.cornerRadiusSmall)
            }
        }
    }

    private func loadPermissions() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.permissionList()
                await MainActor.run {
                    permissions = result["permissions"] as? [[String: Any]] ?? []
                    deniedTools = result["denied_tools"] as? [String] ?? []
                    isLoading = false
                    permLog.info("Permissions loaded: \(self.permissions.count) tools, \(self.deniedTools.count) denied")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    permLog.error("Permission load failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func removeDeniedTool(_ tool: String) {
        deniedTools.removeAll { $0 == tool }
        permLog.info("Removed denied tool: \(tool)")
    }
}
