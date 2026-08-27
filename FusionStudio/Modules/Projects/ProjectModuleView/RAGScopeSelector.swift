import SwiftUI
import os.log

private let projLog = Logger(subsystem: "com.fusion.studio", category: "ProjectModule")

struct RAGScopeSelector: View {
    let projectId: String
    @Binding var ragMode: RAGMode
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var ipc: IPCClient

    @State private var folders: [KnowledgeFolder] = []
    @State private var files: [KnowledgeFile] = []
    @State private var selectedFolderIds: Set<String> = []
    @State private var selectedFileIds: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.proj_ragScopeTitle))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Picker(i18n.t(.proj_ragScopeMode), selection: $ragMode) {
                Text(i18n.t(.proj_ragScopeAuto)).tag(RAGMode.AUTO)
                Text(i18n.t(.proj_ragScopeManual)).tag(RAGMode.MANUAL)
            }
            .pickerStyle(.radioGroup)
            .font(.system(size: theme.captionSize))

            if ragMode == .MANUAL {
                Text(i18n.t(.proj_ragScopeSpecify))
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingXS) {
                        ForEach(folders) { folder in
                            HStack {
                                Toggle(folder.name, isOn: Binding(
                                    get: { selectedFolderIds.contains(folder.id) },
                                    set: { v in
                                        if v { selectedFolderIds.insert(folder.id) } else { selectedFolderIds.remove(folder.id) }
                                    }
                                ))
                                .font(.system(size: theme.footnoteSize))
                            }

                            let folderFiles = files.filter { $0.folderId == folder.id }
                            ForEach(folderFiles) { file in
                                HStack {
                                    Text("    ")
                                    Toggle(file.fileName, isOn: Binding(
                                        get: { selectedFileIds.contains(file.id) },
                                        set: { v in
                                            if v { selectedFileIds.insert(file.id) } else { selectedFileIds.remove(file.id) }
                                        }
                                    ))
                                    .font(.system(size: theme.captionSize))
                                }
                            }
                        }

                        let rootFiles = files.filter { $0.folderId == nil }
                        ForEach(rootFiles) { file in
                            Toggle(file.fileName, isOn: Binding(
                                get: { selectedFileIds.contains(file.id) },
                                set: { v in
                                    if v { selectedFileIds.insert(file.id) } else { selectedFileIds.remove(file.id) }
                                }
                            ))
                            .font(.system(size: theme.footnoteSize))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(i18n.t(.cancel)) { dismiss() }
                Button(i18n.t(.proj_ragScopeConfirm)) {
                    saveRAGConfig()
                    dismiss()
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 440, height: 460)
        .onAppear { loadKnowledge() }
    }

    private func loadKnowledge() {
        Task {
            do {
                async let f = ipc.projectFolderList(projectId: projectId)
                async let fl = ipc.projectKnowledgeFileList(projectId: projectId)
                let foldersResult = try await f
                let filesResult = try await fl
                await MainActor.run {
                    if let items = foldersResult["items"] as? [[String: Any]] ?? foldersResult["folders"] as? [[String: Any]] {
                        self.folders = items.compactMap { KnowledgeFolder.fromDict($0) }
                    }
                    if let items = filesResult["items"] as? [[String: Any]] ?? filesResult["files"] as? [[String: Any]] {
                        self.files = items.compactMap { KnowledgeFile.fromDict($0) }
                    }
                }
            } catch {
                projLog.error("loadKnowledge failed: \(error.localizedDescription)")
            }
        }
    }

    private func saveRAGConfig() {
        Task {
            do {
                _ = try await ipc.projectRagConfigSet(
                    projectId: projectId,
                    ragMode: ragMode.rawValue
                )
            } catch {
                projLog.error("saveRAGConfig failed: \(error.localizedDescription)")
            }
        }
    }
}
