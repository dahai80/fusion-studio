import SwiftUI
import os

private let permLog = Logger(subsystem: "com.fusion.studio", category: "RAGPermissions")

struct RAGPermissionsView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var client = RAGAPIClient.shared
    @StateObject private var i18n = I18nManager.shared
    @State private var apiKeys: [KBAPIKeyInfo] = []
    @State private var isLoading = false
    @State private var showCreateKey = false
    @State private var newKeyName = ""
    @State private var createdKey: String?
    @State private var showCopied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text(i18n.t(.rag_perm_title))
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
            Label(i18n.t(.rag_perm_authStatus), systemImage: "lock.shield")
                .font(.system(size: theme.textSize, weight: .semibold))
                .foregroundStyle(theme.text)
            HStack(spacing: theme.spacingM) {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_perm_apiKeyAuth)).font(.system(size: theme.textSize)).foregroundStyle(theme.text)
                    Text(apiKeys.isEmpty ? i18n.t(.rag_perm_disabled) : i18n.t(.rag_perm_enabled))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(apiKeys.isEmpty ? .orange : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_perm_activeKeys)).font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
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
                Label(i18n.t(.rag_perm_keyMgmt), systemImage: "key")
                    .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Button(action: { showCreateKey = true }) {
                    Label(i18n.t(.rag_perm_createKey), systemImage: "plus").font(.system(size: theme.textSize))
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            if isLoading {
                ProgressView().padding(theme.spacingM)
            } else if apiKeys.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "key.slash").font(.system(size: 32)).foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.rag_perm_noKey)).font(.system(size: theme.textSize)).foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.rag_perm_noKeyHint))
                        .font(.system(size: theme.captionSize)).foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, theme.spacingL)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: theme.spacingS) {
                        Text(i18n.t(.rag_perm_h_name)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(i18n.t(.rag_perm_h_hash)).frame(width: 150)
                        Text(i18n.t(.rag_perm_h_createdAt)).frame(width: 150)
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
            Label(i18n.t(.rag_perm_memberRole), systemImage: "person.2")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            VStack(spacing: theme.spacingS) {
                roleRow(i18n.t(.rag_perm_role_admin), desc: i18n.t(.rag_perm_role_admin_desc), icon: "crown.fill", color: .orange)
                roleRow(i18n.t(.rag_perm_role_edit), desc: i18n.t(.rag_perm_role_edit_desc), icon: "pencil.circle.fill", color: .blue)
                roleRow(i18n.t(.rag_perm_role_query), desc: i18n.t(.rag_perm_role_query_desc), icon: "magnifyingglass", color: .green)
                roleRow(i18n.t(.rag_perm_role_api), desc: i18n.t(.rag_perm_role_api_desc), icon: "link", color: .purple)
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
            Label(i18n.t(.rag_perm_audit), systemImage: "list.bullet.rectangle")
                .font(.system(size: theme.textSize, weight: .semibold)).foregroundStyle(theme.text)
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(i18n.t(.rag_perm_auditNote))
                    .font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
            }
            .padding(theme.spacingS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous).fill(Color.orange.opacity(0.08)))
        }
        .padding(theme.spacingM).background(cardBg).overlay(cardStroke)
    }

    private var createKeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.rag_perm_createTitle)).font(.headline)
            TextField(i18n.t(.rag_perm_keyNamePh), text: $newKeyName).textFieldStyle(.roundedBorder)
            if let key = createdKey {
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(i18n.t(.rag_perm_keyCreated))
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
                Button(i18n.t(.close)) {
                    showCreateKey = false; newKeyName = ""; createdKey = nil; showCopied = false
                }
                Spacer()
                if createdKey == nil {
                    Button(i18n.t(.rag_perm_createBtn)) { Task { await createKey() } }
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
