import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

struct SpaceListView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var spaces: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateDialog = false
    @State private var selectedSpaceId: String?

    var body: some View {
        HStack(spacing: 0) {
            spaceListPanel
            Rectangle().fill(theme.separator).frame(width: 1)
            if let sid = selectedSpaceId {
                SpaceMainView(spaceId: sid)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSpaces() }
    }

    private var spaceListPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "CoWork", subtitle: "协作空间 — 团队对话、共享 Agent、工作流协同")
                .padding(.bottom, theme.spacingS)

            HStack {
                Button(action: { showCreateDialog = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: theme.iconM))
                }
                .buttonStyle(.plain)
                .help("新建协作空间")
                Spacer()
                Button(action: { loadSpaces() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(.red)
                    .padding(.horizontal, theme.spacingM)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(spaces.indices, id: \.self) { idx in
                            spaceCard(spaces[idx], index: idx)
                        }
                    }
                    .padding(.horizontal, theme.spacingS)
                }
            }
        }
        .frame(minWidth: 280, maxWidth: 340)
        .sheet(isPresented: $showCreateDialog) {
            SpaceCreateDialog(onCreated: { _ in loadSpaces() })
        }
    }

    private func spaceCard(_ s: [String: Any], index: Int) -> some View {
        let sid = s["space_id"] as? String ?? s["id"] as? String ?? ""
        let name = s["name"] as? String ?? "Untitled Space"
        let desc = s["description"] as? String ?? ""
        let isActive = selectedSpaceId == sid
        return HStack(spacing: theme.spacingS) {
            Image(systemName: "person.2.square.stack")
                .font(.system(size: theme.iconM))
                .foregroundStyle(isActive ? theme.accent : theme.textTertiary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(isActive ? theme.accent : theme.text)
                    .lineLimit(1)
                if !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }
            Spacer()
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(isActive ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(isActive ? theme.accent.opacity(0.3) : theme.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedSpaceId = sid }
    }

    private var emptyStateView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "person.2.square.stack")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("选择一个协作空间")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadSpaces() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let result = try await ipc.spaceCall(method: "desk.space.list", params: [:])
                spaceLog.info("space.list loaded: \(result.count) keys")
                if let items = result["items"] as? [[String: Any]] {
                    await MainActor.run { spaces = items; isLoading = false }
                } else if let single = result["spaces"] as? [[String: Any]] {
                    await MainActor.run { spaces = single; isLoading = false }
                } else {
                    await MainActor.run { spaces = []; isLoading = false }
                }
            } catch {
                spaceLog.error("space.list failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct SpaceCreateDialog: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var collabMode = "open"
    @State private var isCreating = false

    let onCreated: ([String: Any]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            Text("新建协作空间")
                .font(.system(size: theme.headlineSize, weight: .bold))

            TextField("空间名称", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("描述（可选）", text: $description)
                .textFieldStyle(.roundedBorder)

            Picker("协作模式", selection: $collabMode) {
                Text("开放").tag("open")
                Text("邀请").tag("invite")
                Text("私有").tag("private")
            }

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("创建") { createSpace() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isCreating)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createSpace() {
        isCreating = true
        Task {
            do {
                var params: [String: Any] = [
                    "name": name,
                    "owner_id": "local_user",
                    "collab_mode": collabMode,
                ]
                if !description.isEmpty { params["description"] = description }
                let result = try await ipc.spaceCall(method: "desk.space.create", params: params)
                spaceLog.info("space.created: \(result)")
                await MainActor.run { onCreated(result); dismiss() }
            } catch {
                spaceLog.error("space.create failed: \(error.localizedDescription)")
                await MainActor.run { isCreating = false }
            }
        }
    }
}

struct SpaceMainView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let spaceId: String
    @State private var space: [String: Any]?
    @State private var isLoading = false
    @State private var activeTab = SpaceTab.members

    private enum SpaceTab: Int, CaseIterable {
        case members = 0
        case chat = 1
        case agents = 2
        case snapshots = 3
        case artifacts = 4
        case workflow = 5
        case desktop = 6

        var item: FusionTabItem {
            switch self {
            case .members:   return FusionTabItem(title: "成员", icon: "person.2")
            case .chat:      return FusionTabItem(title: "对话", icon: "bubble.left.and.bubble.right")
            case .agents:    return FusionTabItem(title: "Agent", icon: "brain.head.profile")
            case .snapshots: return FusionTabItem(title: "快照", icon: "camera.on.rectangle")
            case .artifacts: return FusionTabItem(title: "产物", icon: "shippingbox")
            case .workflow:  return FusionTabItem(title: "工作流", icon: "arrow.triangle.branch")
            case .desktop:   return FusionTabItem(title: "桌面", icon: "desktopcomputer")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let s = space {
                spaceHeader(s)
                FusionTabBar(
                    selected: Binding(
                        get: { activeTab.rawValue },
                        set: { if let t = SpaceTab(rawValue: $0) { activeTab = t } }
                    ),
                    tabs: SpaceTab.allCases.map { $0.item }
                )
                .padding(.horizontal, theme.spacingM)
                switch activeTab {
                case .members:
                    SpaceMemberView(spaceId: spaceId)
                case .chat:
                    SpaceChatPlaceholder(spaceId: spaceId)
                case .agents:
                    SpaceAgentView(spaceId: spaceId)
                case .snapshots:
                    SpaceSnapshotView(spaceId: spaceId)
                case .artifacts:
                    SpaceArtifactView(spaceId: spaceId)
                case .workflow:
                    SpaceWorkflowView(spaceId: spaceId)
                case .desktop:
                    SpaceDesktopView(spaceId: spaceId)
                }
            } else {
                Text("加载中…")
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadSpace() }
    }

    private func spaceHeader(_ s: [String: Any]) -> some View {
        HStack(spacing: theme.spacingM) {
            Image(systemName: "person.2.square.stack")
                .font(.system(size: theme.iconL))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(s["name"] as? String ?? "Untitled")
                    .font(.system(size: theme.headlineSize, weight: .bold))
                    .foregroundStyle(theme.text)
                if let desc = s["description"] as? String, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
    }

    private func loadSpace() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceCall(method: "desk.space.get", params: ["space_id": spaceId])
                spaceLog.info("space.get loaded: \(spaceId)")
                await MainActor.run { space = result; isLoading = false }
            } catch {
                spaceLog.error("space.get failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct SpaceMemberView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    let spaceId: String
    @State private var members: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("空间成员")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { loadMembers() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)

            if isLoading {
                ProgressView().padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(members.indices, id: \.self) { idx in
                            memberRow(members[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadMembers() }
    }

    private func memberRow(_ m: [String: Any]) -> some View {
        let name = m["display_name"] as? String ?? m["user_id"] as? String ?? "?"
        let role = m["role"] as? String ?? "member"
        return HStack(spacing: theme.spacingS) {
            Image(systemName: "person.circle")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                Text(role)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
    }

    private func loadMembers() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceCall(method: "desk.space.member.list", params: ["space_id": spaceId])
                if let items = result["members"] as? [[String: Any]] {
                    await MainActor.run { members = items; isLoading = false }
                } else {
                    await MainActor.run { members = []; isLoading = false }
                }
            } catch {
                spaceLog.error("member.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct SpaceAgentView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let spaceId: String
    @State private var agents: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("共享 Agent")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { loadAgents() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)
            if isLoading {
                ProgressView().padding()
            } else if agents.isEmpty {
                emptyAgentView
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(agents.indices, id: \.self) { idx in
                            agentRow(agents[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadAgents() }
    }

    private var emptyAgentView: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text("暂无共享 Agent")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func agentRow(_ a: [String: Any]) -> some View {
        let name = a["agent_name"] as? String ?? a["name"] as? String ?? "?"
        let perm = a["permission"] as? String ?? "all_member"
        return HStack(spacing: theme.spacingS) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                Text(perm)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
    }

    private func loadAgents() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.spaceCall(method: "desk.space.agent.list", params: ["space_id": spaceId])
                let items = r["agents"] as? [[String: Any]] ?? []
                await MainActor.run { agents = items; isLoading = false }
            } catch {
                spaceLog.error("agent.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct SpaceSnapshotView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let spaceId: String
    @State private var snapshots: [[String: Any]] = []
    @State private var isLoading = false
    @State private var showCreate = false
    @State private var snapName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("空间快照")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
                Button(action: { loadSnapshots() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)
            if isLoading {
                ProgressView().padding()
            } else if snapshots.isEmpty {
                emptySnapView
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(snapshots.indices, id: \.self) { idx in
                            snapRow(snapshots[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadSnapshots() }
        .alert("创建快照", isPresented: $showCreate) {
            TextField("名称", text: $snapName)
            Button("创建") { createSnapshot() }
            Button("取消", role: .cancel) { }
        }
    }

    private var emptySnapView: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "camera.on.rectangle")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text("暂无快照")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func snapRow(_ s: [String: Any]) -> some View {
        let name = s["name"] as? String ?? "unnamed"
        let ts = s["created_at"] as? String ?? ""
        return HStack(spacing: theme.spacingS) {
            Image(systemName: "camera")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                Text(ts)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
    }

    private func loadSnapshots() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.spaceCall(method: "desk.space.snapshot.list", params: ["space_id": spaceId])
                let items = r["snapshots"] as? [[String: Any]] ?? []
                await MainActor.run { snapshots = items; isLoading = false }
            } catch {
                spaceLog.error("snapshot.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func createSnapshot() {
        Task {
            do {
                _ = try await ipc.spaceCall(method: "desk.space.snapshot.create", params: [
                    "space_id": spaceId, "name": snapName.isEmpty ? "snapshot" : snapName
                ])
                snapName = ""
                loadSnapshots()
            } catch {
                spaceLog.error("snapshot.create failed: \(error.localizedDescription)")
            }
        }
    }
}

struct SpaceArtifactView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let spaceId: String
    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("空间产物")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { loadArtifacts() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)
            if isLoading {
                ProgressView().padding()
            } else if artifacts.isEmpty {
                emptyArtView
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(artifacts.indices, id: \.self) { idx in
                            artRow(artifacts[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadArtifacts() }
    }

    private var emptyArtView: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "shippingbox")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text("暂无产物")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func artRow(_ a: [String: Any]) -> some View {
        let name = a["name"] as? String ?? "?"
        let type = a["type"] as? String ?? "unknown"
        return HStack(spacing: theme.spacingS) {
            Image(systemName: artifactIcon(type))
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                Text(type)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "shippingbox"
        }
    }

    private func loadArtifacts() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.spaceCall(method: "desk.space.artifact.list", params: ["space_id": spaceId])
                let items = r["artifacts"] as? [[String: Any]] ?? []
                await MainActor.run { artifacts = items; isLoading = false }
            } catch {
                spaceLog.error("artifact.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct SpaceChatPlaceholder: View {
    @Environment(\.studioTheme) private var theme
    let spaceId: String

    var body: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text("空间对话")
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SpaceWorkflowView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let spaceId: String
    @State private var workflows: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("工作流协作")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Button(action: { loadWorkflows() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)
            if isLoading {
                ProgressView().padding()
            } else if workflows.isEmpty {
                emptyWorkflowView
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(workflows.indices, id: \.self) { idx in
                            workflowRow(workflows[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .onAppear { loadWorkflows() }
    }

    private var emptyWorkflowView: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text("暂无工作流")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func workflowRow(_ w: [String: Any]) -> some View {
        let name = w["name"] as? String ?? "unnamed"
        let status = w["status"] as? String ?? "idle"
        return HStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: theme.iconM))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                Text(status)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, 6)
    }

    private func loadWorkflows() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.spaceCall(method: "desk.space.workflow.list", params: ["space_id": spaceId])
                let items = r["workflows"] as? [[String: Any]] ?? []
                await MainActor.run { workflows = items; isLoading = false }
            } catch {
                spaceLog.error("workflow.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct SpaceDesktopView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    let spaceId: String
    @State private var isSharing = false
    @State private var role = "observer"
    @State private var auditLog: [[String: Any]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("桌面共享")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                Spacer()
                Picker("角色", selection: $role) {
                    Text("观察者").tag("observer")
                    Text("控制者").tag("controller")
                    Text("审批者").tag("approver")
                }
                .frame(width: 120)
                Button(action: { toggleShare() }) {
                    Image(systemName: isSharing ? "stop.fill" : "play.fill")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.top, theme.spacingM)

            if isSharing {
                sharedDesktopView
            } else {
                idleDesktopView
            }
        }
    }

    private var idleDesktopView: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 24))
                .foregroundStyle(theme.textTertiary)
            Text("桌面共享未开启")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sharedDesktopView: some View {
        VStack(spacing: theme.spacingS) {
            RoundedRectangle(cornerRadius: theme.cornerRadius)
                .fill(theme.surfaceSecondary)
                .overlay(
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.textTertiary)
                )
                .frame(maxWidth: .infinity)
                .frame(height: 300)
            if !auditLog.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(auditLog.indices, id: \.self) { idx in
                            auditRow(auditLog[idx])
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }
            }
        }
        .padding(theme.spacingM)
    }

    private func auditRow(_ a: [String: Any]) -> some View {
        let op = a["operation"] as? String ?? "?"
        let ts = a["timestamp"] as? String ?? ""
        return HStack {
            Text(op).font(.system(size: theme.captionSize))
            Spacer()
            Text(ts).font(.system(size: theme.captionSize)).foregroundStyle(theme.textSecondary)
        }
    }

    private func toggleShare() {
        isSharing.toggle()
        let method = isSharing ? "desk.space.desktop.share" : "desk.space.desktop.control"
        Task {
            do {
                _ = try await ipc.spaceCall(method: method, params: [
                    "space_id": spaceId, "action": isSharing ? "start" : "stop"
                ])
            } catch {
                spaceLog.error("desktop share failed: \(error.localizedDescription)")
            }
        }
    }
}
