import SwiftUI
import os.log

struct MemoryView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var selectedTab: MemoryTab = .recent
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryView")

    // Callers: MemoryView tabs. Affected API: memory.recall_relevant/auto_forget. User instruction: "审视是否所有需要功能和api所有需要的GUI都在~/fusion/fusion-studio都已经有对应GUI了，所有有问题的都要在fusion-studio补齐GUI"
    enum MemoryTab: String, CaseIterable {
        case recent   = "Recent"
        case recall   = "Recall"
        case relevant = "Context"
        case store    = "Store"
        case manage   = "Manage"
    }

    var body: some View {
        VStack(spacing: 0) {
            memoryToolbar
            Divider()
            Picker("Tab", selection: $selectedTab) {
                ForEach(MemoryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            Group {
                switch selectedTab {
                case .recent:
                    MemoryRecentView()
                case .recall:
                    MemoryRecallView()
                case .relevant:
                    MemoryRelevantView()
                case .store:
                    MemoryStoreView()
                case .manage:
                    MemoryManageView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            Task { await loadRecentMemories() }
        }
    }

    private var memoryToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await loadRecentMemories() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
            if bridge.memoryCount > 0 {
                Text("\(bridge.memoryCount) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }

    private func loadRecentMemories() async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await bridge.fetchRecentMemories()
            _ = try await bridge.fetchMemoryCount()
        } catch {
            errorMessage = error.localizedDescription
            logger.error("loadRecentMemories: \(error)")
        }
        isLoading = false
    }
}

struct MemoryRecentView: View {
    @EnvironmentObject var bridge: AgentBridge

    var body: some View {
        List(bridge.memoryEntries) { entry in
            MemoryEntryRow(entry: entry)
        }
        .listStyle(.inset)
    }
}

struct MemoryEntryRow: View {
    let entry: MemoryEntryModel

    var importanceColor: Color {
        switch entry.importance {
        case 0...3: return .green
        case 4...6: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .center, spacing: 2) {
                Text("\(entry.importance)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(importanceColor)
                Text("imp")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }
            .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.content)
                    .lineLimit(3)
                    .font(.body)
                HStack(spacing: 8) {
                    if !entry.scope.isEmpty {
                        Text(entry.scope)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(3)
                    }
                    if !entry.tags.isEmpty {
                        Text(entry.tags)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(entry.tier)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(entry.timestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MemoryRecallView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var query: String = ""
    @State private var scope: String = ""
    @State private var minImportance: Int = 0
    @State private var isSearching: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryRecallView")

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Search memories...", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await recall() } }
                Button("Search") {
                    Task { await recall() }
                }
                .disabled(query.isEmpty || isSearching)
                .buttonStyle(.borderedProminent)
            }
            HStack(spacing: 12) {
                TextField("Scope filter", text: $scope)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)
                Stepper("Min importance: \(minImportance)", value: $minImportance, in: 0...10)
                    .frame(width: 200)
                Spacer()
            }
            Divider()
            if isSearching {
                ProgressView("Searching...")
            } else {
                List(bridge.memoryEntries) { entry in
                    MemoryEntryRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .padding()
    }

    private func recall() async {
        isSearching = true
        do {
            _ = try await bridge.memoryRecall(query: query, scope: scope, minImportance: minImportance)
        } catch {
            logger.error("recall: \(error)")
        }
        isSearching = false
    }
}

struct MemoryStoreView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var content: String = ""
    @State private var scope: String = "default"
    @State private var tags: String = ""
    @State private var importance: Int = 5
    @State private var tier: String = "short_term"
    @State private var isStoring: Bool = false
    @State private var storeResult: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryStoreView")

    var body: some View {
        Form {
            Section("Content") {
                TextEditor(text: $content)
                    .frame(minHeight: 80, maxHeight: 200)
            }
            Section("Metadata") {
                TextField("Scope", text: $scope)
                TextField("Tags (comma-separated)", text: $tags)
                Stepper("Importance: \(importance)", value: $importance, in: 0...10)
                Picker("Tier", selection: $tier) {
                    Text("Short Term").tag("short_term")
                    Text("Long Term").tag("long_term")
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Store Memory") {
                        Task { await store() }
                    }
                    .disabled(content.isEmpty || isStoring)
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            }
            if let result = storeResult {
                Section("Result") {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func store() async {
        isStoring = true
        storeResult = nil
        do {
            let entry = try await bridge.memoryStore(content: content, scope: scope, tags: tags, importance: importance, tier: tier)
            storeResult = "Stored: \(entry.id)"
            content = ""
        } catch {
            storeResult = "Error: \(error.localizedDescription)"
            logger.error("store: \(error)")
        }
        isStoring = false
    }
}

struct MemoryManageView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var deleteScopeInput: String = ""
    @State private var isDeleting: Bool = false
    @State private var deleteResult: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryManageView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Delete by Scope") {
                HStack(spacing: 8) {
                    TextField("Scope name", text: $deleteScopeInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Delete All in Scope") {
                        Task { await deleteScope() }
                    }
                    .disabled(deleteScopeInput.isEmpty || isDeleting)
                    .foregroundColor(.red)
                }
                if let result = deleteResult {
                    Text(result)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)

            GroupBox("Memory Stats") {
                HStack(spacing: 24) {
                    VStack {
                        Text("\(bridge.memoryEntries.count)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack {
                        Text("\(bridge.memoryCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Refresh Stats") {
                        Task { await refreshStats() }
                    }
                }
            }
            .padding(.horizontal)

            List {
                ForEach(bridge.memoryEntries) { entry in
                    HStack {
                        MemoryEntryRow(entry: entry)
                        Spacer()
                        Button(action: { Task { await deleteEntry(entry.id) } }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .padding(.vertical)
    }

    private func deleteScope() async {
        isDeleting = true
        deleteResult = nil
        do {
            let count = try await bridge.memoryDeleteScope(scope: deleteScopeInput)
            deleteResult = "Deleted \(count) entries"
        } catch {
            deleteResult = "Error: \(error.localizedDescription)"
            logger.error("deleteScope: \(error)")
        }
        isDeleting = false
    }

    private func deleteEntry(_ entryId: String) async {
        do {
            _ = try await bridge.memoryDelete(entryId: entryId)
            _ = try await bridge.fetchRecentMemories()
        } catch {
            logger.error("deleteEntry: \(error)")
        }
    }

    private func refreshStats() async {
        do {
            _ = try await bridge.fetchMemoryCount()
            _ = try await bridge.fetchRecentMemories()
        } catch {
            logger.error("refreshStats: \(error)")
        }
    }
}

struct MemoryRelevantView: View {
    @EnvironmentObject var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    @State private var query: String = ""
    @State private var context: String = ""
    @State private var results: [[String: Any]] = []
    @State private var isSearching: Bool = false
    @State private var autoForgetResult: String?
    @State private var maxAge: Int = 30
    @State private var minImportance: Int = 3
    @State private var dryRun: Bool = true
    private let logger = Logger(subsystem: "com.fusion.studio", category: "MemoryRelevant")

    var body: some View {
        VStack(spacing: theme.spacingM) {
            GroupBox("Context-Aware Recall") {
                VStack(spacing: theme.spacingS) {
                    TextField("Query", text: $query)
                        .textFieldStyle(.roundedBorder)
                    TextField("Context (optional)", text: $context)
                        .textFieldStyle(.roundedBorder)
                    Button("Recall Relevant") { performRecall() }
                        .disabled(query.isEmpty || isSearching)
                }
            }
            .padding(.horizontal, theme.spacingM)

            if isSearching {
                ProgressView()
            } else if !results.isEmpty {
                List(Array(results.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item["content"] as? String ?? "").lineLimit(3)
                        HStack {
                            Text(item["scope"] as? String ?? "").font(.caption2).foregroundStyle(theme.textTertiary)
                            if let score = item["score"] as? Double {
                                Text(String(format: "%.2f", score)).font(.caption2).foregroundStyle(theme.accent)
                            }
                        }
                    }
                }
            }

            Divider()

            GroupBox("Auto Forget") {
                VStack(spacing: theme.spacingS) {
                    HStack {
                        LabeledContent("Max Age (days)") { Stepper("\(maxAge)", value: $maxAge, in: 1...365) }
                        LabeledContent("Min Importance") { Stepper("\(minImportance)", value: $minImportance, in: 0...10) }
                    }
                    Toggle("Dry Run", isOn: $dryRun)
                    Button("Run Auto Forget") { performAutoForget() }
                    if let result = autoForgetResult {
                        Text(result).font(.caption).foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, theme.spacingM)

            Spacer()
        }
    }

    private func performRecall() {
        isSearching = true
        Task {
            do {
                let result = try await bridge.ipcClient!.memoryRecallRelevant(
                    query: query, context: context
                )
                results = result["entries"] as? [[String: Any]] ?? []
            } catch {
                logger.error("recallRelevant failed: \(error.localizedDescription)")
            }
            isSearching = false
        }
    }

    private func performAutoForget() {
        Task {
            do {
                let result = try await bridge.ipcClient!.memoryAutoForget(
                    maxAge: maxAge, minImportance: minImportance, dryRun: dryRun
                )
                let count = result["removed_count"] as? Int ?? 0
                autoForgetResult = dryRun ? "Would remove \(count) entries" : "Removed \(count) entries"
            } catch {
                autoForgetResult = "Error: \(error.localizedDescription)"
            }
        }
    }
}
