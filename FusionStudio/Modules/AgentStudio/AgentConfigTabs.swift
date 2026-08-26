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

// MARK: - CronTabView

struct CronTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedTaskId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scheduled Tasks")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Text("Cron jobs registered by Task → Schedule / Once. Create tasks in the Tasks tab.")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
                FusionButton("Refresh", icon: "arrow.clockwise", style: .secondary, size: .small) {
                    Task { await bridge.fetchCronJobs() }
                }
            }
            .padding(theme.spacingM)

            if bridge.configState.cronJobs.isEmpty {
                Spacer()
                Image(systemName: "clock.badge.xmark")
                    .font(.system(size: 36))
                    .foregroundStyle(theme.textTertiary)
                Text("No scheduled tasks")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, theme.spacingS)
                Text("Create a Task with Schedule or Once trigger to add a cron job.")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacingXL)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.cronJobs.enumerated()), id: \.offset) { idx, job in
                        cronRow(job, isLast: idx == bridge.configState.cronJobs.count - 1)
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchCronJobs() } }
        .sheet(item: Binding(
            get: { selectedTaskId.map { IdentifiableString(value: $0) } },
            set: { selectedTaskId = $0?.value }
        )) { wrap in
            AgentTaskDetailView(taskId: wrap.value, toastManager: toastManager)
        }
    }

    private func cronRow(_ job: [String: Any], isLast: Bool) -> some View {
        let name = job["name"] as? String ?? "Unknown"
        let expression = job["expression"] as? String ?? (job["schedule"] as? String ?? "")
        let cronId = job["id"] as? String ?? job["cron_id"] as? String ?? ""
        let enabled = job["enabled"] as? Bool ?? true
        let nextRun = job["next_run"] as? Double ?? 0
        let graphId = job["graph_id"] as? String ?? ""
        let inputRaw = job["input_data"] as? String ?? ""
        let linkedTaskId = parseTaskId(from: inputRaw)
        let linkedTask = linkedTaskId.flatMap { id in bridge.taskState.tasks.first(where: { $0.id == id }) }

        return StudioRow(
            label: name,
            sublabel: rowSublabel(expression: expression, graphId: graphId, linkedTask: linkedTask, linkedTaskId: linkedTaskId, nextRun: nextRun),
            isLast: isLast
        ) {
            FusionTag(enabled ? "active" : "paused", color: enabled ? .green : .gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let tid = linkedTaskId { selectedTaskId = tid }
        }
        .contextMenu {
            if let tid = linkedTaskId {
                Button("Open Task") { selectedTaskId = tid }
            }
            Button("Unregister", role: .destructive) {
                Task { await unregisterCron(cronId, name: name) }
            }
        }
    }

    private func rowSublabel(expression: String, graphId: String, linkedTask: TaskModel?, linkedTaskId: String?, nextRun: Double) -> String {
        var parts: [String] = []
        if !expression.isEmpty { parts.append(expression) }
        if let linkedTask {
            parts.append("→ task: \(linkedTask.title)")
        } else if let linkedTaskId {
            parts.append("→ task: \(linkedTaskId)")
        } else if !graphId.isEmpty {
            let gname = bridge.graphName(for: graphId)
            parts.append("→ \(gname.isEmpty ? "workflow" : gname)")
        } else {
            parts.append("→ (no graph)")
        }
        if nextRun > 0 {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM-dd HH:mm"
            parts.append("next: \(fmt.string(from: Date(timeIntervalSince1970: nextRun)))")
        }
        return parts.joined(separator: "  ")
    }

    private func parseTaskId(from inputRaw: String) -> String? {
        guard let data = inputRaw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj["task_id"] as? String
    }

    private func unregisterCron(_ id: String, name: String) async {
        do {
            _ = try await bridge.cronUnregister(cronId: id)
            toastManager.show(style: .info, title: "Removed", message: name)
            await bridge.fetchCronJobs()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

private struct IdentifiableString: Identifiable {
    let value: String
    var id: String { value }
}

// MARK: - HooksTabView

struct HooksTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newEvent = "agent.execute"
    @State private var newAgentId = ""
    @State private var newAction = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hooks")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Hook", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.hooks.isEmpty {
                Spacer()
                Text("No hooks registered")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.hooks.enumerated()), id: \.offset) { idx, hook in
                        let event = hook["event"] as? String ?? "Unknown"
                        let agentId = hook["agent_id"] as? String ?? ""
                        let action = hook["action"] as? String ?? ""
                        let hookId = hook["hook_id"] as? String ?? hook["id"] as? String ?? ""
                        StudioRow(label: event, sublabel: "\(agentId) → \(action)", isLast: idx == bridge.configState.hooks.count - 1) {
                            FusionTag("hook", color: .blue)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                Task { await testHook(hookId) }
                            } label: {
                                Label("Test", systemImage: "bolt")
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchHooks() } }
        .sheet(isPresented: $showCreateSheet) {
            createHookSheet
        }
    }

    private var createHookSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Hook")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Event (e.g. agent.execute)", text: $newEvent)
                .textFieldStyle(.roundedBorder)
            Picker("Agent", selection: $newAgentId) {
                Text("Select agent").tag("")
                ForEach(bridge.agentState.agents) { a in
                    Text(a.name).tag(a.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Action", text: $newAction)
                .textFieldStyle(.roundedBorder)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createHook() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createHook() async {
        guard !newEvent.isEmpty, !newAgentId.isEmpty, !newAction.isEmpty else { return }
        do {
            _ = try await bridge.hooksRegister(event: newEvent, agentId: newAgentId, action: newAction)
            toastManager.show(style: .success, title: "Hook Created", message: newEvent)
            showCreateSheet = false
            newAction = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testHook(_ id: String) async {
        do {
            let result = try await bridge.hooksTest(hookId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "Hook OK" : "Hook Failed", message: "")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - AnalyticsTabView

struct AnalyticsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var selectedRange = "week"

    private let ranges = ["day", "week", "month"]

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                HStack {
                    Text("Analytics")
                        .font(.system(size: theme.titleSize, weight: .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Picker("Range", selection: $selectedRange) {
                        ForEach(ranges, id: \.self) { r in
                            Text(r.capitalized).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: selectedRange) { _, newRange in
                        Task { await bridge.fetchAnalytics(range: newRange) }
                    }
                }
                .padding(theme.spacingM)

                analyticsCards
                agentUsageList
                Spacer()
            }
        }
        .onAppear { Task { await bridge.fetchAnalytics(range: selectedRange) } }
    }

    private var analyticsCards: some View {
        let d = bridge.configState.analyticsData
        let totalRequests = d["total_requests"] as? Int ?? 0
        let totalTokens = d["total_tokens"] as? Int ?? 0
        let avgLatency = d["avg_latency_ms"] as? Double ?? 0
        let errorRate = d["error_rate"] as? Double ?? 0
        let cards: [(String, String, String, TagColor)] = [
            ("Total Requests", "\(totalRequests)", "text.bubble", .blue),
            ("Total Tokens", "\(totalTokens)", "number", .blue),
            ("Avg Latency", String(format: "%.0fms", avgLatency), "clock", .purple),
            ("Error Rate", String(format: "%.1f%%", errorRate), "exclamationmark.triangle", errorRate > 5 ? .red : .green),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(cards, id: \.0) { card in
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Image(systemName: card.2)
                            .foregroundStyle(theme.accent)
                        Spacer()
                        Text(card.0)
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    Text(card.1)
                        .font(.system(size: theme.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.text)
                }
                .padding(theme.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                        .fill(theme.surfaceSecondary)
                )
            }
        }
        .padding(.horizontal, theme.spacingM)
    }

    private var agentUsageList: some View {
        let perAgent = bridge.configState.analyticsData["per_agent"] as? [[String: Any]] ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if perAgent.isEmpty {
                Text("No per-agent analytics data")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(theme.spacingL)
            } else {
                ForEach(Array(perAgent.enumerated()), id: \.offset) { idx, entry in
                    let name = entry["name"] as? String ?? entry["agent_id"] as? String ?? "Unknown"
                    let reqs = entry["requests"] as? Int ?? 0
                    let tokens = entry["tokens"] as? Int ?? 0
                    HStack {
                        Text(name)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        Text("\(reqs) reqs")
                            .font(.system(size: theme.captionSize))
                            .foregroundStyle(theme.textSecondary)
                        Text("\(tokens) tok")
                            .font(.system(size: theme.captionSize, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.text)
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
    }
}

// MARK: - AlertTabView

struct AlertTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Alerts")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Refresh", icon: "arrow.clockwise") {
                    Task { await bridge.fetchAlerts() }
                }
            }
            .padding(theme.spacingM)

            if bridge.configState.alerts.isEmpty {
                Spacer()
                VStack(spacing: theme.spacingS) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 40))
                        .foregroundStyle(theme.successText)
                    Text("No active alerts")
                        .font(.system(size: theme.textSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.alerts.enumerated()), id: \.offset) { idx, alert in
                        let level = alert["level"] as? String ?? "info"
                        let message = alert["message"] as? String ?? "No message"
                        let source = alert["source"] as? String ?? ""
                        let aid = alert["alert_id"] as? String ?? alert["id"] as? String ?? ""
                        let acknowledged = alert["acknowledged"] as? Bool ?? false
                        StudioRow(label: message, sublabel: source, isLast: idx == bridge.configState.alerts.count - 1) {
                            FusionTag(level, color: alertColor(for: level))
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            if !acknowledged {
                                Button {
                                    Task { await ackAlert(aid) }
                                } label: {
                                    Label("Acknowledge", systemImage: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchAlerts() } }
    }

    private func alertColor(for level: String) -> TagColor {
        switch level {
        case "critical", "error": return .red
        case "warning", "warn": return .orange
        case "info": return .blue
        default: return .gray
        }
    }

    private func ackAlert(_ id: String) async {
        do {
            _ = try await bridge.alertAcknowledge(alertId: id)
            toastManager.show(style: .success, title: "Acknowledged", message: "Alert dismissed")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - MemoryTabView

struct MemoryTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showStoreSheet = false
    @State private var newContent = ""
    @State private var newScope = "default"
    @State private var newTags = ""
    @State private var newImportance: Double = 5
    @State private var newTier = ""
    @State private var recallQuery = ""
    @State private var recallScope = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Memory Store")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Store", icon: "plus") { showStoreSheet = true }
            }
            .padding(theme.spacingM)

            HStack(spacing: theme.spacingS) {
                TextField("Query memories...", text: $recallQuery)
                    .textFieldStyle(.roundedBorder)
                TextField("scope", text: $recallScope)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                FusionButton("Recall", icon: "magnifyingglass", style: .secondary) {
                    Task { await runRecall() }
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if bridge.moduleState.memoryEntries.isEmpty {
                Spacer()
                Text("No memories yet")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.memoryEntries.enumerated()), id: \.element.id) { idx, entry in
                            StudioRow(label: entry.content, sublabel: memorySublabel(entry), isLast: idx == bridge.moduleState.memoryEntries.count - 1) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    FusionTag("L\(entry.importance)", color: importanceColor(entry.importance))
                                    if !entry.tier.isEmpty {
                                        FusionTag(entry.tier, color: .purple)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchRecentMemories()
                } catch {
                    agentStudioLog.warning("fetchRecentMemories failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showStoreSheet) {
            storeSheet
        }
    }

    private var storeSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Store Memory")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Content", text: $newContent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                TextField("scope", text: $newScope)
                    .textFieldStyle(.roundedBorder)
                TextField("tier", text: $newTier)
                    .textFieldStyle(.roundedBorder)
            }
            TextField("tags (comma separated)", text: $newTags)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("Importance")
                    .font(.system(size: theme.captionSize))
                Slider(value: $newImportance, in: 1...10, step: 1)
                Text("\(Int(newImportance))")
                    .font(.system(size: theme.captionSize, weight: .semibold))
                    .frame(width: 24)
            }
            HStack {
                FusionButton("Cancel") { showStoreSheet = false }
                Spacer()
                FusionButton("Store", icon: "tray.and.arrow.down", isDisabled: newContent.isEmpty) {
                    Task { await runStore() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 420)
    }

    private func runStore() async {
        guard !newContent.isEmpty else { return }
        do {
            _ = try await bridge.memoryStore(content: newContent, scope: newScope, tags: newTags, importance: Int(newImportance), tier: newTier)
            toastManager.show(style: .success, title: "Stored", message: "Memory saved to \(newScope)")
            showStoreSheet = false
            newContent = ""
            newTags = ""
            try await bridge.fetchRecentMemories()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func runRecall() async {
        do {
            let entries = try await bridge.memoryRecall(query: recallQuery, scope: recallScope)
            toastManager.show(style: .success, title: "Recall", message: "\(entries.count) memories")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func memorySublabel(_ entry: MemoryEntryModel) -> String {
        var parts: [String] = []
        if !entry.scope.isEmpty { parts.append("scope: \(entry.scope)") }
        if !entry.tags.isEmpty { parts.append("tags: \(entry.tags)") }
        if !entry.timestamp.isEmpty { parts.append(entry.timestamp) }
        return parts.joined(separator: " · ")
    }

    private func importanceColor(_ level: Int) -> TagColor {
        switch level {
        case 8...10: return .red
        case 5...7: return .orange
        case 3...4: return .blue
        default: return .gray
        }
    }
}

// MARK: - SafetyTabView

struct SafetyTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCheckSheet = false
    @State private var checkContent = ""
    @State private var checkContext = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Safety & Compliance")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Check", icon: "checkmark.shield") { showCheckSheet = true }
            }
            .padding(theme.spacingM)

            if let result = bridge.moduleState.safetyCheckResult {
                StudioSectionHeader(title: "Last Check Result")
                ListGroup {
                    StudioRow(label: "Level", sublabel: result.level, isLast: false) {
                        FusionTag(result.level, color: levelColor(result.level))
                    }
                    StudioRow(label: "Approved", sublabel: nil, isLast: result.violations.isEmpty) {
                        FusionTag(result.approved ? "yes" : "no", color: result.approved ? .green : .red)
                    }
                    if !result.violations.isEmpty {
                        StudioRow(label: "Violations", sublabel: result.violations.joined(separator: ", "), isLast: true) {
                            FusionTag("\(result.violations.count)", color: .red)
                        }
                    }
                }
            }

            StudioSectionHeader(title: "Pending Actions")
            if bridge.moduleState.safetyPendingActions.isEmpty {
                Text("No pending safety actions")
                    .font(.system(size: theme.footnoteSize))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
            } else {
                ListGroup {
                    ForEach(Array(bridge.moduleState.safetyPendingActions.enumerated()), id: \.element.id) { idx, action in
                        StudioRow(label: action.category, sublabel: action.content, isLast: idx == bridge.moduleState.safetyPendingActions.count - 1) {
                            HStack(spacing: 6) {
                                FusionButton("Approve", icon: "checkmark", style: .secondary, size: .small) {
                                    Task { await approveAction(action.id) }
                                }
                                FusionButton("Reject", icon: "xmark", style: .destructive, size: .small) {
                                    Task { await rejectAction(action.id) }
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchPendingSafetyActions()
                } catch {
                    agentStudioLog.warning("fetchPendingSafetyActions failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showCheckSheet) {
            checkSheet
        }
    }

    private var checkSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Safety Check")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Content to check", text: $checkContent, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
            TextField("Context (optional)", text: $checkContext, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                FusionButton("Cancel") { showCheckSheet = false }
                Spacer()
                FusionButton("Check", icon: "shield", isDisabled: checkContent.isEmpty) {
                    Task { await runCheck() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 360)
    }

    private func runCheck() async {
        guard !checkContent.isEmpty else { return }
        do {
            let result = try await bridge.safetyCheck(content: checkContent, context: checkContext)
            toastManager.show(style: result.approved ? .success : .warning, title: result.level, message: result.approved ? "Approved" : "\(result.violations.count) violations")
            showCheckSheet = false
            checkContent = ""
            checkContext = ""
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func approveAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyApproveAction(actionId: actionId)
            toastManager.show(style: .success, title: "Approved", message: "Safety action approved")
            try await bridge.fetchPendingSafetyActions()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func rejectAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyRejectAction(actionId: actionId)
            toastManager.show(style: .success, title: "Rejected", message: "Safety action rejected")
            try await bridge.fetchPendingSafetyActions()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func levelColor(_ level: String) -> TagColor {
        switch level.uppercased() {
        case "L4", "L5": return .red
        case "L3": return .orange
        case "L2": return .blue
        default: return .green
        }
    }
}

// MARK: - PlannerTabView

struct PlannerTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newTask = ""
    @State private var newContext = ""
    @State private var expandedPlanId: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Planner")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("New Plan", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.moduleState.plans.isEmpty {
                Spacer()
                Text("No plans yet")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.plans.enumerated()), id: \.element.id) { idx, plan in
                            planRow(plan, isLast: idx == bridge.moduleState.plans.count - 1)
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do {
                    try await bridge.fetchPlans()
                } catch {
                    agentStudioLog.warning("fetchPlans failed: \(error)")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            createSheet
        }
    }

    @ViewBuilder
    private func planRow(_ plan: PlanModel, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: theme.spacingM) {
                Button {
                    withAnimation(theme.springSnappy) {
                        expandedPlanId = expandedPlanId == plan.id ? nil : plan.id
                    }
                } label: {
                    Image(systemName: expandedPlanId == plan.id ? "chevron.down" : "chevron.right")
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.task)
                        .font(.system(size: theme.textSize, weight: .medium))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                    Text("\(plan.steps.count) steps · \(plan.created_at)")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                FusionTag(plan.status, color: planStatusColor(plan.status))
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingS + 2)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if !isLast {
                    Rectangle().fill(theme.rowSep).frame(height: 0.5).padding(.horizontal, theme.spacingL)
                }
            }

            if expandedPlanId == plan.id {
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    if !plan.context.isEmpty {
                        Text(plan.context)
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textSecondary)
                    }
                    ForEach(plan.steps) { step in
                        HStack(alignment: .top, spacing: theme.spacingS) {
                            Image(systemName: stepIcon(step.status))
                                .foregroundStyle(stepColor(step.status))
                                .frame(width: 16)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.description)
                                    .font(.system(size: theme.footnoteSize))
                                    .foregroundStyle(theme.text)
                                if let result = step.result, !result.isEmpty {
                                    Text(result)
                                        .font(.system(size: theme.captionSize))
                                        .foregroundStyle(theme.textSecondary)
                                }
                            }
                            Spacer()
                            if plan.status == "approved" || plan.status == "executing" {
                                FusionButton("Run", icon: "play", style: .secondary, size: .small) {
                                    Task { await executeStep(plan.id, step.id) }
                                }
                            }
                        }
                    }
                    HStack(spacing: theme.spacingS) {
                        if plan.status == "pending" || plan.status == "draft" {
                            FusionButton("Approve", icon: "checkmark", style: .secondary, size: .small) {
                                Task { await approvePlan(plan.id) }
                            }
                            FusionButton("Reject", icon: "xmark", style: .destructive, size: .small) {
                                Task { await rejectPlan(plan.id) }
                            }
                        }
                        if plan.status == "approved" {
                            FusionButton("Execute All", icon: "play.fill", size: .small) {
                                Task { await executePlan(plan.id) }
                            }
                        }
                        if plan.status != "completed" && plan.status != "cancelled" {
                            FusionButton("Cancel", icon: "stop", style: .ghost, size: .small) {
                                Task { await cancelPlan(plan.id) }
                            }
                        }
                    }
                    .padding(.top, theme.spacingXS)
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.bottom, theme.spacingM)
                .background(theme.surfaceSecondary)
            }
        }
    }

    private var createSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Create Plan")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Task description", text: $newTask, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            TextField("Context (optional)", text: $newContext, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus", isDisabled: newTask.isEmpty) {
                    Task { await createPlan() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 360)
    }

    private func createPlan() async {
        guard !newTask.isEmpty else { return }
        do {
            _ = try await bridge.plannerCreatePlan(task: newTask, context: newContext)
            toastManager.show(style: .success, title: "Plan Created", message: newTask)
            showCreateSheet = false
            newTask = ""
            newContext = ""
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func approvePlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerApprovePlan(planId: planId)
            toastManager.show(style: .success, title: "Approved", message: "Plan approved")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func rejectPlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerRejectPlan(planId: planId)
            toastManager.show(style: .success, title: "Rejected", message: "Plan rejected")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func executeStep(_ planId: String, _ stepId: String) async {
        do {
            _ = try await bridge.plannerExecuteStep(planId: planId, stepId: stepId)
            toastManager.show(style: .success, title: "Step Done", message: "Step executed")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func executePlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerExecutePlan(planId: planId)
            toastManager.show(style: .success, title: "Executing", message: "Plan execution started")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func cancelPlan(_ planId: String) async {
        do {
            _ = try await bridge.plannerCancelPlan(planId: planId)
            toastManager.show(style: .success, title: "Cancelled", message: "Plan cancelled")
            try await bridge.fetchPlans()
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func planStatusColor(_ status: String) -> TagColor {
        switch status.lowercased() {
        case "completed": return .green
        case "approved", "executing": return .blue
        case "cancelled", "rejected", "failed": return .red
        case "pending", "draft": return .orange
        default: return .gray
        }
    }

    private func stepIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "completed", "done": return "checkmark.circle.fill"
        case "running", "executing": return "arrow.triangle.2.circlepath"
        case "failed", "error": return "xmark.circle.fill"
        case "skipped": return "minus.circle"
        default: return "circle"
        }
    }

    private func stepColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "completed", "done": return theme.successText
        case "running", "executing": return theme.infoText
        case "failed", "error": return theme.errorText
        default: return theme.textTertiary
        }
    }
}

// MARK: - RagTabView

struct RagTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var query = ""
    @State private var limit: Double = 10
    @State private var threshold: Double = 0.5
    @State private var mode = "query"
    @State private var answer = ""
    @State private var sources: [String] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RAG Retrieval")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(theme.spacingM)

            VStack(spacing: theme.spacingS) {
                Picker("Mode", selection: $mode) {
                    Text("Query (answer)").tag("query")
                    Text("Retrieve (docs)").tag("retrieve")
                    Text("Vector Search").tag("vector")
                }
                .pickerStyle(.segmented)
                HStack(spacing: theme.spacingS) {
                    TextField("Query...", text: $query, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    FusionButton("Run", icon: "magnifyingglass", isDisabled: query.isEmpty || isLoading) {
                        Task { await runRag() }
                    }
                }
                if mode == "vector" {
                    HStack {
                        Text("Limit: \(Int(limit))")
                            .font(.system(size: theme.captionSize))
                        Slider(value: $limit, in: 1...50, step: 1)
                        Text("Threshold: \(String(format: "%.2f", threshold))")
                            .font(.system(size: theme.captionSize))
                        Slider(value: $threshold, in: 0...1, step: 0.05)
                    }
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if isLoading {
                ProgressView().padding(theme.spacingM)
            }
            if !answer.isEmpty {
                StudioSectionHeader(title: "Answer")
                ScrollView {
                    Text(answer)
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingL)
                }
            }
            if !sources.isEmpty {
                StudioSectionHeader(title: "Sources")
                ListGroup {
                    ForEach(Array(sources.enumerated()), id: \.offset) { idx, src in
                        StudioRow(label: src, sublabel: nil, isLast: idx == sources.count - 1) {
                            FusionTag("\(idx + 1)", color: .blue)
                        }
                    }
                }
            }
            Spacer()
        }
    }

    private func runRag() async {
        guard !query.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            switch mode {
            case "retrieve":
                let docs = try await bridge.ragRetrieve(query: query)
                sources = docs
                answer = ""
                toastManager.show(style: .success, title: "Retrieve", message: "\(docs.count) documents")
            case "vector":
                let docs = try await bridge.ragVectorSearch(query: query, limit: Int(limit), threshold: threshold)
                sources = docs
                answer = ""
                toastManager.show(style: .success, title: "Vector Search", message: "\(docs.count) results")
            default:
                let result = try await bridge.ragQuery(query: query)
                answer = result.answer
                sources = result.sources
                toastManager.show(style: .success, title: "Query", message: "\(result.sources.count) sources")
            }
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - ToolsTabView

struct ToolsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showRegisterSheet = false
    @State private var newName = ""
    @State private var newDesc = ""
    @State private var newParams = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tools")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Register", icon: "plus") { showRegisterSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.moduleState.tools.isEmpty {
                Spacer()
                Text("No tools available")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ScrollView {
                    ListGroup {
                        ForEach(Array(bridge.moduleState.tools.enumerated()), id: \.offset) { idx, tool in
                            let name = tool["name"] as? String ?? "unknown"
                            let desc = tool["description"] as? String ?? ""
                            let isDynamic = (tool["dynamic"] as? Bool ?? false) || (tool["source"] as? String == "dynamic")
                            StudioRow(label: name, sublabel: desc, isLast: idx == bridge.moduleState.tools.count - 1) {
                                HStack(spacing: 6) {
                                    if isDynamic {
                                        FusionTag("dynamic", color: .orange)
                                        FusionButton("Remove", icon: "trash", style: .destructive, size: .small) {
                                            Task { await unregisterTool(name) }
                                        }
                                    } else {
                                        FusionTag("builtin", color: .gray)
                                    }
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            Task {
                do { try await bridge.fetchTools() } catch { agentStudioLog.warning("fetchTools failed: \(error)") }
            }
        }
        .sheet(isPresented: $showRegisterSheet) {
            registerSheet
        }
    }

    private var registerSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("Register Dynamic Tool")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $newDesc, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            TextField("Parameters (JSON)", text: $newParams, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...8)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
            HStack {
                FusionButton("Cancel") { showRegisterSheet = false }
                Spacer()
                FusionButton("Register", icon: "plus", isDisabled: newName.isEmpty) {
                    Task { await registerTool() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 450, height: 420)
    }

    private func registerTool() async {
        let params = parseParams(newParams)
        do {
            _ = try await bridge.toolDynamicRegister(name: newName, description: newDesc, parameters: params)
            toastManager.show(style: .success, title: "Registered", message: "Tool \(newName) added")
            showRegisterSheet = false
            newName = ""
            newDesc = ""
            newParams = ""
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func unregisterTool(_ name: String) async {
        do {
            _ = try await bridge.toolDynamicUnregister(name: name)
            toastManager.show(style: .success, title: "Removed", message: "Tool \(name) unregistered")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func parseParams(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return obj
    }
}

// MARK: - SkillsTabView

struct SkillsTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var mode = "skill"
    @State private var selectedAgentId = ""
    @State private var skillName = ""
    @State private var input = ""
    @State private var question = ""
    @State private var maxSteps: Double = 10
    @State private var webSearch = true
    @State private var result = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Skills & Research")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
            }
            .padding(theme.spacingM)

            Picker("Mode", selection: $mode) {
                Text("Skill Execute").tag("skill")
                Text("Adaptive Research").tag("research")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, theme.spacingL)
            .padding(.bottom, theme.spacingS)

            if mode == "skill" {
                skillForm
            } else {
                researchForm
            }

            if isLoading {
                ProgressView().padding(theme.spacingM)
            }
            if !result.isEmpty {
                StudioSectionHeader(title: "Result")
                ScrollView {
                    Text(result)
                        .font(.system(size: theme.footnoteSize, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, theme.spacingL)
                }
            }
            Spacer()
        }
    }

    private var skillForm: some View {
        VStack(spacing: theme.spacingS) {
            Picker("Agent", selection: $selectedAgentId) {
                Text("Select agent...").tag("")
                ForEach(bridge.agentState.agents) { agent in
                    Text(agent.name).tag(agent.id)
                }
            }
            .textFieldStyle(.roundedBorder)
            TextField("Skill name", text: $skillName)
                .textFieldStyle(.roundedBorder)
            TextField("Input", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            FusionButton("Execute Skill", icon: "wand.and.stars", isDisabled: selectedAgentId.isEmpty || skillName.isEmpty || isLoading) {
                Task { await runSkill() }
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private var researchForm: some View {
        VStack(spacing: theme.spacingS) {
            TextField("Research question", text: $question, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
            HStack {
                Text("Max steps: \(Int(maxSteps))")
                    .font(.system(size: theme.captionSize))
                Slider(value: $maxSteps, in: 1...30, step: 1)
            }
            Toggle("Web search", isOn: $webSearch)
                .font(.system(size: theme.captionSize))
            FusionButton("Run Research", icon: "magnifyingglass.circle", isDisabled: question.isEmpty || isLoading) {
                Task { await runResearch() }
            }
        }
        .padding(.horizontal, theme.spacingL)
    }

    private func runSkill() async {
        guard !selectedAgentId.isEmpty, !skillName.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let output = try await bridge.skillExecute(agentId: selectedAgentId, skillName: skillName, input: input)
            result = output.isEmpty ? "(no output)" : output
            toastManager.show(style: .success, title: "Skill Done", message: skillName)
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }

    private func runResearch() async {
        guard !question.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await bridge.researchAdaptive(question: question, maxSteps: Int(maxSteps), webSearch: webSearch)
            result = summary.isEmpty ? "(no summary)" : summary
            toastManager.show(style: .success, title: "Research Done", message: "Adaptive research completed")
        } catch {
            toastManager.show(style: .error, title: "Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - ConnectorTabView

struct ConnectorTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newType = "http"
    @State private var newConfig = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Connectors")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Connector", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.connectors.isEmpty {
                Spacer()
                Text("No connectors configured")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.connectors.enumerated()), id: \.offset) { idx, conn in
                        let name = conn["name"] as? String ?? "Unknown"
                        let type = conn["type"] as? String ?? ""
                        let status = conn["status"] as? String ?? "unknown"
                        let cid = conn["connector_id"] as? String ?? conn["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: type, isLast: idx == bridge.configState.connectors.count - 1) {
                            FusionTag(status, color: status == "connected" ? .green : status == "disconnected" ? .gray : .orange)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button { Task { await testConnector(cid, name: name) } } label: {
                                Label("Test", systemImage: "bolt")
                            }
                            if status != "connected" {
                                Button { Task { await connectConnector(cid, name: name) } } label: {
                                    Label("Connect", systemImage: "link")
                                }
                            }
                            if status == "connected" {
                                Button { Task { await disconnectConnector(cid, name: name) } } label: {
                                    Label("Disconnect", systemImage: "link.badge.plus")
                                }
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                Task { await deleteConnector(cid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchConnectors() } }
        .sheet(isPresented: $showCreateSheet) {
            createConnectorSheet
        }
    }

    private var createConnectorSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Connector")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Type (http, database, api...)", text: $newType)
                .textFieldStyle(.roundedBorder)
            TextField("Config (JSON)", text: $newConfig, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createConnector() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createConnector() async {
        guard !newName.isEmpty else { return }
        var config: [String: Any] = [:]
        if let data = newConfig.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = json
        }
        do {
            _ = try await bridge.connectorCreate(name: newName, type: newType, config: config)
            toastManager.show(style: .success, title: "Created", message: "\(newName)")
            showCreateSheet = false
            newName = ""; newConfig = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func testConnector(_ id: String, name: String) async {
        do {
            let result = try await bridge.connectorTest(connectorId: id)
            let success = result["success"] as? Bool ?? false
            toastManager.show(style: success ? .success : .error, title: success ? "OK" : "Failed", message: "\(name)")
        } catch {
            toastManager.show(style: .error, title: "Test Failed", message: error.localizedDescription)
        }
    }

    private func connectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorConnect(connectorId: id)
            toastManager.show(style: .success, title: "Connected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Connect Failed", message: error.localizedDescription)
        }
    }

    private func disconnectConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDisconnect(connectorId: id)
            toastManager.show(style: .info, title: "Disconnected", message: name)
            await bridge.fetchConnectors()
        } catch {
            toastManager.show(style: .error, title: "Disconnect Failed", message: error.localizedDescription)
        }
    }

    private func deleteConnector(_ id: String, name: String) async {
        do {
            _ = try await bridge.connectorDelete(connectorId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - ApikeyTabView

struct ApikeyTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newPermissions = "read,execute"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("API Keys")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Create Key", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.apikeys.isEmpty {
                Spacer()
                Text("No API keys")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.apikeys.enumerated()), id: \.offset) { idx, key in
                        let name = key["name"] as? String ?? "Unknown"
                        let kid = key["key_id"] as? String ?? key["id"] as? String ?? ""
                        let prefix = key["key_prefix"] as? String ?? ""
                        let perms = key["permissions"] as? [String] ?? []
                        StudioRow(label: name, sublabel: prefix.isEmpty ? kid : prefix, isLast: idx == bridge.configState.apikeys.count - 1) {
                            if perms.contains("admin") {
                                FusionTag("admin", color: .red)
                            } else if perms.contains("execute") {
                                FusionTag("execute", color: .green)
                            } else {
                                FusionTag("read", color: .blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button {
                                Task { await rotateKey(kid, name: name) }
                            } label: {
                                Label("Rotate Key", systemImage: "arrow.triangle.2.circlepath")
                            }
                            Divider()
                            Button("Revoke", role: .destructive) {
                                Task { await revokeKey(kid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchApikeys() } }
        .sheet(isPresented: $showCreateSheet) {
            createApikeySheet
        }
    }

    private var createApikeySheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New API Key")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Permissions (comma-separated)", text: $newPermissions)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text("Agent Restrictions")
                    .font(.system(size: theme.footnoteSize, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacingXS) {
                        ForEach(bridge.agentState.agents.prefix(10), id: \.id) { agent in
                            FusionTag(agent.name, color: .blue)
                        }
                    }
                }
                Text("Leave empty to allow all agents")
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createKey() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createKey() async {
        guard !newName.isEmpty else { return }
        let perms = newPermissions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        do {
            let result = try await bridge.apikeyCreate(name: newName, permissions: perms)
            let keyVal = result["key"] as? String ?? ""
            toastManager.show(style: .success, title: "Key Created", message: keyVal.isEmpty ? newName : "Copy key: \(keyVal.prefix(12))...")
            showCreateSheet = false
            newName = ""; newPermissions = "read,execute"
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func revokeKey(_ id: String, name: String) async {
        do {
            _ = try await bridge.apikeyRevoke(keyId: id)
            toastManager.show(style: .info, title: "Revoked", message: name)
        } catch {
            toastManager.show(style: .error, title: "Revoke Failed", message: error.localizedDescription)
        }
    }

    private func rotateKey(_ id: String, name: String) async {
        do {
            let result = try await bridge.apikeyRotate(keyId: id)
            let newKey = result["key"] as? String ?? ""
            toastManager.show(style: .success, title: "Key Rotated", message: newKey.isEmpty ? name : "New key: \(newKey.prefix(12))...")
        } catch {
            toastManager.show(style: .error, title: "Rotate Failed", message: error.localizedDescription)
        }
    }
}

// MARK: - StyleTabView

struct StyleTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var showCreateSheet = false
    @State private var newName = ""
    @State private var newTemplate = "default"
    @State private var newRules = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Styles")
                    .font(.system(size: theme.titleSize, weight: .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                FusionButton("Add Style", icon: "plus") { showCreateSheet = true }
            }
            .padding(theme.spacingM)

            if bridge.configState.styles.isEmpty {
                Spacer()
                Text("No custom styles")
                    .font(.system(size: theme.textSize))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
            } else {
                ListGroup {
                    ForEach(Array(bridge.configState.styles.enumerated()), id: \.offset) { idx, style in
                        let name = style["name"] as? String ?? "Unknown"
                        let template = style["template"] as? String ?? ""
                        let sid = style["style_id"] as? String ?? style["id"] as? String ?? ""
                        StudioRow(label: name, sublabel: template, isLast: idx == bridge.configState.styles.count - 1) {
                            FusionTag("style", color: .purple)
                        }
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                Task { await deleteStyle(sid, name: name) }
                            }
                        }
                    }
                }
            }
        }
        .onAppear { Task { await bridge.fetchStyles() } }
        .sheet(isPresented: $showCreateSheet) {
            createStyleSheet
        }
    }

    private var createStyleSheet: some View {
        VStack(spacing: theme.spacingM) {
            Text("New Style")
                .font(.system(size: theme.titleSize, weight: .bold))
            TextField("Name", text: $newName)
                .textFieldStyle(.roundedBorder)
            TextField("Template (default, formal, casual...)", text: $newTemplate)
                .textFieldStyle(.roundedBorder)
            TextField("Rules (JSON)", text: $newRules, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
            HStack {
                FusionButton("Cancel") { showCreateSheet = false }
                Spacer()
                FusionButton("Create", icon: "plus") {
                    Task { await createStyle() }
                }
            }
        }
        .padding(theme.spacingL)
        .frame(width: 400)
    }

    private func createStyle() async {
        guard !newName.isEmpty else { return }
        var rules: [String: Any] = [:]
        if let data = newRules.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            rules = json
        }
        do {
            _ = try await bridge.styleCreate(name: newName, template: newTemplate, rules: rules)
            toastManager.show(style: .success, title: "Created", message: newName)
            showCreateSheet = false
            newName = ""; newRules = ""
        } catch {
            toastManager.show(style: .error, title: "Create Failed", message: error.localizedDescription)
        }
    }

    private func deleteStyle(_ id: String, name: String) async {
        do {
            _ = try await bridge.styleDelete(styleId: id)
            toastManager.show(style: .info, title: "Deleted", message: name)
        } catch {
            toastManager.show(style: .error, title: "Delete Failed", message: error.localizedDescription)
        }
    }
}
