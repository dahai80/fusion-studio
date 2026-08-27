import SwiftUI
import os.log

private let spaceLog = Logger(subsystem: "com.fusion.studio", category: "CoWork.Space")

// MARK: - Page 7.5: 深度研究

struct SpaceDeepResearchView: View {
    @EnvironmentObject var ipc: IPCClient
    @Environment(\.studioTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @StateObject private var i18n = I18nManager.shared

    let spaceId: String

    @State private var query = ""
    @State private var depth = 2
    @State private var isRunning = false
    @State private var result: [String: Any]?
    @State private var resultText = ""
    @State private var agentTracks: [ResearchAgentTrack] = []
    @State private var useMultiAgent = true
    @State private var availableAgents: [SpaceAgent] = []
    @State private var selectedAgentIds: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack {
                Text(i18n.t(.cw_main_deepResearch))
                    .font(.system(size: theme.headlineSize, weight: .bold))
                Spacer()
                if isRunning {
                    HStack(spacing: 4) {
                        ProgressView().controlSize(.small)
                        Text(i18n.t(.cw_research_running))
                            .font(.system(size: 9))
                            .foregroundStyle(theme.accent)
                    }
                }
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: theme.spacingS) {
                TextField(i18n.t(.cw_research_queryPh), text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker(i18n.t(.cw_research_depth), selection: $depth) {
                    Text(i18n.t(.cw_research_depthShallow)).tag(1)
                    Text(i18n.t(.cw_research_depthMedium)).tag(2)
                    Text(i18n.t(.cw_research_depthDeep)).tag(3)
                }
                .frame(width: 80)
                Button(i18n.t(.cw_research_start)) { startResearch() }
                    .disabled(query.isEmpty || isRunning)
            }

            HStack(spacing: theme.spacingM) {
                Toggle(isOn: $useMultiAgent) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: theme.iconXS))
                        Text(i18n.t(.cw_research_multiAgent))
                            .font(.system(size: theme.captionSize))
                    }
                }
                .toggleStyle(.checkbox)
                if useMultiAgent && !availableAgents.isEmpty {
                    Menu {
                        ForEach(availableAgents) { agent in
                            Button(action: {
                                if selectedAgentIds.contains(agent.id) {
                                    selectedAgentIds.removeAll { $0 == agent.id }
                                } else {
                                    selectedAgentIds.append(agent.id)
                                }
                            }) {
                                HStack {
                                    Text(agent.name)
                                    if selectedAgentIds.contains(agent.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 9))
                            Text(selectedAgentIds.isEmpty ? i18n.t(.cw_research_autoSelect) : String(format: i18n.t(.cw_research_agentCountFmt), selectedAgentIds.count))
                                .font(.system(size: 9))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(theme.accent)
                    }
                }
                Spacer()
                Text(i18n.t(.cw_research_zeroToken))
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
            }

            if isRunning && !agentTracks.isEmpty {
                multiAgentProgressView
            } else if isRunning {
                VStack(spacing: theme.spacingS) {
                    ProgressView()
                    Text(i18n.t(.cw_research_runningProgress))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !resultText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingM) {
                        if !agentTracks.filter({ !$0.result.isEmpty }).isEmpty {
                            researchTrackSummary
                            Divider()
                        }
                        MarkdownContentView(content: resultText)
                    }
                    .padding(theme.spacingM)
                }
            } else {
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "telescope")
                        .font(.system(size: 30))
                        .foregroundStyle(theme.textTertiary)
                    Text(i18n.t(.cw_research_desc))
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Text(i18n.t(.cw_research_vsClaude))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.accent)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(theme.spacingL)
        .frame(width: 640, height: 560)
        .onAppear { loadAgents() }
    }

    private var researchTrackSummary: some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(i18n.t(.cw_research_track))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(agentTracks.filter { !$0.result.isEmpty }) { track in
                HStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: theme.iconS))
                        .foregroundStyle(.green)
                    Text(track.agentName)
                        .font(.system(size: theme.captionSize, weight: .medium))
                    Text(track.result.prefix(80) + (track.result.count > 80 ? "..." : ""))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(2)
                }
            }
        }
    }

    private var multiAgentProgressView: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            Text(i18n.t(.cw_research_agentProgress))
                .font(.system(size: theme.footnoteSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(agentTracks) { track in
                HStack(spacing: theme.spacingS) {
                    if track.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: theme.iconS))
                            .foregroundStyle(.green)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Text(track.agentName)
                        .font(.system(size: theme.captionSize, weight: .medium))
                    Text(track.status)
                        .font(.system(size: 9))
                        .foregroundStyle(track.isComplete ? .green : theme.textTertiary)
                    Spacer()
                }
            }
        }
        .padding(theme.spacingM)
    }

    private func loadAgents() {
        Task {
            do {
                let result = try await ipc.spaceAgentList(spaceId: spaceId)
                let items = result["agents"] as? [[String: Any]] ?? []
                await MainActor.run { availableAgents = items.map { SpaceAgent.fromDict($0) } }
            } catch {
                spaceLog.error("agent.list for research failed: \(error.localizedDescription)")
            }
        }
    }

    private func startResearch() {
        isRunning = true
        resultText = ""
        agentTracks = []

        if useMultiAgent && (selectedAgentIds.count >= 2 || (selectedAgentIds.isEmpty && availableAgents.count >= 2)) {
            startMultiAgentResearch()
        } else {
            startSingleResearch()
        }
    }

    private func startSingleResearch() {
        Task {
            do {
                let r = try await ipc.spaceDeepResearch(spaceId: spaceId, query: query, depth: depth)
                await MainActor.run {
                    result = r
                    resultText = r["summary"] as? String ?? r["content"] as? String ?? i18n.t(.cw_research_noResult)
                    isRunning = false
                }
            } catch {
                spaceLog.error("deep.research failed: \(error.localizedDescription)")
                await MainActor.run {
                    resultText = String(format: i18n.t(.cw_research_failFmt), error.localizedDescription)
                    isRunning = false
                }
            }
        }
    }

    private func startMultiAgentResearch() {
        let agents = selectedAgentIds.isEmpty
            ? Array(availableAgents.prefix(3))
            : availableAgents.filter { selectedAgentIds.contains($0.id) }

        agentTracks = agents.map { ResearchAgentTrack(agentId: $0.id, agentName: $0.name) }

        Task {
            var responses: [[String: Any]?] = []
            for agent in agents {
                let resp = try? await ipc.spaceAgentCall(
                    spaceId: spaceId, agentId: agent.id,
                    message: i18n.tf(.spl_deep_research_fmt, depth, query)
                )
                responses.append(resp)
                await MainActor.run {
                    if let idx = agentTracks.firstIndex(where: { $0.agentId == agent.id }) {
                        let content = resp?["content"] as? String ?? resp?["response"] as? String ?? ""
                        agentTracks[idx].result = content
                        agentTracks[idx].isComplete = true
                        agentTracks[idx].status = i18n.t(.cw_research_done)
                    }
                }
            }
            await MainActor.run {
                var combinedText = ""
                for track in agentTracks where !track.result.isEmpty {
                    combinedText += "### \(track.agentName)\n\n\(track.result)\n\n---\n\n"
                }
                resultText = combinedText
                isRunning = false
            }
            spaceLog.info("Multi-agent deep research completed with \(agents.count) agents")
        }
    }
}

private struct ResearchAgentTrack: Identifiable {
    let id = UUID().uuidString
    let agentId: String
    let agentName: String
    var status: String = I18nManager.shared.t(.cw_research_runningStatus)
    var result: String = ""
    var isComplete: Bool = false
}

