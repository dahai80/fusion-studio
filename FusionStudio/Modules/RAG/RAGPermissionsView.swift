import SwiftUI
import os

private let permLog = Logger(subsystem: "com.fusion.studio", category: "RAGPermissions")

struct RAGPermissionsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @State private var apiKeys: [KBAPIKeyInfo] = []
    @State private var isLoading = false
    @State private var showCreateKey = false
    @State private var newKeyName = ""
    @State private var createdKey: String?
    @State private var showCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text("权限管控")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                authStatusCard
                apiKeyCard
                memberRoleCard
                auditNote
            }
            .padding(theme.spacingL)
        }
        .task { await loadKeys() }
        .sheet(isPresented: $showCreateKey) { createKeySheet }
    }

    private var authStatusCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("鉴权状态", systemImage: "lock.shield")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("API Key 认证").font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                    Text(apiKeys.isEmpty ? "未启用" : "已启用")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(apiKeys.isEmpty ? .orange : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: theme.spacingXS) {
                    Text("活跃密钥").font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                    Text("\(apiKeys.count)")
                        .font(.system(size: theme.titleSize, weight: .bold)).foregroundStyle(theme.accent)
                }
            }
        }
        .padding(theme.spacingM)
        .background(cardBg).overlay(cardStroke)
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Label("API 密钥管理", systemImage: "key")
                    .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button(action: { showCreateKey = true }) {
                    Label("创建密钥", systemImage: "plus").font(.system(size: theme.textSize))
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            if isLoading {
                ProgressView().padding(theme.spacingM)
            } else if apiKeys.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "key.slash").font(.system(size: 32)).foregroundStyle(theme.textTertiary)
                    Text("暂无 API 密钥").font(.system(size: theme.textSize)).foregroundStyle(theme.textTertiary)
                    Text("未设置 API Key 时，鉴权功能不启用")
                        .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, theme.spacingL)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: theme.spacingS) {
                        Text("名称").frame(maxWidth: .infinity, alignment: .leading)
                        Text("密钥哈希").frame(width: 150)
                        Text("创建时间").frame(width: 150)
                        Text("").frame(width: 80)
                    }
                    .font(.system(size: theme.captionSize, weight: .semibold)).foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingM).padding(.vertical, theme.spacingS)
                    Divider()
                    ForEach(apiKeys) { key in
                        keyRow(key)
                        if key.id != apiKeys.last?.id { Divider().padding(.leading, 44) }
                    }
                }
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func keyRow(_ key: KBAPIKeyInfo) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "key.fill").foregroundStyle(.orange).frame(width: 20)
            Text(key.name).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(key.id).font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.textSecondary).frame(width: 150)
            Text(formatDate(key.createdAt)).font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary).frame(width: 150)
            Button(action: { Task { await deleteKey(key) } }) {
                Image(systemName: "trash").font(.system(size: theme.captionSize)).foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain).frame(width: 80)
        }
        .padding(.horizontal, theme.spacingM).padding(.vertical, 8)
    }

    private var memberRoleCard: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Label("成员角色", systemImage: "person.2")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            VStack(spacing: theme.spacingS) {
                roleRow("管理员", desc: "全量读写、密钥管理、删除知识库", icon: "crown.fill", color: .orange)
                roleRow("编辑者", desc: "上传文档、修改配置、触发重建索引", icon: "pencil.circle.fill", color: .blue)
                roleRow("查询者", desc: "搜索、RAG 问答、只读访问", icon: "magnifyingglass", color: .green)
                roleRow("API 调用", desc: "仅通过 API Key 调用搜索/问答接口", icon: "link", color: .purple)
            }
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private func roleRow(_ name: String, desc: String, icon: String, color: Color) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: theme.textSize, weight: .medium)).foregroundStyle(theme.text)
                Text(desc).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(color.opacity(0.06)))
    }

    private var auditNote: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Label("审计日志", systemImage: "list.bullet.rectangle")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text("上游 API 暂未提供审计日志接口，需要提 Issue 追踪")
                    .font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
            }
            .padding(theme.spacingS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(Color.orange.opacity(0.08)))
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private var createKeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("创建 API 密钥").font(.headline)
            TextField("密钥名称", text: $newKeyName).textFieldStyle(.roundedBorder)
            if let key = createdKey {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text("密钥已创建（仅显示一次）")
                        .font(.system(size: theme.captionSize)).foregroundStyle(.orange)
                    HStack {
                        Text(key).font(.system(size: theme.captionSize, design: .monospaced))
                            .foregroundStyle(theme.text).textSelection(.enabled)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(key, forType: .string)
                            showCopied = true
                        }) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(theme.spacingS)
                    .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(theme.surfaceSecondary))
                }
            }
            HStack {
                Button("关闭") {
                    showCreateKey = false; newKeyName = ""; createdKey = nil; showCopied = false
                }
                Spacer()
                if createdKey == nil {
                    Button("创建") { Task { await createKey() } }
                        .disabled(newKeyName.isEmpty).buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20).frame(width: 400)
    }

    private var cardBg: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).fill(theme.surfacePrimary)
    }
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous).stroke(theme.separator, lineWidth: 1)
    }

    private func formatDate(_ ts: Double) -> String {
        guard ts > 0 else { return "-" }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: Date(timeIntervalSince1970: ts))
    }

    private func loadKeys() async {
        isLoading = true
        apiKeys = await client.listApiKeys()
        isLoading = false
        permLog.info("Loaded \(apiKeys.count) API keys")
    }

    private func createKey() async {
        guard let key = await client.createApiKey(name: newKeyName) else { return }
        createdKey = key
        await loadKeys()
        permLog.info("Created API key: \(newKeyName)")
    }

    private func deleteKey(_ key: KBAPIKeyInfo) async {
        let ok = await client.deleteApiKey(keyHash: key.id)
        if ok { await loadKeys() }
    }
}
