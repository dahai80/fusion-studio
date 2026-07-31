import SwiftUI
import os.log

private let artRepoLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.Repository")

struct ArtifactsRepositoryView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme

    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedType = "all"
    @State private var selectedArtifactId: String?

    private let typeFilters = ["all", "code", "doc", "visualization", "data"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(eyebrow: "Fusion Studio", title: "Artifacts", subtitle: "全局产物仓库 — 跨会话管理所有 Artifacts")
                .padding(.bottom, theme.spacingS)

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

                Spacer()

                Button(action: { loadArtifacts() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = errorMessage {
                errorBanner(err)
            } else {
                artifactGrid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadArtifacts() }
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

    private var artifactGrid: some View {
        let filtered = artifacts.filter { a in
            if selectedType != "all" {
                let t = a["type"] as? String ?? ""
                if t != selectedType { return false }
            }
            if !searchText.isEmpty {
                let name = (a["name"] as? String ?? "").lowercased()
                if !name.contains(searchText.lowercased()) { return false }
            }
            return true
        }
        return ScrollView {
            if filtered.isEmpty {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text("暂无产物")
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
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

    private func artifactCard(_ a: [String: Any]) -> some View {
        let aid = a["artifact_id"] as? String ?? a["id"] as? String ?? ""
        let name = a["name"] as? String ?? "Untitled"
        let type = a["type"] as? String ?? "unknown"
        let version = a["current_version"] as? Int ?? a["version"] as? Int ?? 0
        let starred = a["starred"] as? Bool ?? false
        let isSelected = selectedArtifactId == aid

        return VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: artifactIcon(type))
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.accent)
                Spacer()
                if starred {
                    Image(systemName: "star.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(.yellow)
                }
                Menu {
                    Button("打开") { selectedArtifactId = aid }
                    Button("重命名") { renameArtifact(aid, currentName: name) }
                    Button(starred ? "取消星标" : "星标") { toggleStar(aid, starred: starred) }
                    Divider()
                    Button("复制内容") { copyContent(aid) }
                    Button("下载") { downloadArtifact(aid) }
                    Divider()
                    Button("删除", role: .destructive) { deleteArtifact(aid) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.textTertiary)
                }
                .menuStyle(.borderlessButton)
            }

            Text(name)
                .font(.system(size: theme.textSize, weight: .medium))
                .foregroundStyle(theme.text)
                .lineLimit(1)

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
        .onTapGesture { selectedArtifactId = aid }
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "doc": return "doc.text"
        case "visualization": return "chart.bar"
        case "data": return "tablecells"
        default: return "cube.box"
        }
    }

    private func loadArtifacts() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let r = try await ipc.artifactCall(method: "artifact.list_all", params: [
                    "page": 1, "page_size": 100
                ])
                artRepoLog.info("list_all loaded: \(r.count) keys")
                let items = r["artifacts"] as? [[String: Any]] ?? r["items"] as? [[String: Any]] ?? []
                await MainActor.run { artifacts = items; isLoading = false }
            } catch {
                artRepoLog.error("list_all failed: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
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

    private func deleteArtifact(_ aid: String) {
        Task {
            do {
                _ = try await ipc.artifactDelete(artifactId: aid)
                loadArtifacts()
            } catch {
                artRepoLog.error("delete failed: \(error.localizedDescription)")
            }
        }
    }
}
