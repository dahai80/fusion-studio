// Callers: ModelHubMainView contentArea switch on .permission.
// Affected API: ModelHubAPIClient listAPIKeys/createAPIKey/deactivateAPIKey/setModelModules/getAPIKeyUsage.
// Data schemas: HubAPIKey, HubAPIKeyListResponse, HubAPIKeyResponse, HubAPIKeyUsageResponse.
// PRD: Permission + role-based access table (admin/member/guest)
// User instruction: issue #63 sub-feature 2 (modules NLP/CV/Audio/Multimodal/Code/Science) + sub-feature 5 (QPS limit)

import SwiftUI
import os.log

private let permLog = Logger(subsystem: "com.fusion.studio", category: "HubPermission")

struct HubPermissionView: View {
    @ObservedObject var client: ModelHubAPIClient
    @Environment(\.studioTheme) private var theme

    @State private var apiKeys: [HubAPIKey] = []
    @State private var models: [HubModel] = []
    @State private var isLoading = false
    @State private var lastError: String?
    @State private var showCreateKey = false
    @State private var newKeyName = ""
    @State private var newKeyModels: [String] = []
    @State private var newKeyModules: [String] = []
    @State private var newKeyRateLimit = 0
    @State private var createdRawKey: String?
    @State private var selectedTab = 0
    @State private var keyUsages: [String: HubAPIKeyUsageResponse] = [:]

    private let moduleOptions = HubModelModule.allCases.map(\.rawValue)

