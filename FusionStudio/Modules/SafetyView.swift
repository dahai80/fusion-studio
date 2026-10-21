import SwiftUI
import os.log

struct SafetyView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var selectedTab: SafetyTab = .check

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyView")

    enum SafetyTab: String, CaseIterable {
        case check = "Check"
        case evaluate = "Evaluate"
        case pending = "Pending"
        case policy = "Policy"
    }

    var body: some View {
        VStack(spacing: 0) {
            safetyToolbar
            Divider()
            Picker("Tab", selection: $selectedTab) {
                ForEach(SafetyTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            Group {
                switch selectedTab {
                case .check:
                    SafetyCheckView()
                case .evaluate:
                    SafetyEvaluateView()
                case .pending:
                    SafetyPendingView()
                case .policy:
                    SafetyPolicyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var safetyToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await loadPending() } }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
            if !bridge.moduleState.safetyPendingActions.isEmpty {
                Text("\(bridge.moduleState.safetyPendingActions.count) pending")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(8)
    }

    private func loadPending() async {
        do {
            _ = try await bridge.fetchPendingSafetyActions()
        } catch {
            logger.error("loadPending: \(error)")
        }
    }
}

struct SafetyCheckView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var contentInput: String = ""
    @State private var contextInput: String = ""
    @State private var isChecking: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyCheckView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Content Safety Check") {
                VStack(spacing: 8) {
                    TextEditor(text: $contentInput)
                        .frame(minHeight: 80, maxHeight: 150)
                        .border(Color.gray.opacity(0.3))
                    TextField("Context (optional)", text: $contextInput)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Check Safety") {
                            Task { await checkContent() }
                        }
                        .disabled(contentInput.isEmpty || isChecking)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)

            if let result = bridge.moduleState.safetyCheckResult {
                safetyCheckResultView(result)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private func safetyCheckResultView(_ result: SafetyCheckModel) -> some View {
        GroupBox("Check Result") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level:")
                        .fontWeight(.semibold)
                    Text(result.level)
                        .foregroundColor(levelColor(result.level))
                    Spacer()
                    Image(systemName: result.approved ? "checkmark.shield.fill" : "xmark.shield.fill")
                        .foregroundColor(result.approved ? .green : .red)
                        .font(.title2)
                }
                if !result.violations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Violations:")
                            .fontWeight(.semibold)
                        ForEach(result.violations, id: \.self) { v in
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text(v)
                                    .font(.caption)
                            }
                        }
                    }
                }
                Text(result.approved ? "Content approved" : "Content rejected")
                    .font(.headline)
                    .foregroundColor(result.approved ? .green : .red)
            }
        }
        .padding(.horizontal)
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "L1": return .green
        case "L2": return .orange
        case "L3": return .red
        default: return .secondary
        }
    }

    private func checkContent() async {
        isChecking = true
        do {
            _ = try await bridge.safetyCheck(content: contentInput, context: contextInput)
        } catch {
            logger.error("checkContent: \(error)")
        }
        isChecking = false
    }
}

