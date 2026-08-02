// Callers: ModelHubMainView contentArea switch on .permission.
// Affected API: ModelHubAPIClient listAPIKeys/createAPIKey/deactivateAPIKey/setModelModules.
// Data schemas: HubAPIKey, HubAPIKeyListResponse, HubAPIKeyResponse.
// User instruction: "按照prd文档和fusion-model-hub配合打造有竞争力的领先的产品"

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

    private let moduleOptions = ["chat", "code", "agent", "artifacts", "design", "rag", "sim", "bench"]

    var body: some View {
        HStack(spacing: 0) {
            keyListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            modelPermPanel
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
                    APIKeyRow(key: key) {
                        deactivateKey(key)
                    }
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
                        ForEach(moduleOptions, id: \.self) { mod in
                            let selected = newKeyModules.contains(mod)
                            Button(mod) {
                                if selected { newKeyModules.removeAll { $0 == mod } }
                                else { newKeyModules.append(mod) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(selected ? .accentColor : nil)
                        }
                    }
                }
            }

            HStack {
                Text("频率限制 (QPM, 0=无限)").font(.caption)
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

    private func loadAll() async {
        isLoading = true
        do {
            async let keysResp = client.listAPIKeys()
            async let modelsResp = client.listModels()
            let keys = try await keysResp
            let models = try await modelsResp
            apiKeys = keys.keys
            models = models.models
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
                    rateLimit: newKeyRateLimit > 0 ? newKeyRateLimit : nil
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

private struct APIKeyRow: View {
    let key: HubAPIKey
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
                    if let qpm = key.rateLimitQpm, qpm > 0 { Text("\(qpm) QPM").font(.caption).foregroundStyle(.secondary) }
                    if key.isActive == true { Text("活跃").font(.caption).foregroundStyle(.green) }
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
                    ForEach(allModules, id: \.self) { mod in
                        let sel = selectedModules.contains(mod)
                        Button(mod) {
                            if sel { selectedModules.remove(mod) }
                            else { selectedModules.insert(mod) }
                            onSetModules(Array(selectedModules))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(sel ? .accentColor : nil)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            selectedModules = Set(model.allowedModules ?? [])
        }
    }
}
