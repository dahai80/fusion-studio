// F-I7: CodeEditorView.swift 拆分 — 打开/克隆项目 sheet (最大单视图)。
// 迁自 CodeEditorView.swift: OpenProjectSheet。
// BUG-10 (argv 选项注入校验) / BUG-12 (waitUntilExit 主线程死锁改 Task.detached 并发 drain) 修复随迁。

import SwiftUI
import AppKit

// MARK: - Open Project Sheet

struct OpenProjectSheet: View {
    @ObservedObject var workspace: ProjectWorkspace
    @Environment(\.studioTheme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var i18n = I18nManager.shared
    @State private var gitURL = ""
    @State private var gitBranch = "main"
    @State private var isCloning = false
    @State private var cloneError: String?

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            ScrollView {
                VStack(spacing: theme.spacingL) {
                    localFolderCard
                    singleFileCard
                    gitHubCard
                    dividerOr
                    dropZone
                }
                .padding(theme.spacingL)
            }
        }
        .frame(width: 520)
        .background(theme.surfacePrimary)
    }

    private var sheetHeader: some View {
        HStack {
            Text(i18n.t(.fc_open_project))
                .font(.system(size: theme.headlineSize, weight: .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: theme.iconL))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(.regularMaterial)
    }

    private var localFolderCard: some View {
        FusionCard(style: .bordered) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.fc_local_folder))
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(i18n.t(.fc_local_folder_desc))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                FusionButton(i18n.t(.fc_choose), icon: "folder", style: .tinted, size: .regular) {
                    workspace.openLocalFolder()
                    if workspace.hasProject { dismiss() }
                }
            }
        }
    }

    private var singleFileCard: some View {
        FusionCard(style: .bordered) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: theme.iconXL))
                    .foregroundStyle(theme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t(.fc_single_file))
                        .font(.system(size: theme.textSize, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(i18n.t(.fc_single_file_desc))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }

                Spacer()

                FusionButton(i18n.t(.fc_choose), icon: "doc", style: .tinted, size: .regular) {
                    workspace.openSingleFile()
                    if workspace.hasProject { dismiss() }
                }
            }
        }
    }

    private var gitHubCard: some View {
        FusionCard(style: .bordered) {
            VStack(alignment: .leading, spacing: theme.spacingM) {
                HStack(spacing: theme.spacingM) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: theme.iconXL))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t(.fc_github_repo))
                            .font(.system(size: theme.textSize, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(i18n.t(.fc_github_repo_desc))
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                HStack(spacing: theme.spacingS) {
                    Text(i18n.t(.fc_url))
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("https://github.com/user/repo", text: $gitURL)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.smallTextSize, design: .monospaced))
                        .padding(theme.spacingS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(gitURL.isEmpty ? theme.inputBorder : (isValidGitURL ? theme.accent : theme.accentDestructive), lineWidth: 1)
                        }
                }

                HStack(spacing: theme.spacingS) {
                    Text(i18n.t(.fc_branch))
                        .font(.system(size: theme.footnoteSize, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("main", text: $gitBranch)
                        .textFieldStyle(.plain)
                        .font(.system(size: theme.smallTextSize))
                        .padding(theme.spacingS)
                        .background(theme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                                .stroke(theme.inputBorder, lineWidth: 1)
                        }
                }

                if let error = cloneError {
                    HStack(spacing: theme.spacingXS) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.accentDestructive)
                        Text(error)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.errorText)
                    }
                }

                HStack {
                    Spacer()
                    FusionButton(i18n.t(.fc_clone_open), icon: "arrow.down.circle", style: .primary, size: .regular, isLoading: isCloning, isDisabled: !isValidGitURL) {
                        cloneRepo()
                    }
                }
            }
        }
    }

    private var dividerOr: some View {
        HStack(spacing: theme.spacingM) {
            Rectangle().fill(theme.separator).frame(height: 0.5)
            Text(i18n.t(.fc_or))
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Rectangle().fill(theme.separator).frame(height: 0.5)
        }
    }

    private var dropZone: some View {
        VStack(spacing: theme.spacingS) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: theme.iconXL))
                .foregroundStyle(theme.textTertiary)
            Text(i18n.t(.fc_drop_here))
                .font(.system(size: theme.smallTextSize))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingXL)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(theme.inputBorder)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var isValidGitURL: Bool {
        let url = gitURL.trimmingCharacters(in: .whitespaces)
        return url.hasPrefix("https://github.com/") || url.hasPrefix("https://gitlab.com/") || url.hasPrefix("git@")
    }

    private func cloneRepo() {
        isCloning = true
        cloneError = nil
        let url = gitURL.trimmingCharacters(in: .whitespaces)
        let branch = gitBranch.trimmingCharacters(in: .whitespaces).isEmpty ? "main" : gitBranch

        // BUG-10: argv 防 shell 注入但不防选项注入 — url/branch 以 `--` 开头会被 git 解释为选项,
        // 如 branch="--upload-pack=evil" 或 url="--config core.sshCommand=..." -> argument injection。
        // 拦: url 须匹配 https/git/ssh 协议前缀或 git@ 形式; branch 须安全 ref-name (字母数字._/-, 不以 - 开头)。
        if url.hasPrefix("-") || branch.hasPrefix("-") {
            cloneError = "URL/分支不能以 -- 开头"
            isCloning = false
            return
        }
        let urlPattern = #"^(https://|http://|git://|ssh://|git@)[A-Za-z0-9._:@/~%?#&=+-]+"#
        guard let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: []),
              urlRegex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil else {
            cloneError = "仓库 URL 协议不受支持 (仅 https/git/ssh/git@)"
            isCloning = false
            return
        }
        let refPattern = #"^[A-Za-z0-9][A-Za-z0-9._/-]*$"#
        guard let refRegex = try? NSRegularExpression(pattern: refPattern, options: []),
              refRegex.firstMatch(in: branch, range: NSRange(branch.startIndex..., in: branch)) != nil else {
            cloneError = "分支名含非法字符"
            isCloning = false
            return
        }

        Task { @MainActor in
            let workspaceDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("fusion-workspace")
            try? FileManager.default.createDirectory(at: workspaceDir, withIntermediateDirectories: true)

            let repoName = URL(string: url)?.deletingPathExtension().lastPathComponent ?? "repo-\(UUID().uuidString.prefix(6))"
            let targetDir = workspaceDir.appendingPathComponent(repoName)

            // BUG-12: 旧实现 waitUntilExit 在 @MainActor Task 内阻塞主线程, 且 stderr 在 wait 后才读 ->
            // git 进度走 stderr 超 64KB 管道缓冲则写端阻塞, git 不退出, waitUntilExit 永挂, 主线程同时冻死。
            // 修正: git 进程移到后台 Task.detached, stdout/stderr 各起后台 Task 并发 readDataToEndOfFile
            // (阻塞各自线程至 EOF, 互不阻塞写端, 管道满即被消费), 两 drain 完成即进程已退出 (EOF 发生于
            // 进程关闭管道时), 读 terminationStatus 非阻塞, 无需 waitUntilExit/DispatchGroup.wait。
            let result: (Int32, String?) = await Task.detached(priority: .userInitiated) {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                // `--` 分隔符后位置参数, 双保险防 url/branch 被当选项 (BUG-10 纵深防御, 校验已在上层拦)。
                process.arguments = ["clone", "-b", branch, "--", url, targetDir.path]
                process.currentDirectoryURL = workspaceDir

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    // 并发 drain: readDataToEndOfFile 阻塞至 EOF (进程关闭管道), 两 Task 互不互锁写端。
                    async let stdoutData = Task.detached { outputPipe.fileHandleForReading.readDataToEndOfFile() }.value
                    async let stderrData = Task.detached { errorPipe.fileHandleForReading.readDataToEndOfFile() }.value
                    _ = await stdoutData
                    let errBytes = await stderrData
                    // 两 pipe EOF = 进程已关闭管道, terminationStatus 此时已就绪, 非阻塞读。
                    if process.terminationStatus == 0 {
                        return (0, nil)
                    }
                    let msg = String(data: errBytes, encoding: .utf8) ?? "Clone failed with exit code \(process.terminationStatus)"
                    return (process.terminationStatus, msg)
                } catch {
                    return (-1, error.localizedDescription)
                }
            }.value

            if result.0 == 0 {
                workspace.loadProject(from: targetDir)
                dismiss()
            } else {
                cloneError = result.1 ?? "Clone failed"
            }
            isCloning = false
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { data, _ in
            guard let data = data as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        workspace.loadProject(from: url)
                    } else {
                        workspace.loadSingleFile(from: url)
                    }
                    if workspace.hasProject { dismiss() }
                }
            }
        }
        return true
    }
}
