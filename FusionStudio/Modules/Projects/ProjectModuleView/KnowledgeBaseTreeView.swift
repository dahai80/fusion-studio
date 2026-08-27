import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct KnowledgeBaseTreeView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let projectId: String
    @State private var folders: [KnowledgeFolder] = []
    @State private var files: [KnowledgeFile] = []
    @State private var expandedFolders: Set<String> = []
    @State private var showAddFilePicker = false
    @State private var showAddFolderDialog = false
    @State private var newFolderName = ""
    @State private var selectedFileId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingS) {
                // Header
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .foregroundStyle(theme.accent)
                    Text(i18n.t(.proj_kbTitle))
                        .font(.system(size: theme.textSize, weight: .semibold))
                    Text(String(format: i18n.t(.proj_kbFileCountFmt), files.count))
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()

                    Button(action: { showAddFolderDialog = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "folder.badge.plus")
                            Text(i18n.t(.proj_kbFolder))
                        }
                        .font(.system(size: theme.captionSize))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Button(action: { showAddFilePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text(i18n.t(.proj_kbAddFile))
                        }
                        .font(.system(size: theme.captionSize))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                }

                // Tree
                if files.isEmpty && folders.isEmpty {
                    emptyKnowledgeState
                } else {
                    // Root-level files (no folder)
                    let rootFiles = files.filter { f in f.folderId == nil }
                    ForEach(rootFiles) { file in
                        knowledgeFileRow(file)
                    }

                    // Folders with their files
                    ForEach(folders) { folder in
                        folderSection(folder)
                    }
                }
            }
            .padding(theme.spacingL)
        }
        .fileImporter(isPresented: $showAddFilePicker,
                      allowedContentTypes: [.item],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
        .alert(i18n.t(.proj_kbNewFolderAlert), isPresented: $showAddFolderDialog) {
            TextField(i18n.t(.proj_kbFolderNamePh), text: $newFolderName)
            Button(i18n.t(.cancel), role: .cancel) { newFolderName = "" }
            Button(i18n.t(.proj_kbCreate)) {
                createFolder()
                newFolderName = ""
            }
            .disabled(newFolderName.isEmpty)
        }
        .onAppear {
            loadKnowledge()
        }
    }

    private var emptyKnowledgeState: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(theme.textQuaternary)
            Text(i18n.t(.proj_kbEmpty))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.proj_kbEmptyHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textQuaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(theme.spacingXL)
    }

    private func folderSection(_ folder: KnowledgeFolder) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder header
            Button(action: {
                if expandedFolders.contains(folder.id) {
                    expandedFolders.remove(folder.id)
                } else {
                    expandedFolders.insert(folder.id)
                }
            }) {
                HStack(spacing: theme.spacingXS) {
                    Image(systemName: expandedFolders.contains(folder.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .semibold))
                        .frame(width: 10)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(theme.accent)
                        .font(.system(size: theme.iconXS))
                    Text(folder.name)
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.text)
                    Text("\(folder.fileCount)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Files in folder
            if expandedFolders.contains(folder.id) {
                let folderFiles = files.filter { $0.folderId == folder.id }
                ForEach(folderFiles) { file in
                    HStack(spacing: theme.spacingXS) {
                        Text("    ")
                        knowledgeFileRow(file)
                    }
                }
            }
        }
    }

    // GUI-18: File row with index status
    private func knowledgeFileRow(_ file: KnowledgeFile) -> some View {
        HStack(spacing: theme.spacingXS) {
            Image(systemName: fileIcon(for: file.fileName))
                .font(.system(size: theme.iconXS))
                .foregroundStyle(theme.textTertiary)

            VStack(alignment: .leading, spacing: 1) {
                Text(file.fileName)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    // GUI-18: Index status
                    statusIcon(file.indexStatus)
                    if file.tokenCount > 0 {
                        Text("(\(file.tokenCount) tokens)")
                            .foregroundStyle(theme.textQuaternary)
                    }
                }
                .font(.system(size: 8, design: .monospaced))
            }

            Spacer()

            // GUI-8: File context menu
            KnowledgeFileMenu(file: file, projectId: projectId)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                .fill(selectedFileId == file.id ? theme.accent.opacity(0.08) : .clear)
        )
    }

    @ViewBuilder
    private func statusIcon(_ status: String) -> some View {
        switch status {
        case "ready", "indexed":
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(i18n.t(.proj_kbStatusIndexed))
                    .foregroundStyle(.green)
            }
        case "indexing":
            HStack(spacing: 2) {
                ProgressView()
                    .scaleEffect(0.5)
                Text(i18n.t(.proj_kbStatusIndexing))
                    .foregroundStyle(.orange)
            }
        case "failed":
            HStack(spacing: 2) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(i18n.t(.proj_kbStatusFailed))
                    .foregroundStyle(.red)
            }
        default:
            HStack(spacing: 2) {
                Image(systemName: "clock")
                    .foregroundStyle(theme.textQuaternary)
                Text(i18n.t(.proj_kbStatusPending))
                    .foregroundStyle(theme.textQuaternary)
            }
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "md", "txt": return "doc.text"
        case "csv": return "tablecells"
        case "png", "jpg", "jpeg", "webp": return "photo"
        default: return "doc"
        }
    }

    private func loadKnowledge() {
        Task {
            do {
                async let foldersResult = ipc.projectFolderList(projectId: projectId)
                async let filesResult = ipc.projectKnowledgeFileList(projectId: projectId)
                let f = try await foldersResult
                let fl = try await filesResult
                await MainActor.run {
                    if let items = f["items"] as? [[String: Any]] ?? f["folders"] as? [[String: Any]] {
                        self.folders = items.compactMap { KnowledgeFolder.fromDict($0) }
                    }
                    if let items = fl["items"] as? [[String: Any]] ?? fl["files"] as? [[String: Any]] {
                        self.files = items.compactMap { KnowledgeFile.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadKnowledge failed: \(error.localizedDescription)")
            }
        }
    }

    private func createFolder() {
        Task {
            do {
                _ = try await ipc.projectFolderCreate(projectId: projectId, name: newFolderName)
                loadKnowledge()
            } catch {
                projLog.error("createFolder failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                Task {
                    do {
                        _ = try await ipc.projectKnowledgeFileUpload(
                            projectId: projectId,
                            sourcePath: url.path,
                            originalName: url.lastPathComponent
                        )
                        loadKnowledge()
                    } catch {
                        projLog.error("file upload failed: \(error.localizedDescription)")
                    }
                }
            }
        case .failure(let error):
            projLog.error("file import failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - GUI-8: Knowledge File Context Menu

