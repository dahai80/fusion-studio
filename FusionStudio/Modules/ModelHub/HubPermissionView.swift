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

    // Tenant & Role state
    @State private var tenants: [HubTenant] = []
    @State private var tenantRoles: [String: [HubRole]] = [:]
    @State private var selectedTenantId: String?
    @State private var showCreateTenant = false
    @State private var newTenantName = ""
    @State private var newTenantRole = ""
    @State private var showCreateRole = false
    @State private var newRoleName = ""
    @State private var newRolePermissions: [String] = []
    @State private var editingRole: HubRole?
    @State private var editRoleName = ""
    @State private var editRolePermissions: [String] = []

    // Approval state
    @State private var approvals: [HubApproval] = []
    @State private var approvalFilter = "pending"
    @State private var approvalComment = ""
    @State private var approvalActionId: String?

    private let moduleOptions = HubModelModule.allCases.map(\.rawValue)

    private let permissionOptions = [
        "models:list", "models:read", "models:write", "models:delete",
        "models:deploy", "models:serve",
        "downloads:create", "downloads:read",
        "quantize:create", "quantize:read",
        "benchmarks:trigger", "benchmarks:read",
        "cluster:read", "cluster:write",
        "auth:keys:list", "auth:keys:create", "auth:keys:delete",
        "tenants:read", "tenants:write",
        "roles:read", "roles:write",
        "approvals:submit", "approvals:review",
        "system:health", "system:audit",
    ]

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
            } else if selectedTab == 1 {
                tenantRolePanel
            } else {
                approvalPanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadAll() }
        .sheet(isPresented: $showCreateKey) { createKeySheet }
        .sheet(isPresented: $showCreateTenant) { createTenantSheet }
        .sheet(item: $editingRole) { role in
            editRoleSheet(role)
        }
        .sheet(isPresented: $showCreateRole) {
            createRoleSheet
        }
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
            tabButton(index: 0, icon: "key", title: "API 密钥与模型权限")
            tabButton(index: 1, icon: "building.2.crop.circle", title: "租户与角色")
            tabButton(index: 2, icon: "checkmark.shield", title: "审批工作流")
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func tabButton(index: Int, icon: String, title: String) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title)
                    .font(.system(size: theme.textSize, weight: selectedTab == index ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selectedTab == index ? theme.accent.opacity(0.1) : .clear)
            .foregroundStyle(selectedTab == index ? theme.accent : theme.textSecondary)
        }
        .buttonStyle(.plain)
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

    // MARK: - Tenant & Role Panel

    private var tenantRolePanel: some View {
        HStack(spacing: 0) {
            tenantListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            roleDetailPanel
        }
    }

    private var tenantListPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("租户")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("新建租户") { showCreateTenant = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(theme.spacingM)

            Divider()

            if tenants.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("暂无租户")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(tenants) { tenant in
                    TenantRow(
                        tenant: tenant,
                        isSelected: selectedTenantId == tenant.id,
                        roleCount: tenantRoles[tenant.id]?.count ?? 0
                    ) {
                        selectTenant(tenant)
                    } onDelete: {
                        deleteTenant(tenant)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 320, maxWidth: 450)
    }

    private var roleDetailPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(selectedTenantId != nil ? "角色列表" : "选择租户查看角色")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                if selectedTenantId != nil {
                    Button("新建角色") {
                        newRoleName = ""
                        newRolePermissions = []
                        showCreateRole = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(theme.spacingM)

            Divider()

            if let tid = selectedTenantId, let roles = tenantRoles[tid] {
                if roles.isEmpty {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "shield")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("暂无角色")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(roles) { role in
                        RoleRow(role: role) {
                            editingRole = role
                            editRoleName = role.name ?? ""
                            editRolePermissions = role.permissions ?? []
                        } onDelete: {
                            deleteRole(role)
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("请先选择左侧租户")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Approval Panel

    private var approvalPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("审批工作流")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                approvalFilterPicker
            }
            .padding(theme.spacingM)

            Divider()

            if approvals.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("暂无审批请求")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(approvals) { approval in
                    ApprovalRow(
                        approval: approval,
                        actionId: approvalActionId,
                        comment: $approvalComment
                    ) { comment in
                        approveApproval(approval, comment: comment)
                    } onReject: { comment in
                        rejectApproval(approval, comment: comment)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var approvalFilterPicker: some View {
        Picker("", selection: $approvalFilter) {
            Text("待审批").tag("pending")
            Text("已通过").tag("approved")
            Text("已拒绝").tag("rejected")
            Text("全部").tag("all")
        }
        .pickerStyle(.segmented)
        .frame(width: 320)
        .onChange(of: approvalFilter) { _ in
            Task { await loadApprovals() }
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

    // MARK: - Create Tenant Sheet

    private var createTenantSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("新建租户").font(.title2).bold()

            TextField("租户名称", text: $newTenantName)
                .textFieldStyle(.roundedBorder)

            Picker("默认角色", selection: $newTenantRole) {
                Text("无").tag("")
                ForEach(roles) { r in
                    Text(r.label).tag(r.role)
                }
            }

            HStack {
                Button("取消") { showCreateTenant = false }.buttonStyle(.bordered)
                Button("创建") {
                    createTenant()
                    showCreateTenant = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTenantName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Create Role Sheet

    private var createRoleSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("新建角色").font(.title2).bold()

            TextField("角色名称", text: $newRoleName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("权限选择").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 6) {
                        ForEach(permissionOptions, id: \.self) { perm in
                            let selected = newRolePermissions.contains(perm)
                            Button(action: {
                                if selected {
                                    newRolePermissions.removeAll { $0 == perm }
                                } else {
                                    newRolePermissions.append(perm)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 11))
                                    Text(perm).font(.system(size: 11))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selected ? theme.accent : theme.textSecondary)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Button("取消") { showCreateRole = false }.buttonStyle(.bordered)
                Button("创建") {
                    createRole()
                    showCreateRole = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newRoleName.isEmpty)
            }
        }
        .padding()
        .frame(width: 480)
    }

    // MARK: - Edit Role Sheet

    private func editRoleSheet(_ role: HubRole) -> some View {
        VStack(spacing: theme.spacingM) {
            Text("编辑角色").font(.title2).bold()

            TextField("角色名称", text: $editRoleName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("权限选择").font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 6) {
                        ForEach(permissionOptions, id: \.self) { perm in
                            let selected = editRolePermissions.contains(perm)
                            Button(action: {
                                if selected {
                                    editRolePermissions.removeAll { $0 == perm }
                                } else {
                                    editRolePermissions.append(perm)
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 11))
                                    Text(perm).font(.system(size: 11))
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selected ? theme.accent : theme.textSecondary)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            HStack {
                Button("取消") { editingRole = nil }.buttonStyle(.bordered)
                Button("保存") {
                    updateRole(role)
                    editingRole = nil
                }
                .buttonStyle(.borderedProminent)
                .disabled(editRoleName.isEmpty)
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
            async let tenantsAsync = client.listTenants()
            async let approvalsAsync = loadApprovalsInternal()

            let keys = try await keysResp
            let mResp = try await modelsAsync
            let tResp = try await tenantsAsync

            apiKeys = keys.keys
            models = mResp.models
            tenants = tResp.tenants

            for key in apiKeys where key.isActive == true {
                if let usage = try? await client.getAPIKeyUsage(keyId: key.id) {
                    keyUsages[key.id] = usage
                }
            }

            let approvalResult = await approvalsAsync
            approvals = approvalResult

            permLog.info("Permission data loaded: \(apiKeys.count) keys, \(models.count) models, \(tenants.count) tenants, \(approvals.count) approvals")
        } catch {
            lastError = error.localizedDescription
            permLog.warning("Load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadApprovalsInternal() async -> [HubApproval] {
        do {
            let statusParam = approvalFilter == "all" ? nil : approvalFilter
            let resp = try await client.listApprovals(status: statusParam)
            return resp.approvals
        } catch {
            permLog.warning("Load approvals failed: \(error.localizedDescription)")
            return []
        }
    }

    private func loadApprovals() async {
        let result = await loadApprovalsInternal()
        approvals = result
    }

    private func loadRolesForTenant(_ tenantId: String) async {
        do {
            let resp = try await client.listRoles(tenantId: tenantId)
            tenantRoles[tenantId] = resp.roles
            permLog.info("Loaded \(resp.roles.count) roles for tenant \(tenantId)")
        } catch {
            permLog.warning("Load roles failed for tenant \(tenantId): \(error.localizedDescription)")
            tenantRoles[tenantId] = []
        }
    }

    private func selectTenant(_ tenant: HubTenant) {
        selectedTenantId = tenant.id
        Task { await loadRolesForTenant(tenant.id) }
    }

    private func createTenant() {
        Task { @MainActor in
            do {
                let roleParam = newTenantRole.isEmpty ? nil : newTenantRole
                _ = try await client.createTenant(name: newTenantName, role: roleParam)
                newTenantName = ""
                newTenantRole = ""
                permLog.info("Tenant created: \(newTenantName)")
                let resp = try await client.listTenants()
                tenants = resp.tenants
            } catch {
                lastError = error.localizedDescription
                permLog.warning("Create tenant failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteTenant(_ tenant: HubTenant) {
        Task { @MainActor in
            do {
                _ = try await client.deleteTenant(id: tenant.id)
                permLog.info("Tenant deleted: \(tenant.id)")
                if selectedTenantId == tenant.id {
                    selectedTenantId = nil
                    tenantRoles.removeValue(forKey: tenant.id)
                }
                let resp = try await client.listTenants()
                tenants = resp.tenants
            } catch {
                lastError = error.localizedDescription
                permLog.warning("Delete tenant failed: \(error.localizedDescription)")
            }
        }
    }

    private func createRole() {
        guard let tid = selectedTenantId else { return }
        Task { @MainActor in
            do {
                let perms = newRolePermissions.isEmpty ? nil : newRolePermissions
                _ = try await client.createRole(tenantId: tid, name: newRoleName, permissions: perms)
                permLog.info("Role created: \(newRoleName) in tenant \(tid)")
                await loadRolesForTenant(tid)
            } catch {
                lastError = error.localizedDescription
                permLog.warning("Create role failed: \(error.localizedDescription)")
            }
        }
    }

    private func updateRole(_ role: HubRole) {
        guard let tid = role.tenantId ?? selectedTenantId else { return }
        Task { @MainActor in
            do {
                let perms = editRolePermissions.isEmpty ? nil : editRolePermissions
                _ = try await client.updateRole(tenantId: tid, roleId: role.id, name: editRoleName, permissions: perms)
                permLog.info("Role updated: \(role.id) in tenant \(tid)")
                await loadRolesForTenant(tid)
            } catch {
                lastError = error.localizedDescription
                permLog.warning("Update role failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteRole(_ role: HubRole) {
        guard let tid = role.tenantId ?? selectedTenantId else { return }
        Task { @MainActor in
            do {
                _ = try await client.deleteRole(tenantId: tid, roleId: role.id)
                permLog.info("Role deleted: \(role.id) in tenant \(tid)")
                await loadRolesForTenant(tid)
            } catch {
                lastError = error.localizedDescription
                permLog.warning("Delete role failed: \(error.localizedDescription)")
            }
        }
    }

    private func approveApproval(_ approval: HubApproval, comment: String?) {
        Task { @MainActor in
            do {
                approvalActionId = approval.id
                _ = try await client.approveRequest(id: approval.id, comment: comment)
                permLog.info("Approval approved: \(approval.id)")
                approvalActionId = nil
                approvalComment = ""
                await loadApprovals()
            } catch {
                lastError = error.localizedDescription
                approvalActionId = nil
                permLog.warning("Approve failed: \(error.localizedDescription)")
            }
        }
    }

    private func rejectApproval(_ approval: HubApproval, comment: String?) {
        Task { @MainActor in
            do {
                approvalActionId = approval.id
                _ = try await client.rejectRequest(id: approval.id, comment: comment)
                permLog.info("Approval rejected: \(approval.id)")
                approvalActionId = nil
                approvalComment = ""
                await loadApprovals()
            } catch {
                lastError = error.localizedDescription
                approvalActionId = nil
                permLog.warning("Reject failed: \(error.localizedDescription)")
            }
        }
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
                createdRawKey = resp.key
                if let rawKey = resp.key, !rawKey.isEmpty {
                    FusionConfig.shared.modelHubApiKey = rawKey
                    permLog.info("API key auto-stored for auth: \(resp.name ?? resp.id ?? "?")")
                }
                newKeyName = ""
                newKeyModels = []
                newKeyModules = []
                newKeyRateLimit = 0
                await loadAll()
                permLog.info("API key created: \(resp.name ?? resp.id ?? "?")")
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

// MARK: - Supporting Types

private struct RoleAccess: Identifiable {
    let role: String
    let label: String
    let icon: String
    let color: Color
    let modules: [String]
    let capabilities: String
    var id: String { role }
}

// MARK: - Sub-Views

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

private struct TenantRow: View {
    let tenant: HubTenant
    let isSelected: Bool
    let roleCount: Int
    let onSelect: () -> Void
    let onDelete: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "building.2.crop.circle")
                .foregroundStyle(isSelected ? theme.accent : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(tenant.name ?? tenant.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                HStack(spacing: 8) {
                    Label(tenant.roleLabel, systemImage: "shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(roleCount) 角色", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if tenant.isActive == true {
                        Text("活跃").font(.caption2).foregroundStyle(.green)
                    }
                }
                if let models = tenant.allowedModels, !models.isEmpty {
                    Text("模型: \(models.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? theme.accent.opacity(0.06) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

private struct RoleRow: View {
    let role: HubRole
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.studioTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: role.isDefault == true ? "star.fill" : "shield")
                    .foregroundStyle(role.isDefault == true ? .yellow : .blue)
                    .frame(width: 20)
                Text(role.name ?? role.id)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                if role.isDefault == true {
                    Text("默认").font(.caption2)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(.yellow.opacity(0.15))
                        .foregroundStyle(.yellow)
                        .clipShape(Capsule())
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            if let perms = role.permissions, !perms.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(perms, id: \.self) { perm in
                            Text(perm)
                                .font(.system(size: 9))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(theme.accent.opacity(0.1))
                                .foregroundStyle(theme.accent)
                                .clipShape(Capsule())
                        }
                    }
                }
            } else {
                Text("无权限配置")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }

            if let created = role.createdAt {
                Text("创建于 \(created)")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }
}

private struct ApprovalRow: View {
    let approval: HubApproval
    let actionId: String?
    @Binding var comment: String
    let onApprove: (String?) -> Void
    let onReject: (String?) -> Void
    @Environment(\.studioTheme) private var theme
    @State private var localComment = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: theme.spacingS) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(approval.modelName ?? approval.modelId ?? "未知模型")
                            .font(.system(size: theme.textSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        operationBadge
                    }
                    HStack(spacing: 12) {
                        if let requester = approval.requestedBy {
                            Label(requester, systemImage: "person")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let time = approval.createdAt {
                            Label(time, systemImage: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(approval.levelLabel)
                            .font(.caption2)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(levelColor.opacity(0.15))
                            .foregroundStyle(levelColor)
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                statusBadge
            }

            if approval.isPending && actionId == approval.id {
                VStack(spacing: theme.spacingXS) {
                    TextField("审批意见（可选）", text: $localComment)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.footnoteSize))
                    HStack(spacing: 8) {
                        Button("通过") {
                            onApprove(localComment.isEmpty ? nil : localComment)
                            localComment = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(.green)

                        Button("拒绝") {
                            onReject(localComment.isEmpty ? nil : localComment)
                            localComment = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                    }
                }
            } else if approval.isPending {
                HStack(spacing: 8) {
                    Button("审批") {
                        comment = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if let reviewer = approval.reviewedBy {
                Text("审批人: \(reviewer)\(approval.comment != nil ? " — \(approval.comment!)" : "")")
                    .font(.caption2)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    private var statusIcon: some View {
        Group {
            switch approval.status {
            case "approved":
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case "rejected":
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            default:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.system(size: 18))
        .frame(width: 24)
    }

    private var operationBadge: some View {
        Text(operationLabel)
            .font(.caption2)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(operationColor.opacity(0.15))
            .foregroundStyle(operationColor)
            .clipShape(Capsule())
    }

    private var operationLabel: String {
        switch approval.operation {
        case "deploy": return "部署"
        case "delete": return "删除"
        case "quantize": return "量化"
        case "export": return "导出"
        case "serve": return "上线"
        case "download": return "下载"
        default: return approval.operation ?? "操作"
        }
    }

    private var operationColor: Color {
        switch approval.operation {
        case "deploy", "serve": return .blue
        case "delete": return .red
        case "quantize": return .purple
        case "export", "download": return .green
        default: return .orange
        }
    }

    private var levelColor: Color {
        switch approval.level {
        case "L1": return .green
        case "L2": return .orange
        case "L3": return .red
        default: return .blue
        }
    }

    private var statusBadge: some View {
        Group {
            switch approval.status {
            case "approved":
                Text("已通过")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            case "rejected":
                Text("已拒绝")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            default:
                Text("待审批")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
    }
}
