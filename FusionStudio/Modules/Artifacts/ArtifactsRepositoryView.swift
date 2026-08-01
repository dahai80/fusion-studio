import SwiftUI
import os.log

private let artRepoLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.Repository")

enum ArtifactViewMode: String, CaseIterable {
    case grid = "grid"
    case list = "list"
}

enum ArtifactSortField: String, CaseIterable {
    case updatedAt = "updated_at"
    case createdAt = "created_at"
    case name = "name"

    var label: String {
        switch self {
        case .updatedAt: return "最近更新"
        case .createdAt: return "创建时间"
        case .name: return "名称"
        }
    }
}

enum ArtifactFilterScope: String, CaseIterable {
    case all = "all"
    case mine = "mine"
    case starred = "starred"
    case pinned = "pinned"

    var label: String {
        switch self {
        case .all: return "全部"
        case .mine: return "我的"
        case .starred: return "星标"
        case .pinned: return "置顶"
        }
    }

    var icon: String {
        switch self {
        case .all: return "cube.box"
        case .mine: return "person"
        case .starred: return "star"
        case .pinned: return "pin"
        }
    }
}

struct ArtifactsRepositoryView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedType = "all"
    @State private var selectedArtifactId: String?
    @State private var viewMode: ArtifactViewMode = .grid
    @State private var sortField: ArtifactSortField = .updatedAt
    @State private var filterScope: ArtifactFilterScope = .all
    @State private var folders: [[String: Any]] = []
    @State private var selectedFolderId: String?
    @State private var showRecycleBin = false
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var page = 1
    @State private var totalPages = 1
    @State private var showCanvas = false

    private let typeFilters = ["all", "code", "doc", "visualization", "data", "html", "markdown"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "Artifacts", subtitle: "全局产物仓库 — 跨会话管理所有 Artifacts")
                .padding(.bottom, theme.spacingS)

            filterBar
            Rectangle().fill(theme.separator).frame(height: 1)

            HStack(spacing: 0) {
                folderSidebar
                Rectangle().fill(theme.separator).frame(width: 1)
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadAll() }
        .sheet(isPresented: $showCanvas) {
            if let aid = selectedArtifactId {
                ArtifactCanvasView(artifactId: aid)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        .sheet(isPresented: $showRecycleBin) {
            ArtifactRecycleBinView()
                .frame(minWidth: 500, minHeight: 400)
        }
        .alert("新建文件夹", isPresented: $showCreateFolder) {
            TextField("文件夹名称", text: $newFolderName)
            Button("创建") { createFolder() }
            Button("取消", role: .cancel) { }
        }
    }

    private var filterBar: some View {
        HStack(spacing: theme.spacingM) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textTertiary)
                TextField("搜索产物…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.textSize))
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
            .overlay(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).stroke(theme.inputBorder, lineWidth: 1))

            scopePicker

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(typeFilters, id: \.self) { t in
                        Button(action: { selectedType = t }) {
                            Text(t == "all" ? "全部" : t.capitalized)
                                .font(.system(size: theme.captionSize, weight: .medium))
                                .foregroundStyle(selectedType == t ? theme.accentText : theme.textSecondary)
                                .padding(.horizontal, theme.spacingS)
                                .padding(.vertical, theme.spacingXS)
                                .background(
                                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                        .fill(selectedType == t ? theme.accent : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Menu {
                ForEach(ArtifactSortField.allCases, id: \.self) { field in
                    Button(action: { sortField = field; loadArtifacts() }) {
                        HStack {
                            Text(field.label)
                            if sortField == field { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)

            HStack(spacing: theme.spacingXS) {
                Button(action: { viewMode = .grid }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(viewMode == .grid ? theme.accent : theme.textTertiary)
                }
                .buttonStyle(.plain)
                Button(action: { viewMode = .list }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(viewMode == .list ? theme.accent : theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Button(action: { showRecycleBin = true }) {
                Image(systemName: "trash")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help("回收站")

            Button(action: { loadAll() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.bottom, theme.spacingS)
    }

    private var scopePicker: some View {
        Menu {
            ForEach(ArtifactFilterScope.allCases, id: \.self) { scope in
                Button(action: { filterScope = scope; loadArtifacts() }) {
                    Label(scope.label, systemImage: scope.icon)
                }
            }
        } label: {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: filterScope.icon)
                    .font(.system(size: theme.iconS))
                Text(filterScope.label)
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
        }
        .menuStyle(.borderlessButton)
    }

    private var folderSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("文件夹")
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { showCreateFolder = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.vertical, theme.spacingS)

            Rectangle().fill(theme.separator).frame(height: 1)

            Button(action: { selectedFolderId = nil; loadArtifacts() }) {
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "tray.full")
                        .font(.system(size: theme.iconS))
                    Text("全部产物")
                        .font(.system(size: theme.footnoteSize))
                    Spacer()
                }
                .foregroundStyle(selectedFolderId == nil ? theme.accent : theme.text)
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(selectedFolderId == nil ? theme.accent.opacity(0.08) : Color.clear)
            }
            .buttonStyle(.plain)

            ForEach(folders.indices, id: \.self) { idx in
                folderRow(folders[idx])
            }

            Spacer()
        }
        .frame(width: 180)
        .background(theme.surfacePrimary)
    }

    private func folderRow(_ f: [String: Any]) -> some View {
        let fid = f["id"] as? String ?? ""
        let name = f["name"] as? String ?? "Untitled"
        let isSelected = selectedFolderId == fid

        return HStack(spacing: theme.spacingS) {
            Image(systemName: "folder")
                .font(.system(size: theme.iconS))
                .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
            Text(name)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(isSelected ? theme.accent : theme.text)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(isSelected ? theme.accent.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFolderId = fid
            loadArtifacts()
        }
        .contextMenu {
            Button("重命名") { renameFolder(fid, currentName: name) }
            Button("删除", role: .destructive) { deleteFolder(fid) }
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                errorBanner(err)
            } else {
                if viewMode == .grid {
                    artifactGrid
                } else {
                    artifactList
                }
            }

            if totalPages > 1 {
                paginationBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var paginationBar: some View {
        HStack(spacing: theme.spacingS) {
            Spacer()
            Button(action: { if page > 1 { page -= 1; loadArtifacts() } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
            .disabled(page <= 1)

            Text("\(page) / \(totalPages)")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textSecondary)

            Button(action: { if page < totalPages { page += 1; loadArtifacts() } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: theme.iconS))
            }
            .buttonStyle(.plain)
            .disabled(page >= totalPages)
            Spacer()
        }
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceElevated)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: theme.spacingS) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button("重试") { loadArtifacts() }
                .font(.system(size: theme.footnoteSize))
        }
        .padding(theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surfaceSecondary))
        .padding(theme.spacingL)
    }

    private var filteredArtifacts: [[String: Any]] {
        artifacts.filter { a in
            if selectedType != "all" {
                let t = a["type"] as? String ?? ""
                if t != selectedType { return false }
            }
            if !searchText.isEmpty {
                let name = (a["name"] as? String ?? "").lowercased()
                if !name.contains(searchText.lowercased()) { return false }
            }
            if filterScope == .starred {
                if !(a["starred"] as? Bool ?? false) { return false }
            }
            if filterScope == .pinned {
                if !(a["pinned"] as? Bool ?? false) { return false }
            }
            return true
        }
    }

    private var artifactGrid: some View {
        let filtered = filteredArtifacts
        return ScrollView {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: theme.spacingM),
                    GridItem(.flexible(), spacing: theme.spacingM),
                    GridItem(.flexible(), spacing: theme.spacingM),
                ], spacing: theme.spacingM) {
                    ForEach(filtered.indices, id: \.self) { idx in
                        artifactCard(filtered[idx])
                    }
                }
                .padding(theme.spacingL)
            }
        }
    }

    private var artifactList: some View {
        let filtered = filteredArtifacts
        return ScrollView {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filtered.indices, id: \.self) { idx in
                        artifactListRow(filtered[idx])
                    }
                }
                .padding(theme.spacingM)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: theme.spacingM) {
            Spacer().frame(height: 40)
            Image(systemName: "cube.box")
                .font(.system(size: 30))
                .foregroundStyle(theme.textTertiary)
            Text("暂无产物")
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func artifactCard(_ a: [String: Any]) -> some View {
        let aid = a["artifact_id"] as? String ?? a["id"] as? String ?? ""
        let name = a["name"] as? String ?? "Untitled"
        let type = a["type"] as? String ?? "unknown"
        let version = a["current_version"] as? Int ?? a["version"] as? Int ?? 0
        let starred = a["starred"] as? Bool ?? false
        let pinned = a["pinned"] as? Bool ?? false
        let summary = a["summary"] as? String ?? ""
        let isSelected = selectedArtifactId == aid

        return VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: artifactIcon(type))
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(artifactColor(type))
                Spacer()
                if pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.accent)
                }
                if starred {
                    Image(systemName: "star.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(.yellow)
                }
                artifactMenu(aid: aid, name: name, starred: starred)
            }

            Text(name)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)

            if !summary.isEmpty {
                Text(summary)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
            }

            HStack {
                Text(type.capitalized)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if version > 0 {
                    Text("v\(version)")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.08) : theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.3) : theme.separator, lineWidth: 1)
        )
        .onTapGesture {
            selectedArtifactId = aid
            showCanvas = true
        }
    }

    private func artifactListRow(_ a: [String: Any]) -> some View {
        let aid = a["artifact_id"] as? String ?? a["id"] as? String ?? ""
        let name = a["name"] as? String ?? "Untitled"
        let type = a["type"] as? String ?? "unknown"
        let version = a["current_version"] as? Int ?? a["version"] as? Int ?? 0
        let starred = a["starred"] as? Bool ?? false
        let summary = a["summary"] as? String ?? ""
        let isSelected = selectedArtifactId == aid

        return HStack(spacing: theme.spacingM) {
            Image(systemName: artifactIcon(type))
                .font(.system(size: theme.iconM))
                .foregroundStyle(artifactColor(type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: theme.spacingXS) {
                    Text(name)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                    if starred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                }
                if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(type.capitalized)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            if version > 0 {
                Text("v\(version)")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }

            artifactMenu(aid: aid, name: name, starred: starred)
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingS)
        .background(isSelected ? theme.accent.opacity(0.08) : Color.clear)
        .cornerRadius(theme.cornerRadiusSmall)
        .onTapGesture {
            selectedArtifactId = aid
            showCanvas = true
        }
    }

    private func artifactMenu(aid: String, name: String, starred: Bool) -> some View {
        Menu {
            Button("打开") {
                selectedArtifactId = aid
                showCanvas = true
            }
            Button("重命名") { renameArtifact(aid, currentName: name) }
            Button(starred ? "取消星标" : "星标") { toggleStar(aid, starred: starred) }
            Divider()
            Button("复制内容") { copyContent(aid) }
            Button("下载") { downloadArtifact(aid) }
            Button("复制") { duplicateArtifact(aid, name: name) }
            Divider()
            Button("移至项目KB") { moveToProjectKb(aid) }
            Divider()
            Button("删除", role: .destructive) { deleteArtifact(aid) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: theme.iconS))
                .foregroundStyle(theme.textTertiary)
        }
        .menuStyle(.borderlessButton)
    }

    private func artifactIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc", "document", "markdown": return "doc.text"
        case "visualization", "chart": return "chart.bar"
        case "data": return "tablecells"
        case "html", "react", "app": return "globe"
        case "svg": return "paintbrush"
        case "mermaid": return "flowchart"
        default: return "cube.box"
        }
    }

    private func artifactColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "code": return .purple
        case "doc", "document", "markdown": return .indigo
        case "visualization", "chart": return .green
        case "data": return .orange
        case "html", "react", "app": return .blue
        case "svg": return .pink
        default: return theme.accent
        }
    }

    private func loadAll() {
        loadArtifacts()
        loadFolders()
    }

    private func loadArtifacts() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                var filters: [String: Any] = [:]
                if filterScope == .starred { filters["starred"] = true }
                if filterScope == .pinned { filters["pinned"] = true }
                if let fid = selectedFolderId { filters["folder_id"] = fid }

                let r = try await ipc.artifactCall(method: "artifact.list_all", params: [
                    "page": page,
                    "page_size": 20,
                    "sort": sortField.rawValue,
                    "filters": filters
                ])
                artRepoLog.info("list_all loaded: \(r.count) keys")
                let items = r["artifacts"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                let total = r["total"] as? Int ?? items.count
                await MainActor.run {
                    artifacts = items
                    totalPages = max(1, (total + 19) / 20)
                    isLoading = false
                }
            } catch {
                artRepoLog.error("list_all failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func loadFolders() {
        Task {
            do {
                let r = try await ipc.artifactCall(method: "artifact.list_folders", params: ["parent_id": selectedFolderId ?? NSNull()])
                let items = r["folders"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                await MainActor.run { folders = items }
                artRepoLog.info("folders loaded: \(items.count)")
            } catch {
                artRepoLog.error("load folders failed: \(error.localizedDescription)")
            }
        }
    }

    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.create_folder", params: [
                    "name": newFolderName,
                    "parent_id": selectedFolderId ?? NSNull()
                ])
                artRepoLog.info("folder created: \(self.newFolderName)")
                await MainActor.run { newFolderName = "" }
                loadFolders()
            } catch {
                artRepoLog.error("create folder failed: \(error.localizedDescription)")
            }
        }
    }

    private func renameFolder(_ fid: String, currentName: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.rename_folder", params: [
                    "folder_id": fid,
                    "new_name": currentName
                ])
                artRepoLog.info("folder renamed: \(fid)")
                loadFolders()
            } catch {
                artRepoLog.error("rename folder failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteFolder(_ fid: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.delete_folder", params: ["folder_id": fid])
                artRepoLog.info("folder deleted: \(fid)")
                if selectedFolderId == fid { selectedFolderId = nil }
                loadFolders()
                loadArtifacts()
            } catch {
                artRepoLog.error("delete folder failed: \(error.localizedDescription)")
            }
        }
    }

    private func renameArtifact(_ aid: String, currentName: String) {
        Task {
            do {
                _ = try await ipc.artifactRename(artifactId: aid, newName: currentName + " (copy)")
                loadArtifacts()
            } catch {
                artRepoLog.error("rename failed: \(error.localizedDescription)")
            }
        }
    }

    private func toggleStar(_ aid: String, starred: Bool) {
        Task {
            do {
                _ = try await ipc.artifactStar(artifactId: aid, starred: !starred)
                loadArtifacts()
            } catch {
                artRepoLog.error("star failed: \(error.localizedDescription)")
            }
        }
    }

    private func copyContent(_ aid: String) {
        Task {
            do {
                let r = try await ipc.artifactGetContent(artifactId: aid)
                if let content = r["content"] as? String {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(content, forType: .string)
                }
            } catch {
                artRepoLog.error("get_content failed: \(error.localizedDescription)")
            }
        }
    }

    private func downloadArtifact(_ aid: String) {
        Task {
            do {
                let r = try await ipc.artifactExport(artifactId: aid)
                artRepoLog.info("exported: \(r.count) keys")
            } catch {
                artRepoLog.error("export failed: \(error.localizedDescription)")
            }
        }
    }

    private func duplicateArtifact(_ aid: String, name: String) {
        Task {
            do {
                _ = try await ipc.artifactDuplicate(artifactId: aid, newName: name + " (副本)")
                artRepoLog.info("duplicated: \(aid)")
                loadArtifacts()
            } catch {
                artRepoLog.error("duplicate failed: \(error.localizedDescription)")
            }
        }
    }

    private func moveToProjectKb(_ aid: String) {
        guard let projectId = FusionProjectManager.shared.activeProject?.id else {
            artRepoLog.warning("no active project for move_to_project_kb")
            return
        }
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.move_to_project_kb", params: [
                    "artifact_id": aid,
                    "project_id": projectId
                ])
                artRepoLog.info("moved to project kb: \(aid)")
                loadArtifacts()
            } catch {
                artRepoLog.error("move_to_project_kb failed: \(error.localizedDescription)")
            }
        }
    }

    private func deleteArtifact(_ aid: String) {
        Task {
            do {
                _ = try await ipc.artifactDelete(artifactId: aid)
                artRepoLog.info("deleted: \(aid)")
                loadArtifacts()
            } catch {
                artRepoLog.error("delete failed: \(error.localizedDescription)")
            }
        }
    }
}