    // Role-based access (PRD)
    private let roles: [RoleAccess] = [
        RoleAccess(role: "admin", label: "管理员", icon: "shield.fill", color: .red,
                   modules: ["chat", "code", "agent", "artifacts", "design", "rag", "sim", "bench"],
                   capabilities: "全部模型 + 全部模块 + 密钥管理 + 系统配置"),
        RoleAccess(role: "member", label: "成员", icon: "person.fill", color: .blue,
                   modules: ["chat", "code", "agent", "artifacts", "design", "rag"],
                   capabilities: "指定模型 + 常规模块 + 无系统配置"),
        RoleAccess(role: "guest", label: "访客", icon: "person.crop.circle", color: .gray,
                   modules: ["chat"],
                   capabilities: "受限模型 + 仅对话 + 速率限制"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabPicker
            Divider()
            if selectedTab == 0 {
                keyAndModelPanel
            } else {
                roleAccessPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAll() }
        .sheet(isPresented: $showCreateKey) { createKeySheet }
        .alert("API Key 已创建", isPresented: .constant(createdRawKey != nil)) {
            Button("复制并关闭") {
                if let key = createdRawKey {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(key, forType: .string)
                }
                createdRawKey = nil
            }
        } message: {
            if let key = createdRawKey {
                Text("请立即复制，此密钥仅显示一次：\n\(key)")
            } else {
                Text("")
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "key").font(.system(size: 14))
                    Text("API 密钥与模型权限")
                        .font(.system(size: theme.textSize, weight: selectedTab == 0 ? .semibold : .regular))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 0 ? theme.accent.opacity(0.1) : .clear)
                .foregroundStyle(selectedTab == 0 ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)

            Button(action: { selectedTab = 1 }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: "shield").font(.system(size: 14))
                    Text("角色权限表")
                        .font(.system(size: theme.textSize, weight: selectedTab == 1 ? .semibold : .regular))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == 1 ? theme.accent.opacity(0.1) : .clear)
                .foregroundStyle(selectedTab == 1 ? theme.accent : theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
    }

    // MARK: - Key & Model Panel

    private var keyAndModelPanel: some View {
        HStack(spacing: 0) {
            keyListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            modelPermPanel
        }
    }

    private var keyListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API 密钥")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("创建密钥") { showCreateKey = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(theme.spacingM)

            Divider()

            if apiKeys.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "key").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("暂无 API 密钥")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(apiKeys) { key in
                    APIKeyRow(key: key, usage: keyUsages[key.id]) { deactivateKey(key) }
                }
                .listStyle(.plain)
            }

            if let err = lastError {
                Text(err).font(.caption).foregroundStyle(.red).padding(4)
            }
        }
        .frame(minWidth: 350, maxWidth: 500)
    }

    private var modelPermPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("模型权限")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
            }
            .padding(theme.spacingM)

            Divider()

            if models.isEmpty {
                Text("加载中...").foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(models) { model in
                    ModelPermRow(model: model, allModules: moduleOptions) { modules in
                        setModules(modelId: model.id, modules: modules)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Role Access Panel (PRD)

    private var roleAccessPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                Text("角色权限表")
                    .font(.system(size: theme.largeTitleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Text("定义不同角色可访问的模块和操作权限")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)

                ForEach(roles) { role in
                    roleCard(role)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: theme.spacingS) {
                        Text("模块权限对照表")
                            .font(.system(size: theme.headlineSize, weight: .semibold))
                            .foregroundStyle(theme.text)

                        // Header row
                        HStack(spacing: 0) {
                            Text("模块").frame(width: 80, alignment: .leading)
                            ForEach(roles) { r in
                                Text(r.label).frame(maxWidth: .infinity)
                            }
                        }
                        .font(.caption).foregroundStyle(theme.textTertiary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        Divider()

                        ForEach(moduleOptions, id: \.self) { mod in
                            HStack(spacing: 0) {
                                Text(mod).frame(width: 80, alignment: .leading)
                                ForEach(roles) { r in
                                    Image(systemName: r.modules.contains(mod) ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(r.modules.contains(mod) ? .green : .red)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.text)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            Divider()
                        }
                    }
                    .padding(8)
                }
            }
            .padding(theme.spacingL)
        }
    }

    private func roleCard(_ role: RoleAccess) -> some View {
        GroupBox {
            HStack(spacing: theme.spacingM) {
                Image(systemName: role.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(role.color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(role.label)
                        .font(.system(size: theme.headlineSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(role.capabilities)
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(role.modules, id: \.self) { mod in
                                Text(mod)
                                    .font(.caption2)
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(role.color.opacity(0.1))
                                    .foregroundStyle(role.color)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(8)
        }
    }

    // MARK: - Create Key Sheet

    private var createKeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("创建 API 密钥").font(.title2).bold()

            TextField("密钥名称", text: $newKeyName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("允许模型（留空=全部）").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(models) { m in
                            let selected = newKeyModels.contains(m.id)
                            Button(m.displayTitle) {
                                if selected { newKeyModels.removeAll { $0 == m.id } }
                                else { newKeyModels.append(m.id) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selected ? .accentColor : nil)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("允许模块（留空=全部）").font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(HubModelModule.allCases) { mod in
                            let selected = newKeyModules.contains(mod.rawValue)
                            Button(action: {
                                if selected { newKeyModules.removeAll { $0 == mod.rawValue } }
                                else { newKeyModules.append(mod.rawValue) }
                            }) {
                                Label(mod.rawValue, systemImage: mod.icon)
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selected ? moduleColor(mod) : nil)
                        }
                    }
                }
            }

            HStack {
                Text("QPS 限制 (0=无限)").font(.caption)
                TextField("", value: $newKeyRateLimit, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack {
                Button("取消") { showCreateKey = false }.buttonStyle(.bordered)
                Button("创建") {
                    createKey()
                    showCreateKey = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newKeyName.isEmpty)
            }
        }
        .padding()
        .frame(width: 480)
    }

    // MARK: - Data

    private func loadAll() async {
        isLoading = true
        do {
            async let keysResp = client.listAPIKeys()
            async let modelsAsync = client.listModels()
            let keys = try await keysResp
            let mResp = try await modelsAsync
            apiKeys = keys.keys
            models = mResp.models
            for key in apiKeys where key.isActive == true {
                if let usage = try? await client.getAPIKeyUsage(keyId: key.id) {
                    keyUsages[key.id] = usage
                }
            }
        } catch {
            lastError = error.localizedDescription
            permLog.warning("Load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func createKey() {
        Task { @MainActor in
            do {
                let resp = try await client.createAPIKey(
                    name: newKeyName,
                    allowedModels: newKeyModels.isEmpty ? nil : newKeyModels,
                    allowedModules: newKeyModules.isEmpty ? nil : newKeyModules,
                    qpsLimit: newKeyRateLimit > 0 ? newKeyRateLimit : nil
                )
                createdRawKey = resp.rawKey
                newKeyName = ""
                newKeyModels = []
                newKeyModules = []
                newKeyRateLimit = 0
                await loadAll()
                permLog.info("API key created: \(resp.key.name ?? resp.key.id)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func moduleColor(_ mod: HubModelModule) -> Color {
        switch mod {
        case .nlp: return .blue
        case .cv: return .purple
        case .audio: return .green
        case .multimodal: return .orange
        case .code: return .cyan
        case .science: return .pink
        }
    }

    private func deactivateKey(_ key: HubAPIKey) {
        Task { @MainActor in
            do {
                _ = try await client.deactivateAPIKey(keyId: key.id)
                await loadAll()
                permLog.info("API key deactivated: \(key.id)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func setModules(modelId: String, modules: [String]) {
        Task { @MainActor in
            do {
                _ = try await client.setModelModules(modelId: modelId, modules: modules)
                permLog.info("Modules set for \(modelId): \(modules)")
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

private struct RoleAccess: Identifiable {
    let role: String
    let label: String
    let icon: String
    let color: Color
    let modules: [String]
    let capabilities: String
    var id: String { role }
}

private struct APIKeyRow: View {
    let key: HubAPIKey
    let usage: HubAPIKeyUsageResponse?
    let onDeactivate: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: key.isActive == true ? "key.fill" : "key")
                .foregroundStyle(key.isActive == true ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text(key.name ?? key.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 8) {
                    if let prefix = key.prefix { Text(prefix + "...").font(.caption).foregroundStyle(.secondary) }
                    if let qps = key.effectiveQPSLimit, qps > 0 { Text("\(qps) QPS").font(.caption).foregroundStyle(.secondary) }
                    if key.isActive == true { Text("活跃").font(.caption).foregroundStyle(.green) }
                }
                if let u = usage {
                    HStack(spacing: 8) {
                        if let current = u.currentQps { Text("QPS: \(String(format: "%.1f", current))").font(.caption2).foregroundStyle(.secondary) }
                        if let total = u.totalRequests { Text("请求: \(total)").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                if let mods = key.allowedModules, !mods.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(mods, id: \.self) { mod in
                                Text(mod).font(.system(size: 9))
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(moduleColorFor(mod).opacity(0.15))
                                    .foregroundStyle(moduleColorFor(mod))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            Spacer()
            if key.isActive == true {
                Button("停用") { onDeactivate() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    private func moduleColorFor(_ mod: String) -> Color {
        switch mod {
        case "NLP": return .blue
        case "CV": return .purple
        case "Audio": return .green
        case "Multimodal": return .orange
        case "Code": return .cyan
        case "Science": return .pink
        default: return .accentColor
        }
    }
}

private struct ModelPermRow: View {
    let model: HubModel
    let allModules: [String]
    let onSetModules: ([String]) -> Void
    @Environment(\.studioTheme) private var theme
    @State private var selectedModules: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.displayTitle)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(HubModelModule.allCases) { mod in
                        let sel = selectedModules.contains(mod.rawValue)
                        Button(action: {
                            if sel { selectedModules.remove(mod.rawValue) }
                            else { selectedModules.insert(mod.rawValue) }
                            onSetModules(Array(selectedModules))
                        }) {
                            Label(mod.rawValue, systemImage: mod.icon)
                                .font(.system(size: 10))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(sel ? moduleColor(mod) : nil)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            selectedModules = Set(model.allowedModules ?? [])
        }
    }

    private func moduleColor(_ mod: HubModelModule) -> Color {
        switch mod {
        case .nlp: return .blue
        case .cv: return .purple
        case .audio: return .green
        case .multimodal: return .orange
        case .code: return .cyan
        case .science: return .pink
        }
    }
}
