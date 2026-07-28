import SwiftUI
import os.log

struct AgentDashboardView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var runningAgents: [AgentRunInfo] = []
    @State private var recentEvents: [EventEntry] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var selectedAgent: AgentRunInfo?
    @State private var tokenUsage: TokenUsageInfo = TokenUsageInfo()
    @State private var autoRefresh: Bool = true
    @State private var refreshTimer: Timer?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "AgentDashboardView")

    var body: some View {
        VStack(spacing: 0) {
            dashboardToolbar
            Divider()
            if isLoading && runningAgents.isEmpty {
                ProgressView("Loading agents...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                errorView(error)
            } else {
                HSplitView {
                    agentListView
                        .frame(minWidth: 260)
                    dashboardDetailView
                        .frame(minWidth: 500)
                }
            }
        }
        .onAppear {
            Task { await loadDashboard() }
            startAutoRefresh()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private var dashboardToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await loadDashboard() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Toggle("Auto", isOn: $autoRefresh)
                .toggleStyle(.checkbox)
                .onChange(of: autoRefresh) { val in
                    if val { startAutoRefresh() } else { stopAutoRefresh() }
                }
            Spacer()
            HStack(spacing: 16) {
                Label("\(tokenUsage.totalTokens)", systemImage: "text.bubble")
                    .font(.caption)
                Label("\(runningAgents.filter { $0.status == "running" }.count)", systemImage: "play.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(8)
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(msg)
                .font(.caption)
            Button("Retry") { Task { await loadDashboard() } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var agentListView: some View {
        VStack(spacing: 0) {
            if runningAgents.isEmpty {
                Spacer()
                Text("No agents running")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(runningAgents, selection: $selectedAgent) { agent in
                    agentRow(agent)
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func agentRow(_ agent: AgentRunInfo) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor(agent.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(agent.graphId.prefix(8))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if agent.status == "running" {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.vertical, 2)
        .tag(agent)
    }

    private var dashboardDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let selected = selectedAgent {
                    agentDetailSection(selected)
                }
                tokenUsageSection
                eventStreamSection
            }
            .padding(16)
        }
    }

    private func agentDetailSection(_ agent: AgentRunInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agent: \(agent.name)")
                .font(.headline)
            HStack(spacing: 24) {
                LabeledContent("Status", value: agent.status)
                LabeledContent("Iterations", value: "\(agent.iterations)")
                LabeledContent("Started", value: formatTime(agent.startedAt))
            }
            .font(.caption)
            if !agent.error.isEmpty {
                Text("Error: \(agent.error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var tokenUsageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token Usage")
                .font(.headline)
            HStack(spacing: 16) {
                usageGauge("Prompt", value: tokenUsage.promptTokens, color: .blue)
                usageGauge("Completion", value: tokenUsage.completionTokens, color: .green)
                usageGauge("Total", value: tokenUsage.totalTokens, color: .orange)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func usageGauge(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var eventStreamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Stream")
                .font(.headline)
            if recentEvents.isEmpty {
                Text("No events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(recentEvents) { evt in
                            eventRow(evt)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func eventRow(_ evt: EventEntry) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(eventColor(evt.type))
                .frame(width: 6, height: 6)
            Text(evt.type)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(eventColor(evt.type))
                .frame(width: 60, alignment: .leading)
            Text(evt.content)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(2)
            Spacer()
            Text(formatTime(evt.timestamp))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "running": return .green
        case "completed": return .blue
        case "error": return .red
        case "paused": return .yellow
        default: return .gray
        }
    }

    private func eventColor(_ type: String) -> Color {
        switch type {
        case "start": return .green
        case "end": return .blue
        case "error": return .red
        case "think": return .purple
        case "tool_call", "tool_result": return .orange
        case "verify": return .cyan
        case "token", "thinking_token": return .secondary
        default: return .gray
        }
    }

    private func formatTime(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts)
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { await loadDashboard() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil
        do {
            let sessions = try await bridge.listSessions()
            var agents: [AgentRunInfo] = []
            var totalPrompt = 0
            var totalCompletion = 0
            var events: [EventEntry] = []

            for session in sessions {
                let info = AgentRunInfo(
                    id: session["id"] as? String ?? UUID().uuidString,
                    name: session["graph_name"] as? String ?? "Unknown",
                    graphId: session["graph_id"] as? String ?? "",
                    status: session["status"] as? String ?? "unknown",
                    iterations: session["iteration_count"] as? Int ?? 0,
                    startedAt: session["started_at"] as? Double ?? 0,
                    error: session["error"] as? String ?? ""
                )
                agents.append(info)
                let prompt = session["prompt_tokens"] as? Int ?? 0
                let completion = session["completion_tokens"] as? Int ?? 0
                totalPrompt += prompt
                totalCompletion += completion

                if let sessionEvents = session["events"] as? [[String: Any]] {
                    for evt in sessionEvents.prefix(20) {
                        events.append(EventEntry(
                            id: evt["timestamp"] as? Double ?? Date().timeIntervalSince1970,
                            type: evt["type"] as? String ?? "unknown",
                            content: (evt["content"] as? String ?? "").prefix(120).description,
                            timestamp: evt["timestamp"] as? Double ?? 0
                        ))
                    }
                }
            }

            runningAgents = agents
            tokenUsage = TokenUsageInfo(
                promptTokens: totalPrompt,
                completionTokens: totalCompletion,
                totalTokens: totalPrompt + totalCompletion
            )
            recentEvents = Array(events.sorted { $0.timestamp > $1.timestamp }.prefix(50))
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Dashboard load failed: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

struct AgentRunInfo: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let graphId: String
    let status: String
    let iterations: Int
    let startedAt: Double
    let error: String

    static func == (lhs: AgentRunInfo, rhs: AgentRunInfo) -> Bool {
        lhs.id == rhs.id
    }
}

struct EventEntry: Identifiable {
    let id: Double
    let type: String
    let content: String
    let timestamp: Double
}

struct TokenUsageInfo {
    var promptTokens: Int = 0
    var completionTokens: Int = 0
    var totalTokens: Int = 0
}
