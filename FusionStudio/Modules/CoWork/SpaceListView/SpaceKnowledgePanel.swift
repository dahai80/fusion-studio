import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")


struct SpaceKnowledgePanel: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String
    @State private var knowledgeStatus: SpaceKnowledgeStatus?
    @State private var searchQuery = ""
    @State private var searchResults: [[String: Any]] = []
    @State private var answerResult: [String: Any]?
    @State private var isSearching = false
    @State private var isUploading = false
    @State private var showUploadDialog = false
    @State private var uploadPath = ""
    private let spaceManager = CoworkSpaceManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(i18n.t(.cw_kb_title))
                    .font(.system(size: theme.footnoteSize, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                if let ks = knowledgeStatus, ks.isBound {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                }
                Button(action: { loadStatus() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: theme.iconS))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, theme.spacingM)
            .padding(.top, theme.spacingS)

            if knowledgeStatus == nil {
                unboundView
            } else if let ks = knowledgeStatus, !ks.isBound {
                unboundView
            } else {
                boundView
            }
        }
        .onAppear { loadStatus() }
    }

    private var unboundView: some View {
        VStack(spacing: theme.spacingM) {
            Image(systemName: "books.vertical")
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.cw_kb_unbound))
                .font(.system(size: theme.captionSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            Text(i18n.t(.cw_kb_bindHint))
                .font(.system(size: 9))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacingL)
            Button(action: { bindKB() }) {
                Label(i18n.t(.cw_kb_bind), systemImage: "link")
                    .font(.system(size: theme.captionSize, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, theme.spacingXL)
    }

    private var boundView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                if let ks = knowledgeStatus {
                    HStack(spacing: theme.spacingS) {
                        Image(systemName: "doc.text")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(theme.textTertiary)
                        Text(String(format: i18n.t(.cw_kb_statsFmt), ks.documentCount, ks.chunkCount))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(theme.textTertiary)
                        Spacer()
                        Button(action: { unbindKB() }) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: theme.iconS))
                                .foregroundStyle(theme.accentDestructive)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, theme.spacingM)
                }

                Divider().padding(.horizontal, theme.spacingM)

                HStack(spacing: theme.spacingS) {
                    TextField(i18n.t(.cw_kb_searchPh), text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: theme.captionSize))
                        .onSubmit { searchKB() }
                    Button(action: { searchKB() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: theme.iconS))
                    }
                    .buttonStyle(.plain)
                    .disabled(searchQuery.isEmpty || isSearching)
                }
                .padding(.horizontal, theme.spacingM)

                if isSearching {
                    ProgressView()
                        .padding(.horizontal, theme.spacingM)
                }

                if !searchResults.isEmpty {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(i18n.t(.cw_kb_results))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingM)
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { idx, result in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result["title"] as? String ?? String(format: i18n.t(.cw_kb_docFmt), idx + 1))
                                    .font(.system(size: theme.captionSize, weight: .medium))
                                    .lineLimit(1)
                                Text(result["content"] as? String ?? "")
                                    .font(.system(size: 9))
                                    .foregroundStyle(theme.textTertiary)
                                    .lineLimit(3)
                            }
                            .padding(.horizontal, theme.spacingM)
                            .padding(.vertical, theme.spacingXS)
                        }
                    }
                }

                if let answer = answerResult {
                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                        Text(i18n.t(.cw_kb_ragAnswer))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.horizontal, theme.spacingM)
                        Text(answer["answer"] as? String ?? "")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.text)
                            .padding(.horizontal, theme.spacingM)
                    }
                }

                Divider().padding(.horizontal, theme.spacingM)

                Button(action: { showUploadDialog = true }) {
                    Label(i18n.t(.cw_kb_upload), systemImage: "plus.circle")
                        .font(.system(size: theme.captionSize))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, theme.spacingM)
            }
            .padding(.top, theme.spacingS)
        }
        .sheet(isPresented: $showUploadDialog) {
            uploadSheet
        }
    }

    private var uploadSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text(i18n.t(.cw_kb_uploadTitle))
                .font(.system(size: theme.bodySize, weight: .semibold))
            TextField(i18n.t(.cw_kb_pathPh), text: $uploadPath)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(i18n.t(.cancel)) { showUploadDialog = false }
                    .buttonStyle(.bordered)
                Button(i18n.t(.cw_kb_uploadBtn)) {
                    uploadDocument()
                    showUploadDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(uploadPath.isEmpty)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 360)
    }

    private func loadStatus() {
        Task {
            await spaceManager.loadKnowledgeStatus(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = spaceManager.activeKnowledge }
        }
    }

    private func bindKB() {
        Task {
            await spaceManager.bindKnowledge(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = spaceManager.activeKnowledge }
        }
    }

    private func unbindKB() {
        Task {
            await spaceManager.unbindKnowledge(spaceId: spaceId)
            await MainActor.run { knowledgeStatus = nil }
        }
    }

    private func searchKB() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchResults = []
        answerResult = nil
        Task {
            do {
                let results = try await spaceManager.searchKnowledge(spaceId: spaceId, query: searchQuery)
                let answer = try await spaceManager.queryKnowledge(spaceId: spaceId, question: searchQuery)
                await MainActor.run {
                    searchResults = results
                    answerResult = answer
                    isSearching = false
                }
            } catch {
                spaceLog.error("Knowledge search failed: \(error.localizedDescription)")
                await MainActor.run { isSearching = false }
            }
        }
    }

    private func uploadDocument() {
        guard !uploadPath.isEmpty else { return }
        isUploading = true
        Task {
            do {
                _ = try await spaceManager.uploadKnowledge(spaceId: spaceId, filePath: uploadPath)
                await MainActor.run {
                    isUploading = false
                    uploadPath = ""
                    loadStatus()
                }
            } catch {
                spaceLog.error("Knowledge upload failed: \(error.localizedDescription)")
                await MainActor.run { isUploading = false }
            }
        }
    }
}

