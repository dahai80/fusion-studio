import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")


struct SpaceFilesPanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var files: [SpaceAttachment] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_files_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button(action: { loadFiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if isLoading {
                ProgressView().padding()
            } else if files.isEmpty {
                VStack(spacing: theme.spacingXS) {
                    Image(systemName: "folder")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_files_empty))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, theme.spacingL)
            } else {
                ScrollView {
                    LazyVStack(spacing: theme.spacingXS) {
                        ForEach(files) { file in
                            HStack(spacing: theme.spacingS) {
                                Image(systemName: "doc")
                                    .font(.system(size: theme.iconS))
                                    .foregroundStyle(theme.textTertiary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(file.fileName)
                                        .font(.system(size: theme.captionSize))
                                        .lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(theme.textTertiary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .onAppear { loadFiles() }
    }

    private func loadFiles() {
        isLoading = true
        Task {
            do {
                let result = try await ipc.spaceArtifactList(spaceId: spaceId)
                let items = result["artifacts"] as? [[String: Any]] ?? []
                await MainActor.run { files = items.map { SpaceAttachment.fromDict($0) }; isLoading = false }
            } catch {
                spaceLog.error("file.list failed: \(error.localizedDescription)")
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Page 5: Agent管理面板
