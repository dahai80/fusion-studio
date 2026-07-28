import SwiftUI
import os.log

private let cronLog = Logger(subsystem: "com.fusion.studio", category: "CronManager")

struct CronJobModel: Identifiable, Hashable {
    let id: String
    let name: String
    let expression: String
    let graphId: String
    let enabled: Bool
    let lastRun: Double
    let nextRun: Double
    let inputData: String

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.name = dict["name"] as? String ?? ""
        self.expression = dict["expression"] as? String ?? ""
        self.graphId = dict["graph_id"] as? String ?? ""
        self.enabled = dict["enabled"] as? Bool ?? true
        self.lastRun = dict["last_run"] as? Double ?? 0
        self.nextRun = dict["next_run"] as? Double ?? 0
        self.inputData = dict["input_data"] as? String ?? ""
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: CronJobModel, rhs: CronJobModel) -> Bool { lhs.id == rhs.id }

    var nextRunText: String {
        guard nextRun > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: nextRun)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }

    var lastRunText: String {
        guard lastRun > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: lastRun)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: date)
    }
}

struct CronExecutionModel: Identifiable {
    let id: String
    let jobId: String
    let startedAt: Double
    let finishedAt: Double
    let status: String
    let error: String

    init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.jobId = dict["job_id"] as? String ?? ""
        self.startedAt = dict["started_at"] as? Double ?? 0
        self.finishedAt = dict["finished_at"] as? Double ?? 0
        self.status = dict["status"] as? String ?? ""
        self.error = dict["error"] as? String ?? ""
    }

    var startedAtText: String {
        guard startedAt > 0 else { return "-" }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: Date(timeIntervalSince1970: startedAt))
    }

    var durationText: String {
        guard startedAt > 0, finishedAt > 0 else { return "-" }
        let d = finishedAt - startedAt
        return String(format: "%.1fs", d)
    }

    var statusColor: Color {
        switch status {
        case "success": return .green
        case "failed": return .red
        default: return .gray
        }
    }
}

struct CronManagerView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var jobs: [CronJobModel] = []
    @State private var executions: [CronExecutionModel] = []
    @State private var selectedJob: CronJobModel?
    @State private var isLoading = false
    @State private var errorMessage = ""

    @State private var showingNewJob = false
    @State private var newName = ""
    @State private var newExpression = "*/5 * * * *"
    @State private var newGraphId = ""
    @State private var newInputData = ""

    @State private var refreshTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if isLoading {
                ProgressView("Loading...")
            } else if !errorMessage.isEmpty {
                Text(errorMessage).foregroundColor(.red).padding()
            } else {
                HSplitView {
                    jobList
                    executionDetail
                }
            }
        }
        .navigationTitle("Scheduled Tasks")
        .onAppear { loadData(); startRefresh() }
        .onDisappear { refreshTimer?.invalidate() }
        .sheet(isPresented: $showingNewJob) { newJobSheet }
    }

    private var toolbar: some View {
        HStack {
            Button(action: loadData) {
                Image(systemName: "arrow.clockwise")
            }
            Button(action: { showingNewJob = true }) {
                Label("New Job", systemImage: "plus")
            }
            Spacer()
            Text("\(jobs.count) jobs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
    }

    private var jobList: some View {
        List(jobs, selection: $selectedJob) { job in
            HStack {
                Circle()
                    .fill(job.enabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.name.isEmpty ? job.id : job.name)
                        .font(.headline)
                    Text(job.expression)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next: \(job.nextRunText)")
                        .font(.caption2)
                    Text("Last: \(job.lastRunText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .contextMenu {
                Button("Delete", role: .destructive) {
                    deleteJob(job)
                }
            }
        }
        .frame(minWidth: 280)
    }

    private var executionDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let job = selectedJob {
                Text("Executions: \(job.name.isEmpty ? job.id : job.name)")
                    .font(.headline)
                    .padding(.horizontal)

                List(executions) { exe in
                    HStack {
                        Circle().fill(exe.statusColor).frame(width: 8, height: 8)
                        Text(exe.startedAtText).font(.caption)
                        Text(exe.durationText).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text(exe.status).font(.caption).foregroundColor(exe.statusColor)
                    }
                    if !exe.error.isEmpty {
                        Text(exe.error).font(.caption2).foregroundColor(.red)
                    }
                }
            } else {
                Text("Select a job to view executions")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 320)
        .onChange(of: selectedJob) { _ in loadExecutions() }
    }

    private var newJobSheet: some View {
        VStack(spacing: 16) {
            Text("New Scheduled Task").font(.headline)
            TextField("Name", text: $newName)
            TextField("Cron Expression", text: $newExpression)
                .font(.system(.body, design: .monospaced))
            Text("Format: minute hour day month weekday (e.g. */5 * * * *)")
                .font(.caption).foregroundColor(.secondary)
            TextField("Graph ID (optional)", text: $newGraphId)
            TextField("Input Data (optional)", text: $newInputData)
            HStack {
                Button("Cancel") { showingNewJob = false }
                Button("Create") { createJob() }
                    .disabled(newExpression.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    private func loadData() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let result = try await bridge.cronList()
                await MainActor.run {
                    self.jobs = result.map { CronJobModel(from: $0) }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func loadExecutions() {
        guard let job = selectedJob else { return }
        Task {
            do {
                let result = try await bridge.cronListExecutions(jobId: job.id)
                await MainActor.run {
                    self.executions = result.map { CronExecutionModel(from: $0) }
                }
            } catch {
                cronLog.error("Load executions: \(error)")
            }
        }
    }

    private func createJob() {
        Task {
            do {
                _ = try await bridge.cronRegister(
                    name: newName,
                    expression: newExpression,
                    graphId: newGraphId,
                    inputData: newInputData
                )
                await MainActor.run {
                    showingNewJob = false
                    newName = ""
                    newExpression = "*/5 * * * *"
                    newGraphId = ""
                    newInputData = ""
                    loadData()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func deleteJob(_ job: CronJobModel) {
        Task {
            do {
                _ = try await bridge.cronUnregister(id: job.id)
                await MainActor.run {
                    if selectedJob == job { selectedJob = nil }
                    loadData()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func startRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            loadData()
            if selectedJob != nil { loadExecutions() }
        }
    }
}
