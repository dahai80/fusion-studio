// F-I7: CodeEditorView.swift 拆分 — git 状态视图 + 聊天历史侧栏 (CodeView sidebarTab 两子页)。
// 迁自 CodeEditorView.swift: GitStatusView / ChatHistoryView。
// GitStatusView codeEditLog 用 1 次 (共享在 CodeView.swift)。

import SwiftUI

// MARK: - Chat History

struct ChatHistoryView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var agent = CodeAgent.shared
    @StateObject private var i18n = I18nManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary).font(.caption)
                TextField(i18n.t(.fc_search_conversations), text: .constant(""))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
            }
            .padding(8)

            Divider()

            if agent.conversation.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "message").font(.system(size: 20)).foregroundColor(.secondary)
                    Text(i18n.t(.fc_no_conversations)).font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(agent.conversation.filter { $0.role == "user" }.reversed().prefix(10)) { msg in
                        Button(action: { agent.scrollToMessageId = msg.id }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(msg.content.prefix(60))
                                    .font(.system(size: 11))
                                    .lineLimit(2)
                                Text(msg.timestamp, style: .time)
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
    }
}

// MARK: - Git Status

struct GitStatusView: View {
    @Environment(\.studioTheme) private var theme
    @StateObject private var workspace = ProjectWorkspace.shared
    @StateObject private var i18n = I18nManager.shared
    @State private var changes: [(String, String)] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.triangle.branch").font(.system(size: 10))
                Text(workspace.gitBranch.isEmpty ? i18n.t(.fc_not_git_repo) : workspace.gitBranch)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 4)

            if !workspace.hasProject {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "arrow.triangle.branch").font(.system(size: 20)).foregroundColor(.secondary)
                    Text(i18n.t(.fc_open_for_git)).font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else if changes.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "checkmark.circle").font(.system(size: 20)).foregroundColor(.secondary)
                    Text(i18n.t(.fc_no_changes)).font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List(changes, id: \.0) { (file, status) in
                    HStack(spacing: 4) {
                        Text(status).font(.system(size: 9, weight: .bold))
                            .foregroundColor(status == "M" ? .orange : .green)
                            .frame(width: 16)
                        Text(file).font(.system(size: 10))
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(theme.surfaceSecondary)
        .onAppear { loadGitChanges() }
        .onChange(of: workspace.projectRoot) { _, _ in loadGitChanges() }
    }

    private func loadGitChanges() {
        guard let root = workspace.projectRoot else { changes = []; return }
        // PERF-6: git status --porcelain + waitUntilExit 原同步跑主线程, 大仓 waitUntilExit 阻塞 UI。移后台 Task.detached 跑进程, 仅解析结果回 MainActor 赋值。BUG-12 同类: 不在 wait 后读 stderr, 本处 stderr 已 null, stdout readDataToEndOfFile 在进程退出后非阻塞返回。
        Task.detached { [root] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["status", "--porcelain"]
            process.currentDirectoryURL = root

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
                // F-R7: waitUntilExit 10s 超时兜底防 git status 挂起 (交互式凭证提示等)。
                let timeoutTask = Task {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    if process.isRunning {
                        process.terminate()
                        codeEditLog.warning("loadGitChanges git status timeout 10s, force terminate")
                    }
                }
                process.waitUntilExit()
                timeoutTask.cancel()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let parsed = output.split(separator: "\n").compactMap { line -> (String, String)? in
                    let parts = String(line).split(separator: " ", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    return (String(parts[1]), String(parts[0]).trimmingCharacters(in: .whitespaces))
                }
                await MainActor.run { self.changes = parsed }
            } catch {
                await MainActor.run { self.changes = [] }
            }
        }
    }
}