struct ArtifactRecycleBinView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("回收站")
                    .font(.system(size: theme.textSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("清空过期") { purgeExpired() }
                    .font(.system(size: theme.footnoteSize))
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDestructive)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS)

            Rectangle().fill(theme.separator).frame(height: 1)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if artifacts.isEmpty {
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "trash")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text("回收站为空")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(artifacts.indices, id: \.self) { idx in
                    recycleRow(artifacts[idx])
                }
                .listStyle(.sidebar)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear { loadRecycleBin() }
    }

    private func recycleRow(_ a: [String: Any]) -> some View {
        let aid = a["artifact_id"] as? String ?? a["id"] as? String ?? ""
        let name = a["name"] as? String ?? "Untitled"
        let type = a["type"] as? String ?? ""

        return HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(type.capitalized)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            Button("恢复") { restoreArtifact(aid) }
                .font(.system(size: theme.footnoteSize))
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
        }
        .padding(.vertical, theme.spacingXS)
    }

    private func loadRecycleBin() {
        isLoading = true
        Task {
            do {
                let r = try await ipc.artifactCall(method: "artifact.list_recycle", params: [
                    "page": 1, "page_size": 50
                ])
                let items = r["artifacts"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                await MainActor.run { artifacts = items; isLoading = false }
            } catch {
                artRepoLog.error("recycle bin load failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func restoreArtifact(_ aid: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.restore", params: ["artifact_id": aid])
                artRepoLog.info("restored: \(aid)")
                loadRecycleBin()
            } catch {
                artRepoLog.error("restore failed: \(error.localizedDescription)")
            }
        }
    }

    private func purgeExpired() {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.purge_expired", params: [:])
                artRepoLog.info("purged expired")
                loadRecycleBin()
            } catch {
                artRepoLog.error("purge failed: \(error.localizedDescription)")
            }
        }
    }
}
