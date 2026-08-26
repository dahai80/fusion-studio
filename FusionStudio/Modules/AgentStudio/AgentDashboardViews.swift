import SwiftUI
import Combine
import os.log

// MARK: - DashboardTabView

struct DashboardTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme
    private let dashboardLog = Logger(subsystem: "com.fusion.studio", category: "Dashboard")
    @State private var filterStartDate = Date().addingTimeInterval(-86400 * 7)
    @State private var filterEndDate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                StudioSectionHeader(title: "Overview")
                dashboardCards
                StudioSectionHeader(title: "Agent Status Breakdown")
                agentStatusList
                StudioSectionHeader(title: "Recent Errors")
                recentErrorsSection
                StudioSectionHeader(title: "Recent Agents")
                recentAgentsSection
                StudioSectionHeader(title: "Audit Trail")
                datePickerBar
                auditTrailSection
                StudioSectionHeader(title: "Session Logs")
                sessionLogsSection
                Spacer()
            }
            .padding(theme.spacingL)
        }
        .onAppear {
            Task {
                await bridge.fetchDashboard()
                await bridge.fetchAuditTrail(startDate: isoDate(filterStartDate), endDate: isoDate(filterEndDate))
                await bridge.fetchSessionLogs(startDate: isoDate(filterStartDate), endDate: isoDate(filterEndDate))
            }
        }
    }

    private func isoDate(_ date: Date) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt.string(from: date)
    }

    private var datePickerBar: some View {
        HStack(spacing: theme.spacingM) {
            DatePicker("From", selection: $filterStartDate, displayedComponents: .date)
                .labelsHidden()
            Text("—")
                .foregroundStyle(theme.textTertiary)
            DatePicker("To", selection: $filterEndDate, displayedComponents: .date)
                .labelsHidden()
            FusionButton("Filter", icon: "line.3.decrease.circle", style: .secondary, size: .small) {
                Task {
                    await bridge.fetchAuditTrail(startDate: isoDate(filterStartDate), endDate: isoDate(filterEndDate))
                    await bridge.fetchSessionLogs(startDate: isoDate(filterStartDate), endDate: isoDate(filterEndDate))
                }
            }
            Spacer()
        }
        .padding(theme.spacingS)
        .background(theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var auditTrailSection: some View {
        let trail = bridge.agentState.auditTrail
        if trail.isEmpty {
            return AnyView(
                HStack {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(theme.textTertiary)
                    Text("No audit events in selected range")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(theme.spacingM)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            )
        }
        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(trail.prefix(20).enumerated()), id: \.offset) { idx, entry in
                    let action = entry["action"] as? String ?? entry["event"] as? String ?? "unknown"
                    let agent = entry["agent_name"] as? String ?? entry["agent_id"] as? String ?? ""
                    let time = entry["timestamp"] as? String ?? entry["time"] as? String ?? ""
                    HStack {
                        Image(systemName: "shield")
                            .foregroundStyle(.blue)
                            .font(.system(size: theme.iconXS))
                        Text(action)
                            .font(.system(size: theme.footnoteSize, weight: .medium))
                            .foregroundStyle(theme.text)
                        if !agent.isEmpty {
                            Text(agent)
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        Spacer()
                        if !time.isEmpty {
                            Text(time)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        )
    }

    private var sessionLogsSection: some View {
        let logs = bridge.agentState.sessionLogs
        if logs.isEmpty {
            return AnyView(
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundStyle(theme.textTertiary)
                    Text("No session logs in selected range")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(theme.spacingM)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            )
        }
        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(logs.prefix(20).enumerated()), id: \.offset) { idx, log in
                    let sessionId = log["session_id"] as? String ?? log["id"] as? String ?? ""
                    let agent = log["agent_name"] as? String ?? log["agent_id"] as? String ?? ""
                    let tokens = log["total_tokens"] as? Int ?? 0
                    let time = log["started_at"] as? String ?? log["timestamp"] as? String ?? ""
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.purple)
                            .font(.system(size: theme.iconXS))
                        Text(sessionId.prefix(8))
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                        if !agent.isEmpty {
                            Text(agent)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textSecondary)
                        }
                        Spacer()
                        if tokens > 0 {
                            Text("\(tokens) tok")
                                .font(.system(size: theme.captionSize, design: .monospaced))
                                .foregroundStyle(theme.textTertiary)
                        }
                        if !time.isEmpty {
                            Text(time)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        )
    }

    private var dashboardCards: some View {
        let d = bridge.agentState.dashboardData
        let cards: [(String, String, String, Color)] = [
            ("Total Agents", "\(d["total_agents"] as? Int ?? bridge.agentState.agents.count)", "person.2", .blue),
            ("Published", "\(d["published_agents"] as? Int ?? bridge.agentState.agents.filter { $0.status == "published" }.count)", "arrow.up.circle", .green),
            ("Active", "\(d["active_agents"] as? Int ?? 0)", "bolt", .orange),
            ("Today Requests", "\(d["today_requests"] as? Int ?? 0)", "text.bubble", .purple),
            ("Total Tokens", "\(d["total_tokens"] as? Int ?? 0)", "number", .cyan),
            ("Errors", "\(d["error_count"] as? Int ?? 0)", "exclamationmark.triangle", .red),
        ]
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
            GridItem(.flexible(), spacing: theme.spacingM),
        ], spacing: theme.spacingM) {
            ForEach(cards, id: \.0) { card in
                VStack(alignment: .leading, spacing: theme.spacingS) {
                    HStack {
                        Image(systemName: card.2)
                            .foregroundStyle(card.3)
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
    }

    private var agentStatusList: some View {
        VStack(spacing: 0) {
            let draft = bridge.agentState.agents.filter { $0.status == "draft" || $0.status == nil }
            let published = bridge.agentState.agents.filter { $0.status == "published" }
            let archived = bridge.agentState.agents.filter { $0.status == "archived" }
            statusRow(label: "Draft", count: draft.count, color: .gray)
            statusRow(label: "Published", count: published.count, color: .green)
            statusRow(label: "Archived", count: archived.count, color: .orange)
        }
    }

    private func statusRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.text)
            Spacer()
            Text("\(count)")
                .font(.system(size: theme.textSize, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.text)
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingM)
        .background(theme.surfaceSecondary)
    }

    private var recentErrorsSection: some View {
        let errors = bridge.agentState.dashboardData["recent_errors"] as? [[String: Any]] ?? []
        if errors.isEmpty {
            return AnyView(
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                    Text("No recent errors")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(theme.spacingM)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            )
        }
        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(errors.prefix(5).enumerated()), id: \.offset) { idx, err in
                    let msg = err["message"] as? String ?? err["error"] as? String ?? "Unknown error"
                    let time = err["timestamp"] as? String ?? err["time"] as? String ?? ""
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: theme.iconXS))
                        Text(msg)
                            .font(.system(size: theme.footnoteSize, design: .monospaced))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        Spacer()
                        if !time.isEmpty {
                            Text(time)
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        )
    }

    private var recentAgentsSection: some View {
        let recent = bridge.agentState.agents.prefix(5)
        if recent.isEmpty {
            return AnyView(
                HStack {
                    Image(systemName: "person.2")
                        .foregroundStyle(theme.textTertiary)
                    Text("No agents yet")
                        .font(.system(size: theme.footnoteSize))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
                .padding(theme.spacingM)
                .background(theme.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
            )
        }
        return AnyView(
            VStack(spacing: 0) {
                ForEach(Array(recent.enumerated()), id: \.element.id) { idx, agent in
                    HStack {
                        Image(systemName: "brain")
                            .foregroundStyle(theme.accent)
                            .font(.system(size: theme.iconXS))
                        Text(agent.name)
                            .font(.system(size: theme.textSize))
                            .foregroundStyle(theme.text)
                        Spacer()
                        if let status = agent.status {
                            FusionTag(status, color: status == "published" ? .green : status == "archived" ? .orange : .gray)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingS)
                    .background(idx % 2 == 0 ? theme.surfaceSecondary : theme.surfacePrimary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        )
    }
}

// MARK: - MarketplaceTabView

struct MarketplaceTabView: View {
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var entries: [MarketplaceEntryModel] = []
    @State private var categories: [String] = []
    @State private var showPublish = false
    @State private var publishName = ""
    @State private var publishAuthor = ""
    @State private var publishDesc = ""
    @State private var publishCategory = ""
    @State private var publishTags = ""
    @State private var publishVersion = "1.0.0"
    @State private var publishGraphId = ""

    @Environment(\.studioTheme) var theme

    var body: some View {
        GeometryReader { geo in
            HSplitView {
                marketplaceSidebar
                    .frame(minWidth: 200, idealWidth: max(200, geo.size.width * 0.2), maxWidth: 360)

                marketplaceDetail
                    .frame(minWidth: 400, idealWidth: geo.size.width * 0.8)
            }
        }
        .onAppear {
            loadMarketplace()
        }
    }

    private var marketplaceSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StudioSectionHeader(title: "Marketplace")

                HStack(spacing: theme.spacingS) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.textTertiary)
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit { searchMarketplace() }
                }
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.bottom, theme.spacingS)

                if !categories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: theme.spacingXS) {
                            FusionTag("All", color: selectedCategory.isEmpty ? .blue : .gray)
                                .onTapGesture { selectedCategory = ""; searchMarketplace() }
                            ForEach(categories, id: \.self) { cat in
                                FusionTag(cat, color: selectedCategory == cat ? .blue : .gray)
                                    .onTapGesture { selectedCategory = cat; searchMarketplace() }
                            }
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                    .padding(.bottom, theme.spacingS)
                }

                if entries.isEmpty {
                    VStack(spacing: theme.spacingM) {
                        Image(systemName: "bag")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textTertiary)
                        Text("No marketplace entries")
                            .font(.system(size: theme.footnoteSize))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .padding(.vertical, theme.spacing2XL)
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: theme.spacingS),
                        GridItem(.flexible(), spacing: theme.spacingS),
                    ], spacing: theme.spacingS) {
                        ForEach(entries) { entry in
                            MarketplaceCard(entry: entry)
                        }
                    }
                    .padding(.horizontal, theme.spacingM)
                }

                HStack {
                    Spacer()
                    FusionButton("Publish", icon: "arrow.up.doc", style: .primary, size: .small) {
                        showPublish = true
                    }
                }
                .padding(theme.spacingM)
            }
        }
        .sheet(isPresented: $showPublish) {
            publishSheet
        }
    }

    private var marketplaceDetail: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "bag")
                .font(.system(size: 48))
                .foregroundStyle(theme.textTertiary)
            Text("Select an entry or publish your work")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var publishSheet: some View {
        ScrollView {
            VStack(spacing: theme.spacingL) {
                Text("Publish to Marketplace")
                    .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.text)

                formField("Name *", text: $publishName)
                formField("Author", text: $publishAuthor)
                formField("Description", text: $publishDesc)
                formField("Category", text: $publishCategory)
                formField("Tags (comma separated)", text: $publishTags)
                formField("Version", text: $publishVersion)
                formField("Graph ID", text: $publishGraphId)

                HStack(spacing: theme.spacingM) {
                    FusionButton("Cancel", icon: "xmark", style: .secondary, size: .regular) {
                        showPublish = false
                    }
                    FusionButton("Publish", icon: "arrow.up.doc", style: .primary, size: .regular, isDisabled: publishName.isEmpty) {
                        publishToMarketplace()
                    }
                }
            }
            .padding(theme.spacingXL)
        }
        .frame(width: 500, height: 500)
        .background(theme.windowBg)
    }

    private func formField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(label)
                .font(.system(size: theme.footnoteSize, weight: .medium))
                .foregroundStyle(theme.textSecondary)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
        }
    }

    private func loadMarketplace() {
        Task {
            do {
                categories = try await bridge.fetchMarketplaceCategories()
                entries = try await bridge.marketplaceSearch(query: "", category: "", tags: [])
            } catch {
                agentStudioLog.warning("Marketplace load failed: \(error)")
            }
        }
    }

    private func searchMarketplace() {
        Task {
            do {
                entries = try await bridge.marketplaceSearch(query: searchText, category: selectedCategory, tags: [])
            } catch {
                toastManager.show(style: .error, title: "Search Failed", message: error.localizedDescription)
            }
        }
    }

    private func publishToMarketplace() {
        Task {
            do {
                let graphData: [String: Any] = publishGraphId.isEmpty ? [:] : ["graph_id": publishGraphId]
                let _ = try await bridge.marketplacePublish(
                    name: publishName,
                    author: publishAuthor,
                    description: publishDesc,
                    category: publishCategory,
                    tags: publishTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                    version: publishVersion,
                    graphData: graphData
                )
                showPublish = false
                toastManager.show(style: .success, title: "Published", message: "\(publishName) is now on marketplace")
                entries = try await bridge.marketplaceSearch(query: "", category: "", tags: [])
            } catch {
                toastManager.show(style: .error, title: "Publish Failed", message: error.localizedDescription)
            }
        }
    }
}

