// Callers: AIAgentObserverView permissions tab embeds this view.
// Affected API: IPCClient.permissionList(), permissionUpdate().
// Data schemas: {permissions: [{tool, level}], denied_tools: [String]}, FUSION.rules frontmatter, SENSITIVE_PATTERNS.
// User instruction: #47 终端命令权限标签可视化 — Tool permission labels (✅/⏳/🚫), FUSION.rules denied_tools editor, sensitive file highlighting

import SwiftUI
import os.log

private let permLog = Logger(subsystem: "com.fusion.studio", category: "PermissionTags")

struct PermissionTagView: View {
    @EnvironmentObject var ipc: IPCClient
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) private var theme

    @State private var permissions: [[String: Any]] = []
    @State private var isLoading = false
    @State private var editingTool: String?
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
            Label("权限标签", systemImage: "lock.shield")
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
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text("工具权限")
                .font(.system(size: theme.smallTextSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            if permissions.isEmpty {
                Text("暂无权限数据")
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
        let tool = perm["tool"] as? String ?? perm["name"] as? String ?? "unknown"
        let level = perm["level"] as? String ?? perm["status"] as? String ?? "allowed"
        let (icon, color, label) = permissionVisual(level)
        return HStack(spacing: theme.spacingS) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: theme.iconS))
            Text(tool)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            Spacer()
            Text(label)
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.12))
                .cornerRadius(4)
            Menu {
                Button("✅ 允许") { updatePermission(tool: tool, level: "allowed") }
                Button("⏳ 需确认") { updatePermission(tool: tool, level: "confirm") }
                Button("🚫 禁止") { updatePermission(tool: tool, level: "denied") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, theme.spacingS)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceElevated)
        .cornerRadius(theme.cornerRadiusSmall)
    }

    private func permissionVisual(_ level: String) -> (String, Color, String) {
        switch level {
        case "allowed", "granted":
            return ("checkmark.circle.fill", theme.greenDot, "✅ 允许")
        case "confirm", "pending", "ask":
            return ("hourglass.circle.fill", theme.amberDot, "⏳ 需确认")
        case "denied", "blocked":
            return ("xmark.circle.fill", theme.redDot, "🚫 禁止")
        default:
            return ("questionmark.circle", theme.textTertiary, level)
        }
    }

    private var deniedToolsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            HStack {
                Text("FUSION.rules 禁用工具")
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
                    TextField("工具名", text: $newDeniedTool)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.smallTextSize))
                    Button("添加") {
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
            Text("敏感文件模式")
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
                    Text("敏感")
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

    private func updatePermission(tool: String, level: String) {
        Task {
            do {
                _ = try await ipc.permissionUpdate(agentId: "", tool: tool, level: level)
                permLog.info("Permission updated: \(tool) → \(level)")
                loadPermissions()
            } catch {
                permLog.error("Permission update failed: \(error.localizedDescription)")
            }
        }
    }

    private func removeDeniedTool(_ tool: String) {
        deniedTools.removeAll { $0 == tool }
        permLog.info("Removed denied tool: \(tool)")
    }
}
