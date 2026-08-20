import SwiftUI
import os.log

private let tagLog = Logger(subsystem: "com.fusion.studio", category: "Artifacts.TagFolderManager")

struct ArtifactTagFolderPopover: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let artifactId: String
    @State private var currentTags: [String] = []
    @State private var currentFolderId: String?
    @State private var currentFolderName: String?
    @State private var folders: [[String: Any]] = []
    @State private var newTag = ""
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            tagSection
            folderSection
        }
        .padding(theme.spacingM)
        .frame(width: 280)
        .onAppear { loadData() }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.art_tf_tags))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacingXS) {
                    ForEach(currentTags, id: \.self) { tag in
                        HStack(spacing: 2) {
                            Text("#\(tag)")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.accentSecondary)
                            Button(action: { removeTag(tag) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, theme.spacingXS)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(theme.accentSoft.opacity(0.15)))
                    }
                }
            }

            HStack(spacing: theme.spacingXS) {
                TextField(i18n.t(.art_tf_addTag), text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.system(size: theme.footnoteSize))
                    .onSubmit { addTag() }
                Button(action: addTag) {
                    Image(systemName: "plus")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newTag.isEmpty)
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.art_tf_folders))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            if isLoading {
                ProgressView().controlSize(.small)
            } else {
                ForEach(folders.indices, id: \.self) { idx in
                    folderOption(folders[idx])
                }

                if folders.isEmpty {
                    Text(i18n.t(.art_tf_noFolders))
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
    }

    private func folderOption(_ f: [String: Any]) -> some View {
        let fid = f["id"] as? String ?? ""
        let name = f["name"] as? String ?? "Untitled"
        let isSelected = currentFolderId == fid

        return Button(action: { moveToFolder(fid) }) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: isSelected ? "folder.fill" : "folder")
                    .font(.system(size: theme.iconS))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                Text(name)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(isSelected ? theme.accent : theme.text)
                    .lineLimit(1)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, theme.spacingS)
            .padding(.vertical, theme.spacingXS)
            .background(isSelected ? theme.accent.opacity(0.08) : Color.clear)
            .cornerRadius(theme.cornerRadiusSmall)
        }
        .buttonStyle(.plain)
    }

    private func loadData() {
        isLoading = true
        Task {
            do {
                let artifactR = try await ipc.artifactGet(artifactId: artifactId)
                let tags = artifactR["tags"] as? [String] ?? []
                let folderId = artifactR["folder_id"] as? String
                let folderName = artifactR["folder_name"] as? String

                let folderR = try await ipc.artifactCall(method: "artifact.list_folders", params: ["parent_id": NSNull()])
                let items = folderR["folders"] as? [[String: Any]] ?? folderR["items"] as? [[String: Any]] ?? []

                await MainActor.run {
                    currentTags = tags
                    currentFolderId = folderId
                    currentFolderName = folderName
                    folders = items
                    isLoading = false
                }
            } catch {
                tagLog.error("load tag/folder data failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !currentTags.contains(tag) else { return }
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.add_tag", params: [
                    "artifact_id": artifactId,
                    "tag": tag
                ])
                tagLog.info("tag added: \(tag)")
                await MainActor.run {
                    currentTags.append(tag)
                    newTag = ""
                }
            } catch {
                tagLog.error("add_tag failed: \(error.localizedDescription)")
            }
        }
    }

    private func removeTag(_ tag: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.remove_tag", params: [
                    "artifact_id": artifactId,
                    "tag": tag
                ])
                tagLog.info("tag removed: \(tag)")
                await MainActor.run {
                    currentTags.removeAll { $0 == tag }
                }
            } catch {
                tagLog.error("remove_tag failed: \(error.localizedDescription)")
            }
        }
    }

    private func moveToFolder(_ folderId: String) {
        Task {
            do {
                _ = try await ipc.artifactCall(method: "artifact.move_to_folder", params: [
                    "artifact_id": artifactId,
                    "folder_id": folderId
                ])
                tagLog.info("moved to folder: \(folderId)")
                await MainActor.run { currentFolderId = folderId }
                loadData()
            } catch {
                tagLog.error("move_to_folder failed: \(error.localizedDescription)")
            }
        }
    }
}