struct MarketplaceEntryRow: View {
    let entry: MarketplaceEntryModel
    let isLast: Bool
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        HStack(spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                Text(entry.name)
                    .font(.system(size: theme.smallTextSize, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(entry.author)
                    .font(.system(size: theme.captionSize))
                    .foregroundStyle(theme.textTertiary)
            }
            Spacer()
            if !entry.category.isEmpty {
                FusionTag(entry.category, color: .blue)
            }
            FusionButton("Install", icon: "arrow.down.circle", style: .secondary, size: .small) {
                installEntry()
            }
        }
        .padding(.vertical, theme.spacingS)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(theme.rowSep).frame(height: 0.5)
            }
        }
    }

    private func installEntry() {
        Task {
            do {
                let _ = try await bridge.marketplaceInstall(entryId: entry.id)
            } catch {
            }
        }
    }
}

struct MarketplaceCard: View {
    let entry: MarketplaceEntryModel
    @EnvironmentObject private var bridge: AgentBridge
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingS) {
            HStack {
                Image(systemName: "cube.box")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.accent)
                Spacer()
                if !entry.category.isEmpty {
                    FusionTag(entry.category, color: .blue)
                }
            }
            Text(entry.name)
                .font(.system(size: theme.smallTextSize, weight: .semibold))
                .foregroundStyle(theme.text)
                .lineLimit(1)
            Text(entry.author)
                .font(.system(size: theme.captionSize))
                .foregroundStyle(theme.textTertiary)
            Text(entry.description)
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
            if !entry.tags.isEmpty {
                FlowLayout(spacing: theme.spacingXS) {
                    ForEach(entry.tags.prefix(3), id: \.self) { tag in
                        FusionTag(tag, color: .gray)
                    }
                }
            }
            HStack {
                Text("v\(entry.version)")
                    .font(.system(size: theme.captionSize, design: .monospaced))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                FusionButton("Install", icon: "arrow.down.circle", style: .secondary, size: .small) {
                    installEntry()
                }
            }
        }
        .padding(theme.spacingM)
        .background(theme.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: theme.cornerRadius, style: .continuous)
                .stroke(theme.inputBorder, lineWidth: 1)
        }
    }

    private func installEntry() {
        Task {
            do {
                _ = try await bridge.marketplaceInstall(entryId: entry.id)
            } catch {
            }
        }
    }
}