struct SafetyEvaluateView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var category = ""
    @State private var content = ""
    @State private var context = ""
    @State private var isEvaluating = false
    @State private var result: SafetyActionModel?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyEvaluateView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Evaluate Action") {
                VStack(spacing: 8) {
                    TextField("Category (e.g. code_execution, file_access)", text: $category)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $content)
                        .frame(minHeight: 60, maxHeight: 120)
                        .border(Color.gray.opacity(0.3))
                    TextField("Context (optional)", text: $context)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button("Evaluate") {
                            Task { await evaluateAction() }
                        }
                        .disabled(category.isEmpty || isEvaluating)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)

            if let result {
                evaluateResultView(result)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    private func evaluateResultView(_ result: SafetyActionModel) -> some View {
        GroupBox("Evaluation Result") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Action ID:").fontWeight(.semibold)
                    Text(result.id).font(.caption).foregroundColor(.secondary)
                }
                HStack {
                    Text("Category:").fontWeight(.semibold)
                    Text(result.category)
                }
                HStack {
                    Text("Status:").fontWeight(.semibold)
                    Text(result.status)
                        .foregroundColor(result.status == "approved" ? .green : .orange)
                }
                if !result.reason.isEmpty {
                    HStack {
                        Text("Reason:").fontWeight(.semibold)
                        Text(result.reason).font(.caption)
                    }
                }
                HStack(spacing: 12) {
                    Button("Approve") {
                        Task { await approveAction(result.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    Button("Reject") {
                        Task { await rejectAction(result.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(.horizontal)
    }

    private func evaluateAction() async {
        isEvaluating = true
        do {
            result = try await bridge.safetyEvaluateAction(category: category, content: content, context: context)
        } catch {
            logger.error("evaluateAction: \(error)")
        }
        isEvaluating = false
    }

    private func approveAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyApproveAction(actionId: actionId)
            result?.status = "approved"
        } catch {
            logger.error("approveAction: \(error)")
        }
    }

    private func rejectAction(_ actionId: String) async {
        do {
            _ = try await bridge.safetyRejectAction(actionId: actionId)
            result?.status = "rejected"
        } catch {
            logger.error("rejectAction: \(error)")
        }
    }
}
struct SafetyPendingView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var cardFilter: String = "all"

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyPendingView")
    private let cardTypes = ["all", "folder", "code", "network", "remote"]

    private var filteredActions: [SafetyActionModel] {
        guard cardFilter != "all" else { return bridge.moduleState.safetyPendingActions }
        return bridge.moduleState.safetyPendingActions.filter { $0.cardType == cardFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            cardFilterBar
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
            Group {
                if bridge.moduleState.safetyPendingActions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No pending actions")
                            .foregroundColor(.secondary)
                        Button("Refresh") {
                            Task { await loadPending() }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredActions.isEmpty {
                    Text("No actions in this card class")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredActions) { action in
                        SafetyActionRow(action: action)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .onAppear {
            Task { await loadPending() }
        }
    }

    private var cardFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(cardTypes, id: \.self) { type in
                let count = type == "all"
                    ? bridge.moduleState.safetyPendingActions.count
                    : bridge.moduleState.safetyPendingActions.filter { $0.cardType == type }.count
                Button {
                    cardFilter = type
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: SafetyActionRow.iconForCard(type))
                            .font(.caption2)
                        Text(type.capitalized)
                            .font(.caption)
                        Text("\(count)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cardFilter == type ? SafetyActionRow.colorForCard(type).opacity(0.18) : Color.clear)
                    )
                    .foregroundColor(cardFilter == type ? SafetyActionRow.colorForCard(type) : .secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                Task { await loadPending() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func loadPending() async {
        do {
            _ = try await bridge.fetchPendingSafetyActions()
        } catch {
            logger.error("loadPending: \(error)")
        }
    }
}

struct SafetyActionRow: View {
    @EnvironmentObject var bridge: AgentBridge
    let action: SafetyActionModel
    @State private var isActing: Bool = false
    @State private var showPreview: Bool = false

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyActionRow")

    static func colorForCard(_ type: String) -> Color {
        switch type {
        case "folder": return .blue
        case "code": return .purple
        case "network": return .orange
        case "remote": return .teal
        default: return .secondary
        }
    }

    static func iconForCard(_ type: String) -> String {
        switch type {
        case "folder": return "folder"
        case "code": return "chevron.left.forwardslash.chevron.right"
        case "network": return "network"
        case "remote": return "antenna.radiowaves.left.and.right"
        default: return "shield"
        }
    }

    private var hasPreview: Bool {
        !action.diff.isEmpty || !action.content.isEmpty
    }

    var statusIcon: String {
        switch action.status {
        case "pending": return "clock"
        case "approved": return "checkmark.circle"
        case "rejected": return "xmark.circle"
        default: return "questionmark.circle"
        }
    }

    var statusColor: Color {
        switch action.status {
        case "pending": return .orange
        case "approved": return .green
        case "rejected": return .red
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(action.category)
                            .font(.headline)
                        Text(action.status)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.2))
                            .foregroundColor(statusColor)
                            .cornerRadius(3)
                        Text(action.cardType.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Self.colorForCard(action.cardType).opacity(0.15))
                            .foregroundColor(Self.colorForCard(action.cardType))
                            .cornerRadius(3)
                        if !action.level.isEmpty {
                            Text(action.level)
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundColor(.secondary)
                                .cornerRadius(3)
                        }
                        if action.category == "file_write" || action.category == "shell_exec" {
                            Text("GATEWAY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .cornerRadius(3)
                        }
                    }
                    if !action.content.isEmpty {
                        Text(action.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Text(action.id)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if action.status == "pending" {
                    HStack(spacing: 4) {
                        if hasPreview {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showPreview.toggle() }
                            } label: {
                                Image(systemName: showPreview ? "chevron.up" : "eye")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        Button("Approve") {
                            Task { await approve() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Button("Reject") {
                            Task { await reject() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                    }
                    .disabled(isActing)
                }
            }
            if showPreview && hasPreview {
                VStack(alignment: .leading, spacing: 4) {
                    if !action.diff.isEmpty {
                        Text("Diff")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        ScrollView {
                            Text(action.diff)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 160)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    if !action.content.isEmpty {
                        Text(action.content)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(6)
                    }
                    if !action.original.isEmpty || !action.proposed.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            if !action.original.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Original").font(.caption2).foregroundColor(.secondary)
                                    Text(action.original)
                                        .font(.system(.caption2, design: .monospaced))
                                        .lineLimit(4)
                                }
                            }
                            if !action.proposed.isEmpty {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Proposed").font(.caption2).foregroundColor(.secondary)
                                    Text(action.proposed)
                                        .font(.system(.caption2, design: .monospaced))
                                        .lineLimit(4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func approve() async {
        isActing = true
        do {
            _ = try await bridge.safetyApproveAction(actionId: action.id)
            _ = try await bridge.ipcClient!.safetyApprove(actionId: action.id)
            _ = try await bridge.fetchPendingSafetyActions()
        } catch {
            logger.error("approve: \(error)")
        }
        isActing = false
    }

    private func reject() async {
        isActing = true
        do {
            _ = try await bridge.safetyRejectAction(actionId: action.id)
            _ = try await bridge.ipcClient!.safetyReject(actionId: action.id)
            _ = try await bridge.fetchPendingSafetyActions()
        } catch {
            logger.error("reject: \(error)")
        }
        isActing = false
    }
}

struct SafetyPolicyView: View {
    @EnvironmentObject var bridge: AgentBridge
    @State private var category: String = ""
    @State private var description: String = ""
    @State private var defaultLevel: String = "L2"
    @State private var requiresDiff: Bool = false
    @State private var isAdding: Bool = false
    @State private var addResult: String?

    private let logger = Logger(subsystem: "com.fusion.studio", category: "SafetyPolicyView")

    var body: some View {
        VStack(spacing: 16) {
            GroupBox("Add Safety Policy") {
                VStack(spacing: 8) {
                    TextField("Category", text: $category)
                        .textFieldStyle(.roundedBorder)
                    TextField("Description", text: $description)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Picker("Default Level", selection: $defaultLevel) {
                            Text("L1 - Low").tag("L1")
                            Text("L2 - Medium").tag("L2")
                            Text("L3 - High").tag("L3")
                        }
                        .frame(width: 180)
                        Toggle("Requires Diff", isOn: $requiresDiff)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Button("Add Policy") {
                            Task { await addPolicy() }
                        }
                        .disabled(category.isEmpty || isAdding)
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    if let result = addResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.hasPrefix("Error") ? .red : .green)
                    }
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding(.vertical)
    }

    private func addPolicy() async {
        isAdding = true
        addResult = nil
        do {
            let success = try await bridge.safetyAddPolicy(category: category, description: description, defaultLevel: defaultLevel, requiresDiff: requiresDiff)
            addResult = success ? "Policy added" : "Failed to add policy"
            category = ""
            description = ""
        } catch {
            addResult = "Error: \(error.localizedDescription)"
            logger.error("addPolicy: \(error)")
        }
        isAdding = false
    }
}
