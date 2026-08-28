import SwiftUI
import Combine
import os.log

// MARK: - TeamTabView

struct TeamTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showOrchestrateSheet = false
    @State private var orchestrateTask = ""
    @State private var selectedAgentIds: Set<String> = []
    @State private var orchestrateMode = "sequential"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Multi-Agent Team")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Orchestrate", icon: "play.circle") { showOrchestrateSheet = true }
            }
            .padding(theme.spacingM)

            StudioSectionHeader(title: "Swarm Agents")
            if bridge.configState.swarmAgents.isEmpty {
                Text("No swarm agents registered")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.swarmAgents.enumerated()), id: \.offset) { idx, agent in
                        let name = agent["name"] as? String ?? agent["agent_id"] as? String ?? "Unknown"
                        let role = agent["role"] as? String ?? "worker"
                        let status = agent["status"] as? String ?? "idle"
                        StudioRow(label: name, sublabel: role, isLast: idx == bridge.configState.swarmAgents.count - 1) {
                            FusionTag(status, color: status == "active" ? .green : .gray)
                        }
                    }
                }
            }

            StudioSectionHeader(title: "Plaza Channels")
            if bridge.configState.plazaChannels.isEmpty {
                Text("No plaza channels")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.plazaChannels.enumerated()), id: \.offset) { idx, ch in
                        let name = ch["name"] as? String ?? "Unknown"
                        let desc = ch["description"] as? String ?? ""
                        StudioRow(label: name, sublabel: desc, isLast: idx == bridge.configState.plazaChannels.count - 1) {
                            FusionTag("channel", color: .purple)
                        }
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            Task {
                await bridge.fetchSwarmAgents()
                await bridge.fetchPlazaChannels()
            }
        }
        .sheet(isPresented: $showOrchestrateSheet) {
            orchestrateSheet
        }
    }

    private var orchestrateSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Orchestrate Task")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Task description", text: $orchestrateTask, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            Picker("Mode", selection: $orchestrateMode) {
                Text("Sequential").tag("sequential")
                Text("Parallel").tag("parallel")
                Text("Swarm").tag("swarm")
            }
            .pickerStyle(.segmented)
            Text("Select agents:")
                .font(.system(size: theme.captionSize))
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bridge.agentState.agents) { agent in
                        HStack {
                            Image(systemName: selectedAgentIds.contains(agent.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(theme.accent)
                            Text(agent.name)
                                .font(.system(size: theme.textSize))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedAgentIds.contains(agent.id) {
                                selectedAgentIds.remove(agent.id)
                            } else {
                                selectedAgentIds.insert(agent.id)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
            HStack {
                FusionButton("Cancel") { showOrchestrateSheet = false }
                Spacer()
                FusionButton("Run", icon: "play") {
                    Task { await runOrchestration() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 500)
    }

    private func runOrchestration() async {
        guard !orchestrateTask.isEmpty, !selectedAgentIds.isEmpty else { return }
        do {
            let result = try await bridge.teamOrchestrate(task: orchestrateTask, agentIds: Array(selectedAgentIds), mode: orchestrateMode)
            let status = result["status"] as? String ?? "started"
            toastManager.show(style: .success, title: "Orchestration \(status)", message: orchestrateTask)
            showOrchestrateSheet = false
            orchestrateTask = ""
            selectedAgentIds.removeAll()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}