// MARK: - ConversationView

struct ConversationView: View {
    @StateObject private var orchestrator = AgentOrchestrator.shared
    @State private var inputText = ""
    let toastManager: FusionToastManager
    @EnvironmentObject private var bridge: AgentBridge

    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            if !bridge.agentState.activeSessionId.isEmpty {
                HStack {
                    Image(systemName: "link")
                        .foregroundStyle(theme.textTertiary)
                    Text("Session: \(bridge.agentState.activeSessionId.prefix(12))...")
                        .font(.system(size: theme.captionSize, design: .monospaced))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    if bridge.agentState.isAgentStreaming {
                        HStack(spacing: theme.spacingXS) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Streaming...")
                                .font(.system(size: theme.captionSize))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
                .padding(.horizontal, theme.spacingM)
                .padding(.vertical, theme.spacingXS)
                .background(theme.surfaceSecondary)
            }
            if orchestrator.conversationLog.isEmpty {
                emptyChatPlaceholder
            } else {
                messageList
            }
            if !bridge.agentState.lastToolCalls.isEmpty {
                toolCallsBar
            }
            inputBar
            Spacer()
        }
        .toolbar {
            ToolbarItem {
                FusionButton("Clear", icon: "trash", style: .ghost, size: .small) {
                    orchestrator.clearConversation()
                    bridge.agentState.activeSessionId = ""
                    bridge.agentState.lastToolCalls = []
                    bridge.agentState.streamingContent = ""
                    toastManager.show(style: .info, title: "Chat Cleared", message: "Conversation history removed")
                }
            }
        }
    }

