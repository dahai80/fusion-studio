// Callers: ArtifactVersionHistorySheet (diff button on version row), ArtifactsPanel.
// Affected API: ArtifactVersionDiffView (new View), IPCClient.artifactsCall (existing method).
// Data schemas: DiffLine (type/lineNums/content), DiffResult (additions/deletions/lines), DiffLineType. LCS-based diff.
// User instruction: "启动 Phase 4" — Task #49 ArtifactVersionDiff 版本差异可视化

import SwiftUI
import os.log

private let diffLog = Logger(subsystem: "com.fusion.studio", category: "ArtifactVersionDiff")

struct DiffLineType: Equatable {
    let rawValue: String
    static let unchanged = DiffLineType(rawValue: "unchanged")
    static let added = DiffLineType(rawValue: "added")
    static let deleted = DiffLineType(rawValue: "deleted")
}

struct DiffLine: Identifiable {
    let id = UUID()
    let type: DiffLineType
    let oldLineNum: Int?
    let newLineNum: Int?
    let content: String
}

struct DiffResult {
    let additions: Int
    let deletions: Int
    let lines: [DiffLine]
}

struct ArtifactVersionDiffView: View {
    @Environment(\.studioTheme) private var theme
    @EnvironmentObject var ipcClient: IPCClient

    let leftVersionId: Int
    let rightVersionId: Int
    let artifactName: String

    @State private var leftContent: String = ""
    @State private var rightContent: String = ""
    @State private var diffResult: DiffResult?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            diffHeader
            Rectangle().fill(theme.separator).frame(height: 1)
            if isLoading {
                Spacer()
                ProgressView("Comparing versions...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: theme.spacingM) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else if let diff = diffResult {
                diffStatsBar(diff)
                Rectangle().fill(theme.separator).frame(height: 1)
                diffContent(diff)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear { loadAndDiff() }
    }

    private var diffHeader: some View {
        HStack(spacing: theme.spacingM) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Version Diff")
                    .font(.system(size: theme.titleSize, weight: .semibold))
                    .foregroundStyle(theme.text)
                Text(artifactName)
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        }
        .padding(theme.spacingL)
        .background(theme.surfaceElevated)
    }

    private func diffStatsBar(_ diff: DiffResult) -> some View {
        HStack(spacing: theme.spacingL) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .cornerRadius(2)
                Text("+\(diff.additions)")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(.green)
            }
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.red.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .cornerRadius(2)
                Text("-\(diff.deletions)")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(.red)
            }
            Spacer()
            Text("v\(leftVersionId) → v\(rightVersionId)")
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingXS + 2)
        .background(theme.surfaceSecondary)
    }

    private func diffContent(_ diff: DiffResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(diff.lines) { line in
                    diffLineRow(line)
                }
            }
        }
    }

    private func diffLineRow(_ line: DiffLine) -> some View {
        let bgColor: Color = {
            switch line.type {
            case .added: return Color.green.opacity(0.08)
            case .deleted: return Color.red.opacity(0.08)
            default: return Color.clear
            }
        }()
        let indicatorColor: Color = {
            switch line.type {
            case .added: return Color.green.opacity(0.5)
            case .deleted: return Color.red.opacity(0.5)
            default: return Color.clear
            }
        }()
        let prefix: String = {
            switch line.type {
            case .added: return "+"
            case .deleted: return "-"
            default: return " "
            }
        }()

        return HStack(spacing: 0) {
            Rectangle()
                .fill(indicatorColor)
                .frame(width: 3)
            Text(line.oldLineNum.map { "\($0)" } ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 32, alignment: .trailing)
            Text(line.newLineNum.map { "\($0)" } ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .frame(width: 32, alignment: .trailing)
            Text(prefix)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(line.type == .added ? .green : line.type == .deleted ? .red : theme.textTertiary)
                .frame(width: 14)
            Text(line.content)
                .font(.system(size: theme.captionSize, design: .monospaced))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(bgColor)
    }

    private func loadAndDiff() {
        Task {
            do {
                let left = try await fetchVersionContent(versionId: leftVersionId)
                let right = try await fetchVersionContent(versionId: rightVersionId)
                leftContent = left
                rightContent = right
                diffResult = computeDiff(oldText: left, newText: right)
                isLoading = false
                diffLog.info("Diff computed: v\(self.leftVersionId)→v\(self.rightVersionId)")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                diffLog.error("Diff load failed: \(error)")
            }
        }
    }

    private func fetchVersionContent(versionId: Int) async throws -> String {
        let sessionId = "diff-\(UUID().uuidString.prefix(8))"
        let result = try await ipcClient.artifactsCall(
            method: "artifact.get_version_content",
            params: [
                "version_id": versionId,
                "session_id": sessionId
            ]
        )
        if let content = result["content"] as? String {
            return content
        }
        return ""
    }

    private func computeDiff(oldText: String, newText: String) -> DiffResult {
        let oldLines = oldText.components(separatedBy: "\n")
        let newLines = newText.components(separatedBy: "\n")
        var lines: [DiffLine] = []
        var additions = 0
        var deletions = 0

        let lcs = longestCommonSubsequence(oldLines, newLines)
        var oi = 0, ni = 0, li = 0

        while oi < oldLines.count || ni < newLines.count {
            if li < lcs.count && oi < oldLines.count && ni < newLines.count
                && oldLines[oi] == lcs[li] && newLines[ni] == lcs[li] {
                lines.append(DiffLine(type: .unchanged, oldLineNum: oi + 1, newLineNum: ni + 1, content: oldLines[oi]))
                oi += 1; ni += 1; li += 1
            } else if oi < oldLines.count && (li >= lcs.count || oldLines[oi] != lcs[li]) {
                lines.append(DiffLine(type: .deleted, oldLineNum: oi + 1, newLineNum: nil, content: oldLines[oi]))
                oi += 1; deletions += 1
            } else if ni < newLines.count && (li >= lcs.count || newLines[ni] != lcs[li]) {
                lines.append(DiffLine(type: .added, oldLineNum: nil, newLineNum: ni + 1, content: newLines[ni]))
                ni += 1; additions += 1
            } else {
                break
            }
        }

        while oi < oldLines.count {
            lines.append(DiffLine(type: .deleted, oldLineNum: oi + 1, newLineNum: nil, content: oldLines[oi]))
            oi += 1; deletions += 1
        }
        while ni < newLines.count {
            lines.append(DiffLine(type: .added, oldLineNum: nil, newLineNum: ni + 1, content: newLines[ni]))
            ni += 1; additions += 1
        }

        return DiffResult(additions: additions, deletions: deletions, lines: lines)
    }

    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
        let m = a.count, n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        var result: [String] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if a[i - 1] == b[j - 1] {
                result.append(a[i - 1])
                i -= 1; j -= 1
            } else if dp[i - 1][j] > dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return result.reversed()
    }
}
