import SwiftUI
import os.log

// #418 Mobile Cowork panel: read-only overview plus steering actions backed by
// fusion-cowork web API. Runs on desktop but mirrors the mobile surface contract.
private let coworkMobileViewLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Mobile.View")

struct CoworkMobileView: View {
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    @State private var runs: [[String: Any]] = []
    @State private var approvals: [[String: Any]] = []
    @State private var selectedRunId: String?
    @State private var artifacts: [[String: Any]] = []
    @State private var isLoading = false
    @State private var actionInProgress = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var previewArtifact: [String: Any]?
    @State private var showPreview = false

    @State private var directiveAction: MobileDirectiveAction = .skipRemaining
    @State private var nodeIdText = ""
    @State private var paramsText = "{\n    \"prompt\": \"\"\n}"
    @State private var insertNodeText = "{\n    \"name\": \"llm\",\n    \"label\": \"\",\n    \"params\": {}\n}"

    private var bridge: CoworkMobileBridge { CoworkMobileBridge() }

    private var selectedRun: [String: Any]? {
        guard let selectedRunId else { return nil }
        return runs.first { ($0["run_id"] as? String) == selectedRunId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(theme.separator).frame(height: 1)
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(theme.separator).frame(width: 1)
                detail
            }
        }
        .frame(minWidth: 880, minHeight: 620)
        .task { await refresh() }
        .sheet(isPresented: $showPreview) {
            artifactPreview
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: theme.spacingS) {
                Image(systemName: "iphone.gen3")
                    .foregroundStyle(theme.accent)
                Text(i18n.t(.cw_mobile_title))
                    .font(.headline)
                if isLoading || actionInProgress {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Label(i18n.t(.cw_mobile_refresh), systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(isLoading || actionInProgress)
                Button {
                    dismiss()
                } label: {
                    Label(i18n.t(.cw_mobile_close), systemImage: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
            Text(i18n.t(.cw_mobile_subtitle))
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(theme.accent)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(theme.accentDestructive)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.spacingL)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                runsSection
                approvalsSection
            }
            .padding(theme.spacingM)
        }
        .frame(width: 320)
    }

    private var runsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            sectionTitle(i18n.t(.cw_mobile_runs), count: runs.count)
            if runs.isEmpty {
                emptyHint(i18n.t(.cw_mobile_noRuns))
            } else {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                    runRow(run)
                }
            }
        }
    }

    private func runRow(_ run: [String: Any]) -> some View {
        let runId = run["run_id"] as? String ?? ""
        let isSelected = selectedRunId == runId
        let status = run["status"] as? String ?? ""
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(run["workflow_name"] as? String ?? runId)
                    .font(.system(size: theme.textSize, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accent : theme.text)
                    .lineLimit(1)
                Spacer()
                statusBadge(status)
            }
            Text(runId)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            if let error = run["error"] as? String, !error.isEmpty {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(theme.accentDestructive)
                    .lineLimit(2)
            }
        }
        .padding(theme.spacingS)
        .background(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(isSelected ? theme.accent.opacity(0.12) : theme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .stroke(isSelected ? theme.accent.opacity(0.3) : theme.separator, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectRun(runId) }
    }

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            sectionTitle(i18n.t(.cw_mobile_approvals), count: approvals.count)
            if approvals.isEmpty {
                emptyHint(i18n.t(.cw_mobile_noApprovals))
            } else {
                ForEach(Array(approvals.enumerated()), id: \.offset) { _, approval in
                    approvalRow(approval)
                }
            }
        }
    }

    private func approvalRow(_ approval: [String: Any]) -> some View {
        let actionId = approval["action_id"] as? String ?? ""
        let toolName = approval["tool_name"] as? String ?? ""
        let source = approval["source"] as? String ?? ""
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(toolName)
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if !source.isEmpty {
                    Text(source)
                        .font(.system(size: 9))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(theme.surfaceSecondary))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            Text(actionId)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
            HStack(spacing: theme.spacingS) {
                Button(i18n.t(.cw_mobile_approve)) {
                    Task { await confirm(actionId: actionId, approved: true) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .disabled(actionInProgress || actionId.isEmpty)
                Button(i18n.t(.cw_mobile_reject)) {
                    Task { await confirm(actionId: actionId, approved: false) }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(actionInProgress || actionId.isEmpty)
            }
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
    }

    @ViewBuilder
    private var detail: some View {
        if let run = selectedRun {
            runDetail(run)
        } else {
            VStack(spacing: theme.spacingS) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 32))
                    .foregroundStyle(theme.textTertiary)
                Text(i18n.t(.cw_mobile_noSelection))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func runDetail(_ run: [String: Any]) -> some View {
        let runId = run["run_id"] as? String ?? ""
        let status = run["status"] as? String ?? ""
        return ScrollView {
            VStack(alignment: .leading, spacing: theme.spacingL) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: theme.spacingS) {
                        Text(run["workflow_name"] as? String ?? i18n.t(.cw_mobile_runs))
                            .font(.title3.weight(.semibold))
                        statusBadge(status)
                        Spacer()
                        if status == "running" {
                            Button(i18n.t(.cw_mobile_pause)) {
                                Task { await pause(runId) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(actionInProgress)
                        }
                        if status == "paused" {
                            Button(i18n.t(.cw_mobile_resume)) {
                                Task { await resume(runId) }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(actionInProgress)
                        }
                    }
                    Text(runId)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                        .textSelection(.enabled)
                    if let error = run["error"] as? String, !error.isEmpty {
                        Text("\(i18n.t(.cw_mobile_error)): \(error)")
                            .font(.caption)
                            .foregroundStyle(theme.accentDestructive)
                            .textSelection(.enabled)
                    }
                }

                steerSection(runId: runId)
                artifactsSection
            }
            .padding(theme.spacingL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func steerSection(runId: String) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            sectionTitle(i18n.t(.cw_mobile_steer), count: nil)
            Picker("", selection: $directiveAction) {
                ForEach(MobileDirectiveAction.allCases) { action in
                    Text(action.label(i18n)).tag(action)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if directiveAction != .skipRemaining {
                HStack(spacing: theme.spacingS) {
                    Text(directiveAction == .setParams ? i18n.t(.cw_mobile_nodeId) : "After node")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 90, alignment: .leading)
                    TextField("node_id", text: $nodeIdText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }
            }

            if directiveAction == .setParams {
                jsonEditor(title: i18n.t(.cw_mobile_paramsJson), text: $paramsText)
            }
            if directiveAction == .insertNode {
                jsonEditor(title: i18n.t(.cw_mobile_insertJson), text: $insertNodeText)
            }

            HStack {
                Spacer()
                Button(i18n.t(.cw_mobile_send)) {
                    Task { await sendDirective(runId: runId) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(actionInProgress)
            }
        }
        .padding(theme.spacingM)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadius).fill(theme.surfaceSecondary))
    }

    private func jsonEditor(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 70)
                .scrollContentBackground(.hidden)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.inputBg))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .stroke(theme.inputBorder, lineWidth: 1)
                )
        }
    }

    private var artifactsSection: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            sectionTitle(i18n.t(.cw_mobile_artifacts), count: artifacts.count)
            if artifacts.isEmpty {
                emptyHint(i18n.t(.cw_mobile_noArtifacts))
            } else {
                ForEach(Array(artifacts.enumerated()), id: \.offset) { _, artifact in
                    artifactRow(artifact)
                }
            }
        }
    }

    private func artifactRow(_ artifact: [String: Any]) -> some View {
        let type = artifact["type"] as? String ?? ""
        let content = artifact["content"] as? String ?? ""
        let path = artifact["path"] as? String ?? ""
        let truncated = artifact["truncated"] as? Bool ?? false
        return HStack(spacing: theme.spacingS) {
            Image(systemName: artifactIcon(type))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(artifact["name"] as? String ?? artifact["artifact_id"] as? String ?? "")
                    .font(.system(size: theme.captionSize, weight: .medium))
                    .lineLimit(1)
                Text(path.isEmpty ? type : path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if truncated {
                Text(i18n.t(.cw_mobile_truncated))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }
            Button(i18n.t(.cw_mobile_preview)) {
                previewArtifact = artifact
                showPreview = true
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .disabled(content.isEmpty && path.isEmpty)
        }
        .padding(theme.spacingS)
        .background(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall).fill(theme.surfaceSecondary))
    }

    private var artifactPreview: some View {
        let artifact = previewArtifact ?? [:]
        let content = artifact["content"] as? String ?? ""
        let path = artifact["path"] as? String ?? ""
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(artifact["name"] as? String ?? i18n.t(.cw_mobile_preview))
                    .font(.headline)
                Spacer()
                Button(i18n.t(.cw_mobile_close)) { showPreview = false }
                    .buttonStyle(.plain)
            }
            .padding(theme.spacingL)
            if !path.isEmpty {
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                    .textSelection(.enabled)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingS)
            }
            Rectangle().fill(theme.separator).frame(height: 1)
            ScrollView([.vertical, .horizontal]) {
                Text(content.isEmpty ? path : content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(theme.spacingL)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }

    private func sectionTitle(_ title: String, count: Int?) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            if let count {
                Text("\(count)")
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(theme.accent.opacity(0.15)))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(theme.textTertiary)
            .padding(.vertical, 4)
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running": return theme.accent
        case "paused": return .orange
        case "completed", "success": return .green
        case "failed", "error", "cancelled": return theme.accentDestructive
        default: return theme.textSecondary
        }
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "diff": return "plus.forwardslash.minus"
        case "markdown", "report": return "doc.richtext"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "image": return "photo"
        default: return "doc"
        }
    }

    private func selectRun(_ runId: String) {
        selectedRunId = runId
        artifacts = []
        Task { await loadArtifacts(runId) }
    }

    private func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let overview = try await bridge.overview()
            runs = overview.runs
            approvals = overview.pendingApprovals
            if let selectedRunId, !runs.contains(where: { ($0["run_id"] as? String) == selectedRunId }) {
                self.selectedRunId = nil
                artifacts = []
            }
            if self.selectedRunId == nil, let first = runs.first?["run_id"] as? String {
                self.selectedRunId = first
                await loadArtifacts(first)
            } else if let selectedRunId {
                await loadArtifacts(selectedRunId)
            }
            coworkMobileViewLog.info("overview loaded runs=\(self.runs.count) approvals=\(self.approvals.count)")
        } catch {
            errorMessage = "\(i18n.t(.cw_mobile_loadFail)): \(error.localizedDescription)"
            coworkMobileViewLog.error("overview failed: \(error.localizedDescription, privacy: .public)")
        }
        isLoading = false
    }

    private func loadArtifacts(_ runId: String) async {
        do {
            let loaded = try await bridge.artifacts(runId: runId)
            if selectedRunId == runId {
                artifacts = loaded
            }
        } catch {
            coworkMobileViewLog.error("artifacts failed run=\(runId, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if selectedRunId == runId {
                artifacts = []
            }
        }
    }

    private func confirm(actionId: String, approved: Bool) async {
        actionInProgress = true
        errorMessage = nil
        do {
            _ = try await bridge.confirm(actionId: actionId, approved: approved)
            statusMessage = approved ? i18n.t(.cw_mobile_approve) : i18n.t(.cw_mobile_reject)
            await refresh()
        } catch {
            errorMessage = "\(i18n.t(.cw_mobile_actionFail)): \(error.localizedDescription)"
            coworkMobileViewLog.error("confirm failed: \(error.localizedDescription, privacy: .public)")
        }
        actionInProgress = false
    }

    private func pause(_ runId: String) async {
        await performRunAction(i18n.t(.cw_mobile_pause)) {
            _ = try await bridge.pause(runId: runId)
        }
    }

    private func resume(_ runId: String) async {
        await performRunAction(i18n.t(.cw_mobile_resume)) {
            _ = try await bridge.resume(runId: runId)
        }
    }

    private func performRunAction(_ label: String, operation: @escaping () async throws -> Void) async {
        actionInProgress = true
        errorMessage = nil
        do {
            try await operation()
            statusMessage = label
            await refresh()
        } catch {
            errorMessage = "\(i18n.t(.cw_mobile_actionFail)): \(error.localizedDescription)"
            coworkMobileViewLog.error("run action \(label, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
        actionInProgress = false
    }

    private func sendDirective(runId: String) async {
        var body: [String: Any] = ["action": directiveAction.rawValue]
        switch directiveAction {
        case .skipRemaining:
            break
        case .setParams:
            guard let params = parseJSONObject(paramsText) else {
                errorMessage = i18n.t(.cw_mobile_jsonInvalid)
                return
            }
            body["params"] = params
            if !nodeIdText.trimmingCharacters(in: .whitespaces).isEmpty {
                body["node_id"] = nodeIdText.trimmingCharacters(in: .whitespaces)
            }
        case .insertNode:
            guard let spec = parseJSONObject(insertNodeText) else {
                errorMessage = i18n.t(.cw_mobile_jsonInvalid)
                return
            }
            body["node"] = spec
            if !nodeIdText.trimmingCharacters(in: .whitespaces).isEmpty {
                body["after_node_id"] = nodeIdText.trimmingCharacters(in: .whitespaces)
            }
        }

        actionInProgress = true
        errorMessage = nil
        do {
            let result = try await bridge.directive(runId: runId, body: body)
            let status = result["status"] as? String ?? "queued"
            statusMessage = "\(i18n.t(.cw_mobile_steer)): \(status)"
            await refresh()
        } catch {
            errorMessage = "\(i18n.t(.cw_mobile_actionFail)): \(error.localizedDescription)"
            coworkMobileViewLog.error("directive failed: \(error.localizedDescription, privacy: .public)")
        }
        actionInProgress = false
    }

    private func parseJSONObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }
}

private enum MobileDirectiveAction: String, CaseIterable, Identifiable {
    case skipRemaining = "skip_remaining"
    case setParams = "set_params"
    case insertNode = "insert_node"

    var id: String { rawValue }

    func label(_ i18n: I18nManager) -> String {
        switch self {
        case .skipRemaining: return i18n.t(.cw_mobile_skipRemaining)
        case .setParams: return i18n.t(.cw_mobile_setParams)
        case .insertNode: return i18n.t(.cw_mobile_insertNode)
        }
    }
}