    private var toolCallsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacingXS) {
                Image(systemName: "wrench")
                    .foregroundStyle(theme.textTertiary)
                ForEach(Array(bridge.agentState.lastToolCalls.enumerated()), id: \.offset) { idx, tc in
                    let name = tc["name"] as? String ?? tc["function"] as? String ?? "tool"
                    FusionTag(name, color: .purple)
                }
            }
        }
        .padding(.horizontal, theme.spacingM)
        .padding(.vertical, theme.spacingXS)
        .background(theme.surfaceSecondary)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                    ForEach(orchestrator.conversationLog) { msg in
                        messageBubble(msg: msg)
                            .id(msg.id)
                    }
                }
                .padding(theme.spacingL)
            }
            .onChange(of: orchestrator.conversationLog.count) { _, _ in
                withAnimation(theme.springSnappy) {
                    proxy.scrollTo(orchestrator.conversationLog.last?.id, anchor: .bottom)
                }
            }
        }
    }

    private func messageBubble(msg: AgentOrchestrator.AgentMessage) -> some View {
        HStack(alignment: .top, spacing: theme.spacingS) {
            VStack(alignment: .leading, spacing: theme.spacingXS) {
                HStack(spacing: theme.spacingXS) {
                    Text(msg.fromAgent)
                        .font(.system(size: theme.smallTextSize, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    Image(systemName: "arrow.right")
                        .font(.system(size: theme.iconXS))
                        .foregroundStyle(theme.textTertiary)
                    Text(msg.toAgent)
                        .font(.system(size: theme.smallTextSize, weight: .semibold))
                        .foregroundStyle(theme.accentSecondary)
                    Spacer()
                    Text(msg.timestamp, style: .time)
                        .font(.system(size: theme.captionSize))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(msg.content)
                    .font(.system(size: theme.footnoteSize, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .textSelection(.enabled)
            }
        }
        .padding(theme.spacingM)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
    }

    private var inputBar: some View {
        HStack(spacing: theme.spacingS) {
            TextField("Send a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: theme.textSize))
                .lineLimit(1...6)
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .onSubmit { sendMessage() }

            FusionButton("Send", icon: "paperplane.fill", style: .primary, size: .small, isDisabled: inputText.isEmpty) {
                sendMessage()
            }
        }
        .padding(.horizontal, theme.spacingL)
        .padding(.vertical, theme.spacingS)
        .background(theme.surfaceSecondary)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.separator)
                .frame(height: 0.5)
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        orchestrator.sendMessage(from: "User", to: "All Agents", content: inputText)
        agentStudioLog.info("User sent message: \(inputText)")
        inputText = ""
    }

    private var emptyChatPlaceholder: some View {
        VStack(spacing: theme.spacingM) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(theme.textTertiary)
            Text("No messages yet")
                .font(.system(size: theme.textSize))
                .foregroundStyle(theme.textSecondary)
            Text("Run a workflow or send a message to start a conversation")
                .font(.system(size: theme.footnoteSize))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
    }
}

// MARK: - SoulEditorSheet

struct SoulEditorSheet: View {
    @Binding var soulContent: String
    let onSave: () -> Void
    let toastManager: FusionToastManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.studioTheme) var theme

    var body: some View {
        VStack(spacing: theme.spacingL) {
            Text("Edit Soul")
                .font(.system(size: theme.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.text)

            TextEditor(text: $soulContent)
                .font(.system(size: theme.footnoteSize, design: .monospaced))
                .padding(theme.spacingS)
                .background(theme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall, style: .continuous)
                        .stroke(theme.inputBorder, lineWidth: 1)
                }
                .frame(minHeight: 200)

            HStack(spacing: theme.spacingM) {
                FusionButton("Cancel", icon: "xmark", style: .secondary, size: .regular) {
                    dismiss()
                }
                FusionButton("Save", icon: "checkmark", style: .primary, size: .regular) {
                    onSave()
                }
            }
        }
        .padding(theme.spacingXL)
        .frame(width: 500, height: 400)
        .background(theme.windowBg)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var result = LayoutResult()
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            result.positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }

        result.size = CGSize(width: maxWidth, height: currentY + rowHeight)
        return result
    }
}
